/// Lifetime counters stored on `users/{uid}.stats`.
///
/// The same rules live in the backend (`backend/src/services/stats.service.js`)
/// so client-side casual updates and server-validated updates agree.
class ProfileStats {
  const ProfileStats({
    this.games = 0,
    this.wins = 0,
    this.losses = 0,
    this.winStreak = 0,
    this.bestWinTurns,
    this.totalTurns = 0,
    this.snakes = 0,
    this.ladders = 0,
    this.rating = baseRating,
  });

  static const int baseRating = 1000;
  static const int winPoints = 25;
  static const int lossPoints = 10;

  final int games;
  final int wins;
  final int losses;
  final int winStreak;
  final int? bestWinTurns;
  final int totalTurns;
  final int snakes;
  final int ladders;
  final int rating;

  double get winRate => games == 0 ? 0 : wins / games;

  /// Applies one finished match.
  ProfileStats applyMatch({
    required bool won,
    required int turns,
    required int snakes,
    required int ladders,
  }) {
    final nextWins = wins + (won ? 1 : 0);
    final nextLosses = losses + (won ? 0 : 1);
    return ProfileStats(
      games: games + 1,
      wins: nextWins,
      losses: nextLosses,
      winStreak: won ? winStreak + 1 : 0,
      bestWinTurns: won
          ? (bestWinTurns == null ? turns : (turns < bestWinTurns! ? turns : bestWinTurns))
          : bestWinTurns,
      totalTurns: totalTurns + turns,
      snakes: this.snakes + snakes,
      ladders: this.ladders + ladders,
      rating: ratingFor(wins: nextWins, losses: nextLosses),
    );
  }

  static int ratingFor({required int wins, required int losses}) =>
      (baseRating + wins * winPoints - losses * lossPoints).clamp(0, 1 << 30);

  Map<String, dynamic> toMap() => {
        'games': games,
        'wins': wins,
        'losses': losses,
        'winStreak': winStreak,
        'bestWinTurns': bestWinTurns,
        'totalTurns': totalTurns,
        'snakes': snakes,
        'ladders': ladders,
        'rating': rating,
      };

  factory ProfileStats.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const ProfileStats();
    int i(String k) => (m[k] as num?)?.toInt() ?? 0;
    return ProfileStats(
      games: i('games'),
      wins: i('wins'),
      losses: i('losses'),
      winStreak: i('winStreak'),
      bestWinTurns: (m['bestWinTurns'] as num?)?.toInt(),
      totalTurns: i('totalTurns'),
      snakes: i('snakes'),
      ladders: i('ladders'),
      rating: (m['rating'] as num?)?.toInt() ?? baseRating,
    );
  }
}

/// A player's public profile document (`users/{uid}`).
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.avatar,
    required this.isGuest,
    this.stats = const ProfileStats(),
    this.createdAt,
    this.lastSeenAt,
  });

  final String uid;
  final String displayName;
  final String avatar;
  final bool isGuest;
  final ProfileStats stats;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;

  UserProfile copyWith({
    String? displayName,
    String? avatar,
    ProfileStats? stats,
    DateTime? lastSeenAt,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      isGuest: isGuest,
      stats: stats ?? this.stats,
      createdAt: createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'avatar': avatar,
        'isGuest': isGuest,
        'stats': stats.toMap(),
        'createdAt': createdAt?.toUtc().toIso8601String(),
        'lastSeenAt': lastSeenAt?.toUtc().toIso8601String(),
      };

  factory UserProfile.fromMap(String uid, Map<String, dynamic> m) => UserProfile(
        uid: uid,
        displayName: (m['displayName'] as String?) ?? 'Player',
        avatar: (m['avatar'] as String?) ?? '🦁',
        isGuest: (m['isGuest'] as bool?) ?? true,
        stats: ProfileStats.fromMap(m['stats'] as Map<String, dynamic>?),
        createdAt: parseDate(m['createdAt']),
        lastSeenAt: parseDate(m['lastSeenAt']),
      );

  /// Accepts ISO strings, millis, or objects with `toDate()` (Timestamp).
  static DateTime? parseDate(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
    try {
      // ignore: avoid_dynamic_calls
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }
}
