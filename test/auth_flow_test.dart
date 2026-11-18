import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:snakes_ladders/app.dart';
import 'package:snakes_ladders/data/repositories/profile_repository.dart';
import 'package:snakes_ladders/data/services/auth_service.dart';
import 'package:snakes_ladders/data/services/firebase_bootstrap.dart';
import 'package:snakes_ladders/features/authentication/login_screen.dart';
import 'package:snakes_ladders/features/home/home_screen.dart';
import 'package:snakes_ladders/features/leaderboard/leaderboard_screen.dart';
import 'package:snakes_ladders/features/profile/profile_screen.dart';
import 'package:snakes_ladders/core/services/audio_service.dart';
import 'package:snakes_ladders/data/models/app_settings.dart';
import 'package:snakes_ladders/data/services/settings_store.dart';
import 'package:snakes_ladders/providers/app_providers.dart';
import 'package:snakes_ladders/providers/settings_providers.dart';

void main() {
  testWidgets('splash -> login -> offline guest -> home -> profile & leaderboard', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final auth = LocalAuthService(uid: 'local-test');
    final repo = InMemoryProfileRepository();
    addTearDown(auth.dispose);
    addTearDown(repo.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        firebaseStatusProvider.overrideWith((ref) async => const FirebaseStatus.unavailable('not configured')),
        authServiceProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(repo),
        audioServiceProvider.overrideWithValue(SilentAudioService()),
        settingsStoreProvider.overrideWithValue(InMemorySettingsStore(const AppSettings(onboardingDone: true))),
      ],
      child: const SnakesLaddersApp(),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('PLAY OFFLINE'), findsOneWidget);
    expect(find.text('CONTINUE WITH GOOGLE'), findsNothing);

    await tester.tap(find.text('PLAY OFFLINE'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);

    await tester.tap(find.byTooltip('Leaderboard'));
    await tester.pumpAndSettle();
    expect(find.byType(LeaderboardScreen), findsOneWidget);
    expect(find.text('No ranked games yet.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guest'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Offline guest'), findsOneWidget);
    expect(find.text('Games'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
