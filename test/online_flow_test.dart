import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:snakes_ladders/app.dart';
import 'package:snakes_ladders/data/models/app_user.dart';
import 'package:snakes_ladders/data/repositories/profile_repository.dart';
import 'package:snakes_ladders/data/services/auth_service.dart';
import 'package:snakes_ladders/data/services/firebase_bootstrap.dart';
import 'package:snakes_ladders/data/services/local_room_service.dart';
import 'package:snakes_ladders/features/game/board/board_widget.dart';
import 'package:snakes_ladders/features/game/components/dice_widget.dart';
import 'package:snakes_ladders/features/multiplayer/online_game_screen.dart';
import 'package:snakes_ladders/features/multiplayer/online_lobby_screen.dart';
import 'package:snakes_ladders/features/multiplayer/room_screen.dart';
import 'package:snakes_ladders/core/services/audio_service.dart';
import 'package:snakes_ladders/data/models/app_settings.dart';
import 'package:snakes_ladders/data/services/settings_store.dart';
import 'package:snakes_ladders/providers/app_providers.dart';
import 'package:snakes_ladders/providers/settings_providers.dart';
import 'package:snakes_ladders/providers/online_providers.dart';

void main() {
  testWidgets('lobby -> private room -> bot joins -> start -> roll -> move replayed', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final sim = LocalRoomService(uid: 'me', simulateOpponents: true, random: Random(2), botDelay: const Duration(milliseconds: 300));
    addTearDown(sim.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        firebaseStatusProvider.overrideWith((ref) async => const FirebaseStatus.unavailable('test')),
        authServiceProvider.overrideWithValue(
          LocalAuthService(uid: 'me', initialUser: const AppUser(uid: 'me', isGuest: true, isOffline: true)),
        ),
        profileRepositoryProvider.overrideWithValue(InMemoryProfileRepository()),
        audioServiceProvider.overrideWithValue(SilentAudioService()),
        settingsStoreProvider.overrideWithValue(InMemorySettingsStore(const AppSettings(onboardingDone: true))),
        roomServiceProvider.overrideWithValue(sim),
      ],
      child: const SnakesLaddersApp(),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.tap(find.text('Play Online'));
    await tester.pumpAndSettle();
    expect(find.byType(OnlineLobbyScreen), findsOneWidget);
    expect(find.textContaining('Offline simulation'), findsOneWidget);

    await tester.tap(find.text('CREATE PRIVATE ROOM'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(RoomScreen), findsOneWidget);
    expect(find.text('WAITING FOR PLAYERS'), findsOneWidget);

    // The simulated opponent joins after 300ms.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('START GAME'), findsOneWidget);
    expect(find.text('Mango'), findsOneWidget);

    await tester.tap(find.text('START GAME'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(OnlineGameScreen), findsOneWidget);
    expect(find.byType(BoardWidget), findsOneWidget);
    expect(find.text('ROLL'), findsOneWidget);

    // Roll whenever it is my turn until the bot has replied at least once
    // (a six keeps the turn, so this may take a couple of rolls).
    var botMoved = false;
    for (var i = 0; i < 120 && !botMoved; i++) {
      final view = ProviderScope.containerOf(tester.element(find.byType(DiceWidget))).read(onlineGameProvider(sim.rooms.keys.first));
      if (view.canRoll) {
        await tester.tap(find.byType(DiceWidget));
      }
      await tester.pump(const Duration(milliseconds: 250));
      botMoved = sim.rooms.values.first.moves.any((m) => m.seat == 1);
    }
    final room = sim.rooms.values.first;
    expect(botMoved, isTrue);
    expect(room.moves.first.seat, 0);
    // Let the last replay finish before leaving.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    // Leave: confirm dialog, then back to the lobby.
    // The board animates forever, so never pumpAndSettle on the game screen.
    await tester.tap(find.byTooltip('Leave'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Leave'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(OnlineLobbyScreen), findsOneWidget);
    expect(sim.rooms.values.first.isFinished, isTrue);
    // Drain any pending bot timers.
    await tester.pump(const Duration(seconds: 3));
  });
}
