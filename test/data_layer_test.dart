import 'package:flutter_test/flutter_test.dart';
import 'package:snakes_ladders/data/models/app_user.dart';
import 'package:snakes_ladders/data/models/leaderboard_entry.dart';
import 'package:snakes_ladders/data/models/match_record.dart';
import 'package:snakes_ladders/data/models/user_profile.dart';
import 'package:snakes_ladders/data/repositories/profile_repository.dart';
import 'package:snakes_ladders/data/services/api_client.dart';
import 'package:snakes_ladders/data/services/auth_service.dart';
import 'package:snakes_ladders/data/services/match_recorder.dart';
import 'package:snakes_ladders/features/game/models/game_state.dart';
import 'package:snakes_ladders/features/game/models/player.dart';
import 'package:snakes_ladders/providers/game_providers.dart';

GameState finishedGame({int winner = 0}) => GameState(
      players: [
        Player(id: 'a', name: 'You', colorIndex: 0, position: winner == 0 ? 100 : 55),
        Player(id: 'b', name: 'Mango', colorIndex: 1, position: winner == 1 ? 100 : 61, type: PlayerType.computer, botId: 'mango'),
      ],
      stats: const [PlayerStats(rolls: 12, snakes: 1, ladders: 2), PlayerStats(rolls: 11, snakes: 2)],
      phase: GamePhase.completed,
      winnerIndex: winner,
      turnNumber: 23,
      startedAt: DateTime(2026, 11, 18, 10),
      completedAt: DateTime(2026, 11, 18, 10, 2),
    );

void main() {
  group('ProfileStats', () {
    test('applyMatch mirrors the backend rules', () {
      var s = const ProfileStats().applyMatch(won: true, turns: 20, snakes: 1, ladders: 3);
      expect(s.games, 1);
      expect(s.wins, 1);
      expect(s.winStreak, 1);
      expect(s.bestWinTurns, 20);
      expect(s.rating, 1025);
      s = s.applyMatch(won: false, turns: 30, snakes: 0, ladders: 0);
      expect(s.losses, 1);
      expect(s.winStreak, 0);
      expect(s.bestWinTurns, 20);
      expect(s.rating, 1015);
      expect(s.totalTurns, 50);
      expect(s.winRate, 0.5);
    });

    test('round-trips through a map', () {
      const s = ProfileStats(games: 3, wins: 2, losses: 1, bestWinTurns: 17, rating: 1040);
      final back = ProfileStats.fromMap(s.toMap());
      expect(back.games, 3);
      expect(back.bestWinTurns, 17);
      expect(back.rating, 1040);
      expect(ProfileStats.fromMap(null).rating, ProfileStats.baseRating);
    });
  });

  group('UserProfile', () {
    test('serialises and parses dates in several shapes', () {
      const u = UserProfile(uid: 'x', displayName: 'Ann', avatar: '🦁', isGuest: false);
      final m = u.toMap();
      expect(UserProfile.fromMap('x', m).displayName, 'Ann');
      expect(UserProfile.parseDate('2026-11-18T10:00:00Z')?.year, 2026);
      expect(UserProfile.parseDate(1000)?.millisecondsSinceEpoch, 1000);
      expect(UserProfile.parseDate(null), isNull);
      expect(UserProfile.parseDate(Object()), isNull);
    });
  });

  group('MatchRecord', () {
    test('fromGame captures seats, stats, winner and duration', () {
      final setup = GameSetup.defaultFor(GameMode.vsComputer);
      final r = MatchRecord.fromGame(finishedGame(), setup, myIndex: 0, id: 'm1');
      expect(r.players.length, 2);
      expect(r.players[1].isComputer, isTrue);
      expect(r.players[0].rolls, 12);
      expect(r.winnerIndex, 0);
      expect(r.iWon, isTrue);
      expect(r.turns, 23);
      expect(r.durationMs, 120000);
      expect(r.countsForStats, isTrue);
      final back = MatchRecord.fromMap('m1', r.toMap());
      expect(back.mode, GameMode.vsComputer);
      expect(back.players[1].name, 'Mango');
      expect(back.endedAt.toUtc(), r.endedAt.toUtc());
    });

    test('pass-and-play and practice never count for stats', () {
      final local = MatchRecord.fromGame(finishedGame(), GameSetup.defaultFor(GameMode.localMultiplayer));
      expect(local.countsForStats, isFalse);
      expect(local.myIndex, isNull);
      final practice = MatchRecord.fromGame(finishedGame(), GameSetup.defaultFor(GameMode.practice), myIndex: 0);
      expect(practice.countsForStats, isFalse);
    });

    test('seatFor', () {
      expect(MatchRecorder.seatFor(GameSetup.defaultFor(GameMode.vsComputer)), 0);
      expect(MatchRecorder.seatFor(GameSetup.defaultFor(GameMode.localMultiplayer)), isNull);
    });
  });

  group('LocalAuthService', () {
    test('guest sign-in and sign-out emit state', () async {
      final auth = LocalAuthService(uid: 'local-1');
      final states = <AppUser?>[];
      final sub = auth.authStateChanges.listen(states.add);
      expect(auth.currentUser, isNull);
      final u = await auth.signInAsGuest();
      expect(u.isGuest, isTrue);
      expect(u.isOffline, isTrue);
      expect(await auth.idToken(), isNull);
      await auth.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(states, [null, u, null]);
      expect(() => auth.signInWithGoogle(), throwsA(isA<AuthException>()));
      await sub.cancel();
      auth.dispose();
    });
  });

  group('InMemoryProfileRepository', () {
    late InMemoryProfileRepository repo;
    const user = AppUser(uid: 'u1', isGuest: true, displayName: 'Guest');

    setUp(() => repo = InMemoryProfileRepository());
    tearDown(() => repo.dispose());

    test('ensureProfile creates once and keeps edits', () async {
      final p = await repo.ensureProfile(user, avatar: '🐸');
      expect(p.displayName, 'Guest');
      expect(p.avatar, '🐸');
      await repo.updateProfile('u1', displayName: 'Zara');
      final again = await repo.ensureProfile(user);
      expect(again.displayName, 'Zara');
      expect(await repo.watchProfile('u1').first, isNotNull);
      expect(await repo.watchProfile('nobody').first, isNull);
    });

    test('recordMatch updates history, stats and the leaderboard', () async {
      await repo.ensureProfile(user);
      final setup = GameSetup.defaultFor(GameMode.vsComputer);
      await repo.recordMatch('u1', MatchRecord.fromGame(finishedGame(), setup, myIndex: 0, id: 'm1'));
      await repo.recordMatch('u1', MatchRecord.fromGame(finishedGame(winner: 1), setup, myIndex: 0, id: 'm2'));
      // Duplicate id replaces rather than duplicates.
      await repo.recordMatch('u1', MatchRecord.fromGame(finishedGame(winner: 1), setup, myIndex: 0, id: 'm2'));

      final history = await repo.watchHistory('u1').first;
      expect(history.length, 2);
      expect(history.first.id, 'm2');

      final profile = (await repo.watchProfile('u1').first)!;
      expect(profile.stats.games, 3);
      expect(profile.stats.wins, 1);
      expect(profile.stats.losses, 2);

      final board = await repo.watchLeaderboard(LeaderboardPeriod.allTime).first;
      expect(board.length, 1);
      expect(board.first.uid, 'u1');
      expect(board.first.rating, 1005);
    });

    test('leaderboard orders by rating then wins', () {
      final a = const LeaderboardEntry(uid: 'a', displayName: 'A', avatar: '', wins: 3, games: 5, rating: 1050);
      final b = const LeaderboardEntry(uid: 'b', displayName: 'B', avatar: '', wins: 5, games: 9, rating: 1050);
      final c = const LeaderboardEntry(uid: 'c', displayName: 'C', avatar: '', wins: 1, games: 1, rating: 1025);
      final sorted = [c, a, b]..sort(LeaderboardEntry.compare);
      expect(sorted.map((e) => e.uid), ['b', 'a', 'c']);
    });
  });

  group('MatchRecorder', () {
    test('records locally and skips the API when disabled or offline', () async {
      final repo = InMemoryProfileRepository();
      final api = ApiClient(baseUrl: '', tokenProvider: () async => null);
      final recorder = MatchRecorder(repository: repo, api: api);
      const user = AppUser(uid: 'u1', isGuest: true, isOffline: true);
      await repo.ensureProfile(user);
      final setup = GameSetup.defaultFor(GameMode.vsComputer);
      final rec = await recorder.record(user, finishedGame(), setup);
      expect(rec, isNotNull);
      expect((await repo.watchHistory('u1').first).length, 1);
      expect(await recorder.record(null, finishedGame(), setup), isNull);
      expect(api.isEnabled, isFalse);
      expect(await api.submitMatch(rec!), isNull);
      repo.dispose();
    });
  });
}
