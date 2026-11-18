import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:snakes_ladders/app.dart';
import 'package:snakes_ladders/core/services/audio_service.dart';
import 'package:snakes_ladders/data/models/app_settings.dart';
import 'package:snakes_ladders/data/models/app_user.dart';
import 'package:snakes_ladders/data/repositories/profile_repository.dart';
import 'package:snakes_ladders/data/services/auth_service.dart';
import 'package:snakes_ladders/data/services/firebase_bootstrap.dart';
import 'package:snakes_ladders/data/services/settings_store.dart';
import 'package:snakes_ladders/features/game/components/game_audio_bridge.dart';
import 'package:snakes_ladders/features/game/models/game_state.dart';
import 'package:snakes_ladders/features/game/models/player.dart';
import 'package:snakes_ladders/features/home/home_screen.dart';
import 'package:snakes_ladders/features/home/rules_screen.dart';
import 'package:snakes_ladders/features/onboarding/onboarding_screen.dart';
import 'package:snakes_ladders/features/settings/settings_screen.dart';
import 'package:snakes_ladders/providers/app_providers.dart';
import 'package:snakes_ladders/providers/settings_providers.dart';

const players = [Player(id: 'a', name: 'Ann', colorIndex: 0), Player(id: 'b', name: 'Ben', colorIndex: 1)];

GameState state({GamePhase phase = GamePhase.waiting, int current = 0, List<int> positions = const [0, 0], List<GameEvent> events = const [], bool completed = false}) =>
    GameState(
      players: [for (final (i, p) in players.indexed) p.copyWith(position: positions[i])],
      phase: phase,
      currentPlayerIndex: current,
      events: events,
      winnerIndex: completed ? current : null,
    );

GameEvent ev(GameEventType t) => GameEvent(type: t, playerIndex: 0, message: t.name);

void main() {
  group('GameAudioMapper', () {
    const m = GameAudioMapper();

    test('dice on roll start, step per cell, event sounds, turn chime', () {
      expect(m.sfxFor(null, state()), isEmpty);
      expect(m.sfxFor(state(), state(phase: GamePhase.rolling)), [Sfx.dice]);
      expect(m.sfxFor(state(phase: GamePhase.moving, positions: [3, 0]), state(phase: GamePhase.moving, positions: [4, 0])), [Sfx.step]);
      expect(m.sfxFor(state(phase: GamePhase.moving, positions: [3, 0]), state(phase: GamePhase.moving, positions: [3, 0])), isEmpty);
      final prev = state(phase: GamePhase.moving);
      expect(m.sfxFor(prev, state(phase: GamePhase.slidingSnake, events: [ev(GameEventType.snake)])), [Sfx.snake]);
      expect(m.sfxFor(prev, state(phase: GamePhase.climbingLadder, events: [ev(GameEventType.ladder)])), [Sfx.ladder]);
      expect(m.sfxFor(prev, state(phase: GamePhase.completed, events: [ev(GameEventType.won)], completed: true)), [Sfx.win]);
      expect(m.sfxFor(prev, state(phase: GamePhase.switchingTurn, events: [ev(GameEventType.blocked)])), [Sfx.blocked]);
      expect(m.sfxFor(state(phase: GamePhase.switchingTurn), state(phase: GamePhase.waiting, events: [ev(GameEventType.extraTurn)])), [Sfx.six]);
      // Turn passes to the other human.
      expect(m.sfxFor(state(phase: GamePhase.switchingTurn, current: 0), state(phase: GamePhase.waiting, current: 1)), [Sfx.turn]);
      // Not when it stays with the same seat.
      expect(m.sfxFor(state(phase: GamePhase.switchingTurn, current: 0), state(phase: GamePhase.waiting, current: 0)), isEmpty);
    });

    test('only new events are played', () {
      final a = state(events: [ev(GameEventType.ladder)]);
      final b = state(events: [ev(GameEventType.ladder), ev(GameEventType.snake)]);
      expect(m.sfxFor(a, b), [Sfx.snake]);
    });
  });

  group('SettingsNotifier', () {
    test('loads, saves and drives the audio service', () async {
      final store = InMemorySettingsStore(const AppSettings(sound: false, themeMode: ThemeMode.light, onboardingDone: true));
      final audio = SilentAudioService();
      final c = ProviderContainer(overrides: [
        settingsStoreProvider.overrideWithValue(store),
        audioServiceProvider.overrideWithValue(audio),
      ]);
      addTearDown(c.dispose);
      expect(c.read(settingsProvider).loaded, isFalse);
      await Future<void>.delayed(Duration.zero);
      final s = c.read(settingsProvider);
      expect(s.loaded, isTrue);
      expect(s.sound, isFalse);
      expect(s.themeMode, ThemeMode.light);
      expect(audio.soundEnabled, isFalse);
      await c.read(settingsProvider.notifier).setSound(true);
      await c.read(settingsProvider.notifier).setMusic(false);
      expect(audio.soundEnabled, isTrue);
      expect(audio.musicEnabled, isFalse);
      expect(store.current!.music, isFalse);
      expect(store.saves, 2);
      expect(c.read(hapticsProvider).enabled, isTrue);
      await c.read(settingsProvider.notifier).setHaptics(false);
      expect(c.read(hapticsProvider).enabled, isFalse);
    });

    test('AppSettings round-trips', () {
      const s = AppSettings(sound: false, music: true, haptics: false, themeMode: ThemeMode.system, onboardingDone: true);
      final back = AppSettings.fromMap(s.toMap());
      expect(back.sound, isFalse);
      expect(back.haptics, isFalse);
      expect(back.themeMode, ThemeMode.system);
      expect(back.onboardingDone, isTrue);
      expect(back.loaded, isTrue);
      expect(AppSettings.fromMap(const {}).themeMode, ThemeMode.dark);
    });
  });

  group('screens', () {
    Widget app({required bool onboardingDone, required SilentAudioService audio}) => ProviderScope(
          overrides: [
            firebaseStatusProvider.overrideWith((ref) async => const FirebaseStatus.unavailable('test')),
            authServiceProvider.overrideWithValue(
              LocalAuthService(uid: 'local-test', initialUser: const AppUser(uid: 'local-test', isGuest: true, isOffline: true)),
            ),
            profileRepositoryProvider.overrideWithValue(InMemoryProfileRepository()),
            audioServiceProvider.overrideWithValue(audio),
            settingsStoreProvider.overrideWithValue(InMemorySettingsStore(AppSettings(onboardingDone: onboardingDone))),
          ],
          child: const SnakesLaddersApp(),
        );

    testWidgets('first launch shows onboarding, finishing lands on home and starts music', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final audio = SilentAudioService();
      await tester.pumpWidget(app(onboardingDone: false, audio: audio));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Roll & race'), findsOneWidget);
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('Climb ladders'), findsOneWidget);
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("LET'S PLAY"));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(audio.musicStarts, greaterThanOrEqualTo(1));
    });

    testWidgets('settings toggles sound and theme; rules screen opens', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final audio = SilentAudioService();
      await tester.pumpWidget(app(onboardingDone: true, audio: audio));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byType(HomeScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(audio.played, contains(Sfx.click));

      await tester.tap(find.text('Sound effects'));
      await tester.pumpAndSettle();
      expect(audio.soundEnabled, isFalse);
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, ThemeMode.light);

      await tester.tap(find.text('How to play'));
      await tester.pumpAndSettle();
      expect(find.byType(RulesScreen), findsOneWidget);
      expect(find.text('Snakes'), findsOneWidget);
    });
  });
}
