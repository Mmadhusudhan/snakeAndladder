import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/leaderboard_entry.dart';
import '../models/match_record.dart';
import '../models/user_profile.dart';

/// Storage boundary for profiles, history and leaderboards.
///
/// Rules of the road (mirrored in `firestore.rules`):
/// - a user may read and write their own `users/{uid}` and
///   `game_history/{uid}/games/*`;
/// - leaderboard entries are written only by the backend.
abstract class ProfileRepository {
  Stream<UserProfile?> watchProfile(String uid);

  /// Creates the profile on first sign-in and stamps `lastSeenAt`.
  Future<UserProfile> ensureProfile(AppUser user, {String? avatar});

  Future<void> updateProfile(String uid, {String? displayName, String? avatar});

  /// Saves a finished match to the user's history and, when it counts,
  /// applies it to their stats.
  Future<void> recordMatch(String uid, MatchRecord match);

  Stream<List<MatchRecord>> watchHistory(String uid, {int limit = 50});

  Stream<List<LeaderboardEntry>> watchLeaderboard(LeaderboardPeriod period, {int limit = 50});
}

/// In-memory implementation for offline mode and tests. The leaderboard is
/// derived from the profiles it knows about so the screen still works.
class InMemoryProfileRepository implements ProfileRepository {
  final Map<String, UserProfile> _profiles = {};
  final Map<String, List<MatchRecord>> _history = {};
  final _profileChanges = StreamController<String>.broadcast();
  final _historyChanges = StreamController<String>.broadcast();

  Map<String, UserProfile> get profiles => Map.unmodifiable(_profiles);

  @override
  Stream<UserProfile?> watchProfile(String uid) async* {
    yield _profiles[uid];
    yield* _profileChanges.stream.where((u) => u == uid).map((_) => _profiles[uid]);
  }

  @override
  Future<UserProfile> ensureProfile(AppUser user, {String? avatar}) async {
    final now = DateTime.now();
    final existing = _profiles[user.uid];
    final profile = existing?.copyWith(lastSeenAt: now) ??
        UserProfile(
          uid: user.uid,
          displayName: user.fallbackName,
          avatar: avatar ?? '🦁',
          isGuest: user.isGuest,
          createdAt: now,
          lastSeenAt: now,
        );
    _profiles[user.uid] = profile;
    _profileChanges.add(user.uid);
    return profile;
  }

  @override
  Future<void> updateProfile(String uid, {String? displayName, String? avatar}) async {
    final p = _profiles[uid];
    if (p == null) return;
    _profiles[uid] = p.copyWith(displayName: displayName, avatar: avatar);
    _profileChanges.add(uid);
  }

  @override
  Future<void> recordMatch(String uid, MatchRecord match) async {
    final list = _history.putIfAbsent(uid, () => []);
    list.removeWhere((m) => m.id == match.id);
    list.insert(0, match);
    _historyChanges.add(uid);
    if (match.countsForStats) {
      final p = _profiles[uid];
      if (p != null) {
        final me = match.me!;
        _profiles[uid] = p.copyWith(
          stats: p.stats.applyMatch(
            won: match.iWon,
            turns: match.turns,
            snakes: me.snakes,
            ladders: me.ladders,
          ),
        );
        _profileChanges.add(uid);
      }
    }
  }

  @override
  Stream<List<MatchRecord>> watchHistory(String uid, {int limit = 50}) async* {
    List<MatchRecord> snapshot() => List.unmodifiable((_history[uid] ?? const []).take(limit));
    yield snapshot();
    yield* _historyChanges.stream.where((u) => u == uid).map((_) => snapshot());
  }

  @override
  Stream<List<LeaderboardEntry>> watchLeaderboard(LeaderboardPeriod period, {int limit = 50}) async* {
    List<LeaderboardEntry> snapshot() {
      final entries = [
        for (final p in _profiles.values)
          if (p.stats.games > 0)
            LeaderboardEntry(
              uid: p.uid,
              displayName: p.displayName,
              avatar: p.avatar,
              wins: p.stats.wins,
              games: p.stats.games,
              rating: p.stats.rating,
            ),
      ]..sort(LeaderboardEntry.compare);
      return List.unmodifiable(entries.take(limit));
    }

    yield snapshot();
    yield* _profileChanges.stream.map((_) => snapshot());
  }

  void dispose() {
    _profileChanges.close();
    _historyChanges.close();
  }
}

/// Cloud Firestore implementation.
class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) => _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _historyCol(String uid) =>
      _db.collection('game_history').doc(uid).collection('games');

  @override
  Stream<UserProfile?> watchProfile(String uid) => _userDoc(uid).snapshots().map(
        (snap) => snap.exists ? UserProfile.fromMap(uid, snap.data()!) : null,
      );

  @override
  Future<UserProfile> ensureProfile(AppUser user, {String? avatar}) async {
    final ref = _userDoc(user.uid);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.update({'lastSeenAt': FieldValue.serverTimestamp()});
      return UserProfile.fromMap(user.uid, snap.data()!);
    }
    final profile = UserProfile(
      uid: user.uid,
      displayName: user.fallbackName,
      avatar: avatar ?? '🦁',
      isGuest: user.isGuest,
      createdAt: DateTime.now(),
      lastSeenAt: DateTime.now(),
    );
    await ref.set({
      ...profile.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    });
    return profile;
  }

  @override
  Future<void> updateProfile(String uid, {String? displayName, String? avatar}) async {
    final data = <String, dynamic>{
      'displayName': ?displayName,
      'avatar': ?avatar,
    };
    if (data.isEmpty) return;
    await _userDoc(uid).update(data);
  }

  @override
  Future<void> recordMatch(String uid, MatchRecord match) async {
    final historyRef = _historyCol(uid).doc(match.id);
    final userRef = _userDoc(uid);
    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      tx.set(historyRef, {
        ...match.toMap(),
        'endedAt': FieldValue.serverTimestamp(),
      });
      if (match.countsForStats && userSnap.exists) {
        final stats = ProfileStats.fromMap(userSnap.data()?['stats'] as Map<String, dynamic>?);
        final me = match.me!;
        tx.update(userRef, {
          'stats': stats
              .applyMatch(
                won: match.iWon,
                turns: match.turns,
                snakes: me.snakes,
                ladders: me.ladders,
              )
              .toMap(),
        });
      }
    });
  }

  @override
  Stream<List<MatchRecord>> watchHistory(String uid, {int limit = 50}) =>
      _historyCol(uid).orderBy('endedAt', descending: true).limit(limit).snapshots().map(
            (q) => [for (final d in q.docs) MatchRecord.fromMap(d.id, d.data())],
          );

  @override
  Stream<List<LeaderboardEntry>> watchLeaderboard(LeaderboardPeriod period, {int limit = 50}) => _db
      .collection('leaderboards')
      .doc(period.id)
      .collection('entries')
      .orderBy('rating', descending: true)
      .orderBy('wins', descending: true)
      .limit(limit)
      .snapshots()
      .map((q) => [for (final d in q.docs) LeaderboardEntry.fromMap(d.id, d.data())]);
}
