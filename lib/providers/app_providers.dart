import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_user.dart';
import '../data/models/leaderboard_entry.dart';
import '../data/models/match_record.dart';
import '../data/models/user_profile.dart';
import '../data/repositories/profile_repository.dart';
import '../data/services/api_client.dart';
import '../data/services/auth_service.dart';
import '../data/services/firebase_bootstrap.dart';
import '../data/services/match_recorder.dart';

/// Starts Firebase (or reports why it could not).
final firebaseStatusProvider = FutureProvider<FirebaseStatus>((ref) => FirebaseBootstrap.initialize());

/// Picks the Firebase or offline auth service once bootstrap has finished.
/// Overridden in tests.
final authServiceProvider = Provider<AuthService>((ref) {
  final status = ref.watch(firebaseStatusProvider).value;
  if (status != null && status.available) return FirebaseAuthService();
  final local = LocalAuthService();
  ref.onDispose(local.dispose);
  return local;
});

final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final status = ref.watch(firebaseStatusProvider).value;
  if (status != null && status.available) return FirestoreProfileRepository();
  final mem = InMemoryProfileRepository();
  ref.onDispose(mem.dispose);
  return mem;
});

/// The signed-in user's profile document.
final profileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(profileRepositoryProvider).watchProfile(user.uid);
});

final historyProvider = StreamProvider<List<MatchRecord>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(profileRepositoryProvider).watchHistory(user.uid);
});

final leaderboardProvider = StreamProvider.family<List<LeaderboardEntry>, LeaderboardPeriod>((ref, period) {
  return ref.watch(profileRepositoryProvider).watchLeaderboard(period);
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final auth = ref.watch(authServiceProvider);
  return ApiClient(baseUrl: ApiClient.configuredBaseUrl, tokenProvider: auth.idToken);
});

final matchRecorderProvider = Provider<MatchRecorder>((ref) {
  return MatchRecorder(
    repository: ref.watch(profileRepositoryProvider),
    api: ref.watch(apiClientProvider),
  );
});

/// Sign-in actions with error messages suitable for a snackbar.
class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> _run(Future<AppUser> Function(AuthService) action) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(authServiceProvider);
      final user = await action(service);
      await ref.read(profileRepositoryProvider).ensureProfile(user);
      state = const AsyncValue.data(null);
      return true;
    } on AuthException catch (e, st) {
      state = e.cancelled ? const AsyncValue.data(null) : AsyncValue.error(e, st);
      return false;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> signInAsGuest() => _run((s) => s.signInAsGuest());
  Future<bool> signInWithGoogle() => _run((s) => s.signInWithGoogle());

  Future<void> signOut() async {
    await ref.read(authServiceProvider).signOut();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AsyncValue<void>>(AuthController.new);
