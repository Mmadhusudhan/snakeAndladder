import '../../features/game/models/game_state.dart';
import '../../providers/game_providers.dart';
import 'user_profile.dart';

/// One seat in a finished match.
class MatchPlayer {
  const MatchPlayer({
    required this.name,
    required this.avatar,
    required this.colorIndex,
    required this.isComputer,
    required this.position,
    required this.rolls,
    required this.snakes,
    required this.ladders,
  });

  final String name;
  final String avatar;
  final int colorIndex;
  final bool isComputer;
  final int position;
  final int rolls;
  final int snakes;
  final int ladders;

  Map<String, dynamic> toMap() => {
        'name': name,
        'avatar': avatar,
        'colorIndex': colorIndex,
        'isComputer': isComputer,
        'position': position,
        'rolls': rolls,
        'snakes': snakes,
        'ladders': ladders,
      };

  factory MatchPlayer.fromMap(Map<String, dynamic> m) => MatchPlayer(
        name: (m['name'] as String?) ?? 'Player',
        avatar: (m['avatar'] as String?) ?? '🙂',
        colorIndex: (m['colorIndex'] as num?)?.toInt() ?? 0,
        isComputer: (m['isComputer'] as bool?) ?? false,
        position: (m['position'] as num?)?.toInt() ?? 0,
        rolls: (m['rolls'] as num?)?.toInt() ?? 0,
        snakes: (m['snakes'] as num?)?.toInt() ?? 0,
        ladders: (m['ladders'] as num?)?.toInt() ?? 0,
      );
}

/// A finished match as stored in `game_history/{uid}/games/{id}`.
class MatchRecord {
  const MatchRecord({
    required this.id,
    required this.mode,
    required this.players,
    required this.winnerIndex,
    required this.myIndex,
    required this.turns,
    required this.durationMs,
    required this.endedAt,
    this.exactRollToWin = true,
  });

  final String id;
  final GameMode mode;
  final List<MatchPlayer> players;
  final int winnerIndex;

  /// Seat of the signed-in user, or null when nobody at the table is them
  /// specifically (pass-and-play).
  final int? myIndex;
  final int turns;
  final int durationMs;
  final DateTime endedAt;
  final bool exactRollToWin;

  bool get iWon => myIndex != null && winnerIndex == myIndex;
  MatchPlayer get winner => players[winnerIndex];
  MatchPlayer? get me => myIndex == null ? null : players[myIndex!];

  /// Only matches against the computer feed wins, losses and rating.
  /// Pass-and-play is history only, and practice never counts.
  bool get countsForStats => mode == GameMode.vsComputer && myIndex != null;

  /// Builds a record from a completed game. [myIndex] is the seat of the
  /// signed-in user (seat 0 against the computer).
  factory MatchRecord.fromGame(GameState state, GameSetup setup, {int? myIndex, String? id}) {
    final ended = state.completedAt ?? DateTime.now();
    return MatchRecord(
      id: id ?? ended.toUtc().millisecondsSinceEpoch.toString(),
      mode: setup.mode,
      players: [
        for (final (i, p) in state.players.indexed)
          MatchPlayer(
            name: p.name,
            avatar: p.avatar,
            colorIndex: p.colorIndex,
            isComputer: p.isComputer,
            position: p.position,
            rolls: state.stats[i].rolls,
            snakes: state.stats[i].snakes,
            ladders: state.stats[i].ladders,
          ),
      ],
      winnerIndex: state.winnerIndex ?? 0,
      myIndex: myIndex,
      turns: state.turnNumber,
      durationMs: ended.difference(state.startedAt).inMilliseconds,
      endedAt: ended,
      exactRollToWin: setup.rules.exactRollToWin,
    );
  }

  Map<String, dynamic> toMap() => {
        'mode': mode.name,
        'players': [for (final p in players) p.toMap()],
        'winnerIndex': winnerIndex,
        'myIndex': myIndex,
        'turns': turns,
        'durationMs': durationMs,
        'endedAt': endedAt.toUtc().toIso8601String(),
        'exactRollToWin': exactRollToWin,
      };

  factory MatchRecord.fromMap(String id, Map<String, dynamic> m) => MatchRecord(
        id: id,
        mode: GameMode.values.firstWhere(
          (g) => g.name == m['mode'],
          orElse: () => GameMode.localMultiplayer,
        ),
        players: [
          for (final p in (m['players'] as List? ?? const []))
            MatchPlayer.fromMap(Map<String, dynamic>.from(p as Map)),
        ],
        winnerIndex: (m['winnerIndex'] as num?)?.toInt() ?? 0,
        myIndex: (m['myIndex'] as num?)?.toInt(),
        turns: (m['turns'] as num?)?.toInt() ?? 0,
        durationMs: (m['durationMs'] as num?)?.toInt() ?? 0,
        endedAt: UserProfile.parseDate(m['endedAt']) ?? DateTime.now(),
        exactRollToWin: (m['exactRollToWin'] as bool?) ?? true,
      );
}
