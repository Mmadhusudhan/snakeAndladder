import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snakes_ladders/app.dart';
import 'package:snakes_ladders/data/models/app_user.dart';
import 'package:snakes_ladders/data/repositories/profile_repository.dart';
import 'package:snakes_ladders/data/services/auth_service.dart';
import 'package:snakes_ladders/data/services/firebase_bootstrap.dart';
import 'package:snakes_ladders/core/services/audio_service.dart';
import 'package:snakes_ladders/data/models/app_settings.dart';
import 'package:snakes_ladders/data/services/settings_store.dart';
import 'package:snakes_ladders/providers/app_providers.dart';
import 'package:snakes_ladders/providers/settings_providers.dart';
import 'package:snakes_ladders/features/game/board/board_widget.dart';
import 'package:snakes_ladders/features/game/components/dice_widget.dart';
import 'package:snakes_ladders/features/game/models/game_state.dart';
import 'package:snakes_ladders/providers/game_providers.dart';

/// Boots the app straight into the home screen as an offline guest.
Widget offlineApp() => ProviderScope(
      overrides: [
        firebaseStatusProvider.overrideWith((ref) async => const FirebaseStatus.unavailable('test')),
        authServiceProvider.overrideWithValue(
          LocalAuthService(uid: 'local-test', initialUser: const AppUser(uid: 'local-test', isGuest: true, isOffline: true)),
        ),
        profileRepositoryProvider.overrideWithValue(InMemoryProfileRepository()),
        audioServiceProvider.overrideWithValue(SilentAudioService()),
        settingsStoreProvider.overrideWithValue(InMemorySettingsStore(const AppSettings(onboardingDone: true))),
      ],
      child: const SnakesLaddersApp(),
    );

Future<void> pumpToHome(WidgetTester tester) async {
  await tester.pumpWidget(offlineApp());
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('home -> setup -> game: a human can roll and the token moves',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await pumpToHome(tester);
    expect(find.text('SNAKES & LADDERS'), findsOneWidget);

    await tester.tap(find.text('Local Multiplayer'));
    await tester.pumpAndSettle();
    expect(find.text('START GAME'), findsOneWidget);

    await tester.tap(find.text('START GAME'));
    // The board runs a looping snake animation, so settle with fixed pumps.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(BoardWidget), findsOneWidget);
    expect(find.textContaining("Player 1's turn"), findsAtLeastNWidgets(1));

    await tester.tap(find.byType(DiceWidget));
    await tester.pump(); // locks immediately
    expect(find.textContaining('is rolling'), findsOneWidget);

    // Let the roll, the walk and the turn switch finish.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 400));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BoardWidget)),
    );
    final state = container.read(gameControllerProvider);
    expect(state.phase, GamePhase.waiting);
    expect(state.lastRoll, inInclusiveRange(1, 6));
    expect(state.players[0].position, greaterThan(0));
    // A six keeps the turn, anything else passes it on.
    expect(state.currentPlayerIndex, state.lastRoll == 6 ? 0 : 1);
    expect(find.textContaining("'s turn"), findsAtLeastNWidgets(1));
  });

  testWidgets('landscape layout puts the board beside the panel',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpToHome(tester);
    await tester.tap(find.text('Play vs Computer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START GAME'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final board = tester.getRect(find.byType(BoardWidget));
    final dice = tester.getRect(find.byType(DiceWidget));
    expect(board.width, board.height);
    expect(dice.left, greaterThan(board.right));
  });
}
