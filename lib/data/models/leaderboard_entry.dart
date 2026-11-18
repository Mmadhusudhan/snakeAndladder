/// One row of `leaderboards/{period}/entries/{uid}`.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.avatar,
    required this.wins,
    required this.games,
    required this.rating,
  });

  final String uid;
  final String displayName;
  final String avatar;
  final int wins;
  final int games;
  final int rating;

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'avatar': avatar,
        'wins': wins,
        'games': games,
        'rating': rating,
      };

  factory LeaderboardEntry.fromMap(String uid, Map<String, dynamic> m) => LeaderboardEntry(
        uid: uid,
        displayName: (m['displayName'] as String?) ?? 'Player',
        avatar: (m['avatar'] as String?) ?? '🙂',
        wins: (m['wins'] as num?)?.toInt() ?? 0,
        games: (m['games'] as num?)?.toInt() ?? 0,
        rating: (m['rating'] as num?)?.toInt() ?? 0,
      );

  /// Highest rating first, then more wins, then name.
  static int compare(LeaderboardEntry a, LeaderboardEntry b) {
    final r = b.rating.compareTo(a.rating);
    if (r != 0) return r;
    final w = b.wins.compareTo(a.wins);
    if (w != 0) return w;
    return a.displayName.compareTo(b.displayName);
  }
}

/// Leaderboard windows the backend maintains.
enum LeaderboardPeriod { allTime, weekly }

extension LeaderboardPeriodInfo on LeaderboardPeriod {
  String get id => switch (this) {
        LeaderboardPeriod.allTime => 'allTime',
        LeaderboardPeriod.weekly => 'weekly',
      };

  String get label => switch (this) {
        LeaderboardPeriod.allTime => 'All time',
        LeaderboardPeriod.weekly => 'This week',
      };
}
