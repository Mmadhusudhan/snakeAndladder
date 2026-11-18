import 'player.dart';

/// The state machine phases of a game.
enum GamePhase {
  /// Waiting for the current player to roll.
  waiting,

  /// Dice animation in progress.
  rolling,

  /// Token walking cell by cell.
  moving,

  /// Token climbing a ladder.
  climbingLadder,

  /// Token sliding down a snake.
  slidingSnake,

  /// Short pause before the next player's turn.
  switchingTurn,

  /// Someone reached 100.
  completed,
}

/// Kinds of events that appear in the game log.
enum GameEventType {
  rolled,
  moved,
  blocked,
  snake,
  ladder,

  /// Token arrived at the end of a snake or ladder.
  landed,
  extraTurn,
  forfeit,
  won,
}

/// A single thing that happened, used for the log and for sounds later.
class GameEvent {
  const GameEvent({
    required this.type,
    required this.playerIndex,
    required this.message,
    this.from,
    this.to,
    this.dice,
  });

  final GameEventType type;
  final int playerIndex;
  final String message;
  final int? from;
  final int? to;
  final int? dice;

  @override
  String toString() => message;
}

/// Per-player counters for the result screen and (later) online stats.
class PlayerStats {
  const PlayerStats({
    this.rolls = 0,
    this.sixes = 0,
    this.snakes = 0,
    this.ladders = 0,
    this.blocked = 0,
    this.cellsMoved = 0,
  });

  final int rolls;
  final int sixes;
  final int snakes;
  final int ladders;
  final int blocked;

  /// Cells walked by dice (excludes snake / ladder jumps).
  final int cellsMoved;

  PlayerStats copyWith({
    int? rolls,
    int? sixes,
    int? snakes,
    int? ladders,
    int? blocked,
    int? cellsMoved,
  }) {
    return PlayerStats(
      rolls: rolls ?? this.rolls,
      sixes: sixes ?? this.sixes,
      snakes: snakes ?? this.snakes,
      ladders: ladders ?? this.ladders,
      blocked: blocked ?? this.blocked,
      cellsMoved: cellsMoved ?? this.cellsMoved,
    );
  }
}

/// Everything the UI needs to draw a game.
class GameState {
  GameState({
    required this.players,
    List<PlayerStats>? stats,
    DateTime? startedAt,
    this.completedAt,
    this.currentPlayerIndex = 0,
    this.phase = GamePhase.waiting,
    this.lastRoll,
    this.pendingRoll,
    this.winnerIndex,
    this.turnNumber = 1,
    this.consecutiveSixes = 0,
    this.events = const [],
    this.transitionFrom,
    this.transitionTo,
    this.isPaused = false,
  })  : stats = stats ?? List.filled(players.length, const PlayerStats()),
        startedAt = startedAt ?? DateTime.now();

  final List<Player> players;

  /// Counters per player, same order as [players].
  final List<PlayerStats> stats;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int currentPlayerIndex;
  final GamePhase phase;
  /// The value shown on the dice once the roll animation has finished.
  final int? lastRoll;

  /// The value the dice will land on. Set as soon as [GamePhase.rolling]
  /// starts so the dice animation can tumble towards the right face. Not
  /// shown to players until it becomes [lastRoll].
  final int? pendingRoll;
  final int? winnerIndex;
  final int turnNumber;

  /// Sixes rolled in a row by the current player.
  final int consecutiveSixes;

  /// Most recent events, newest last.
  final List<GameEvent> events;

  /// Start cell of an active snake / ladder transition (for animation).
  final int? transitionFrom;

  /// End cell of an active snake / ladder transition.
  final int? transitionTo;

  final bool isPaused;

  Player get currentPlayer => players[currentPlayerIndex];
  Player? get winner => winnerIndex == null ? null : players[winnerIndex!];
  bool get isCompleted => phase == GamePhase.completed;

  /// True while the dice must not be rolled.
  bool get isInputLocked => phase != GamePhase.waiting || isPaused;

  /// True when a human should press the dice.
  bool get awaitingHumanRoll =>
      phase == GamePhase.waiting && !isPaused && !currentPlayer.isComputer;

  GameEvent? get lastEvent => events.isEmpty ? null : events.last;

  /// Wall-clock length of the match (until now if still running).
  Duration get elapsed => (completedAt ?? DateTime.now()).difference(startedAt);

  /// Player indices ordered best to worst: furthest along first, ties
  /// broken by fewer rolls.
  List<int> get ranking {
    final idx = List<int>.generate(players.length, (i) => i);
    idx.sort((a, b) {
      final byPos = players[b].position.compareTo(players[a].position);
      if (byPos != 0) return byPos;
      return stats[a].rolls.compareTo(stats[b].rolls);
    });
    return idx;
  }

  GameState copyWith({
    List<Player>? players,
    List<PlayerStats>? stats,
    DateTime? completedAt,
    int? currentPlayerIndex,
    GamePhase? phase,
    int? lastRoll,
    bool clearLastRoll = false,
    int? pendingRoll,
    int? winnerIndex,
    int? turnNumber,
    int? consecutiveSixes,
    List<GameEvent>? events,
    int? transitionFrom,
    int? transitionTo,
    bool clearTransition = false,
    bool? isPaused,
  }) {
    return GameState(
      players: players ?? this.players,
      stats: stats ?? this.stats,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      phase: phase ?? this.phase,
      lastRoll: clearLastRoll ? null : (lastRoll ?? this.lastRoll),
      pendingRoll: pendingRoll ?? this.pendingRoll,
      winnerIndex: winnerIndex ?? this.winnerIndex,
      turnNumber: turnNumber ?? this.turnNumber,
      consecutiveSixes: consecutiveSixes ?? this.consecutiveSixes,
      events: events ?? this.events,
      transitionFrom:
          clearTransition ? null : (transitionFrom ?? this.transitionFrom),
      transitionTo: clearTransition ? null : (transitionTo ?? this.transitionTo),
      isPaused: isPaused ?? this.isPaused,
    );
  }
}
