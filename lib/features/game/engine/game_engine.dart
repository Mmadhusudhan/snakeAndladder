import 'dart:async';

import '../../../core/constants/board_constants.dart';
import '../models/board_config.dart';
import '../models/bot_personality.dart';
import '../models/game_rules_config.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import 'dice.dart';
import 'game_rules.dart';

/// Injectable wait so tests can run instantly.
typedef DelayFn = Future<void> Function(Duration duration);

Future<void> _realDelay(Duration d) => Future<void>.delayed(d);

/// How long each phase of a move takes. The UI animations use the same
/// numbers so the engine and the screen stay in sync.
class EngineTimings {
  const EngineTimings({
    this.roll = const Duration(milliseconds: 1000),
    this.step = const Duration(milliseconds: 230),
    this.snake = const Duration(milliseconds: 700),
    this.snakePerCell = const Duration(milliseconds: 18),
    this.ladder = const Duration(milliseconds: 700),
    this.ladderPerCell = const Duration(milliseconds: 22),
    this.maxTransition = const Duration(milliseconds: 2400),
    this.switchTurn = const Duration(milliseconds: 450),
    this.computerThink = const Duration(milliseconds: 900),
  });

  final Duration roll;
  final Duration step;

  /// Base time for a snake slide; [snakePerCell] is added per cell of drop.
  final Duration snake;
  final Duration snakePerCell;

  /// Base time for a ladder climb; [ladderPerCell] is added per cell of rise.
  final Duration ladder;
  final Duration ladderPerCell;

  /// Upper bound for any slide or climb.
  final Duration maxTransition;
  final Duration switchTurn;
  final Duration computerThink;

  /// How long sliding from [from] down to [to] takes.
  Duration snakeDuration(int from, int to) =>
      _clampTransition(snake + snakePerCell * (from - to).abs());

  /// How long climbing from [from] up to [to] takes.
  Duration ladderDuration(int from, int to) =>
      _clampTransition(ladder + ladderPerCell * (from - to).abs());

  Duration _clampTransition(Duration d) => d > maxTransition ? maxTransition : d;

  static const EngineTimings instant = EngineTimings(
    roll: Duration.zero,
    step: Duration.zero,
    snake: Duration.zero,
    snakePerCell: Duration.zero,
    ladder: Duration.zero,
    ladderPerCell: Duration.zero,
    switchTurn: Duration.zero,
    computerThink: Duration.zero,
  );
}

/// Drives a game through its state machine.
///
/// The engine owns the [GameState], applies [GameRules], and sequences the
/// phases with delays so the UI can animate each step. All state changes go
/// through [_emit], so listeners always see a consistent snapshot.
class GameEngine {
  GameEngine({
    required List<Player> players,
    GameRulesConfig rulesConfig = GameRulesConfig.classic,
    BoardConfig board = BoardConfig.classic,
    Dice? dice,
    DelayFn? delay,
    this.timings = const EngineTimings(),
    this.autoPlayComputer = true,
    this.maxEvents = 50,
  })  : assert(players.length >= 2 && players.length <= 4,
            'Snakes & Ladders supports 2-4 players'),
        rules = GameRules(config: rulesConfig, board: board),
        _dice = dice ?? RandomDice(sides: rulesConfig.diceSides),
        _delay = delay ?? _realDelay,
        _initialPlayers = List.unmodifiable(players),
        _state = GameState(players: List.unmodifiable(players)) {
    assert(board.isValid, board.validate().join('; '));
  }

  final GameRules rules;
  final EngineTimings timings;
  final bool autoPlayComputer;
  final int maxEvents;

  final Dice _dice;
  final DelayFn _delay;
  final List<Player> _initialPlayers;

  GameState _state;
  final StreamController<GameState> _controller =
      StreamController<GameState>.broadcast();

  /// Incremented on reset/dispose so in-flight turns stop cleanly.
  int _generation = 0;
  bool _disposed = false;
  bool _started = false;

  GameState get state => _state;
  Stream<GameState> get stream => _controller.stream;
  bool get isDisposed => _disposed;

  /// Starts the game. Needed so a computer player going first rolls.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    _scheduleComputerTurn(_generation);
  }

  /// Rolls for the current player and plays out the whole turn.
  ///
  /// Returns false when the roll was refused (animation in progress, paused,
  /// finished, or disposed). Safe to call repeatedly: only the first call
  /// during [GamePhase.waiting] does anything.
  Future<bool> rollDice() async {
    if (_disposed || _state.isInputLocked) return false;
    final gen = _generation;
    final playerIndex = _state.currentPlayerIndex;
    final player = _state.currentPlayer;

    // Lock immediately (synchronously) so a double tap cannot roll twice.
    // The value is decided now so the dice animation can land on it.
    final roll = _rollFor(player);
    _emit(_state.copyWith(
      phase: GamePhase.rolling,
      clearLastRoll: true,
      pendingRoll: roll,
    ));
    if (!await _wait(timings.roll, gen)) return false;

    final sixes = roll == rules.config.diceSides
        ? _state.consecutiveSixes + 1
        : 0;
    _emit(_state.copyWith(
      lastRoll: roll,
      consecutiveSixes: sixes,
      stats: _bump(playerIndex, (st) => st.copyWith(
            rolls: st.rolls + 1,
            sixes: st.sixes + (roll == rules.config.diceSides ? 1 : 0),
          )),
      events: _append(GameEvent(
        type: GameEventType.rolled,
        playerIndex: playerIndex,
        dice: roll,
        message: '${player.name} rolled $roll',
      )),
    ));

    if (rules.forfeitsTurn(sixes)) {
      _emit(_state.copyWith(
        events: _append(GameEvent(
          type: GameEventType.forfeit,
          playerIndex: playerIndex,
          dice: roll,
          message: '${player.name} rolled $sixes sixes in a row and loses the turn',
        )),
      ));
      await _endTurn(gen, extraTurn: false);
      return true;
    }

    final move = rules.resolve(from: player.position, roll: roll);

    if (move.outcome == MoveOutcome.blocked) {
      _emit(_state.copyWith(
        stats: _bump(playerIndex, (st) => st.copyWith(blocked: st.blocked + 1)),
        events: _append(GameEvent(
          type: GameEventType.blocked,
          playerIndex: playerIndex,
          dice: roll,
          from: move.from,
          to: move.from,
          message: _blockedMessage(player, move),
        )),
      ));
      await _endTurn(gen, extraTurn: rules.grantsExtraTurn(roll));
      return true;
    }

    // Walk cell by cell.
    _emit(_state.copyWith(phase: GamePhase.moving));
    for (final cell in move.path) {
      _emit(_state.copyWith(players: _withPosition(playerIndex, cell)));
      if (!await _wait(timings.step, gen)) return false;
    }
    _emit(_state.copyWith(
      stats: _bump(playerIndex, (st) => st.copyWith(cellsMoved: st.cellsMoved + move.path.length)),
      events: _append(GameEvent(
        type: GameEventType.moved,
        playerIndex: playerIndex,
        dice: roll,
        from: move.from,
        to: move.landing,
        message: '${player.name} moved to ${move.landing}',
      )),
    ));

    switch (move.outcome) {
      case MoveOutcome.snake:
        _emit(_state.copyWith(
          phase: GamePhase.slidingSnake,
          transitionFrom: move.landing,
          transitionTo: move.finalPosition,
          stats: _bump(playerIndex, (st) => st.copyWith(snakes: st.snakes + 1)),
          events: _append(GameEvent(
            type: GameEventType.snake,
            playerIndex: playerIndex,
            from: move.landing,
            to: move.finalPosition,
            message:
                '🐍 ${player.name} was bitten! Down from ${move.landing} to ${move.finalPosition}',
          )),
        ));
        if (!await _wait(timings.snakeDuration(move.landing, move.finalPosition), gen)) {
          return false;
        }
        _emit(_state.copyWith(
          players: _withPosition(playerIndex, move.finalPosition),
          clearTransition: true,
          events: _append(_landed(playerIndex, player, move)),
        ));
      case MoveOutcome.ladder:
        _emit(_state.copyWith(
          phase: GamePhase.climbingLadder,
          transitionFrom: move.landing,
          transitionTo: move.finalPosition,
          stats: _bump(playerIndex, (st) => st.copyWith(ladders: st.ladders + 1)),
          events: _append(GameEvent(
            type: GameEventType.ladder,
            playerIndex: playerIndex,
            from: move.landing,
            to: move.finalPosition,
            message:
                '🪜 ${player.name} climbed from ${move.landing} to ${move.finalPosition}',
          )),
        ));
        if (!await _wait(timings.ladderDuration(move.landing, move.finalPosition), gen)) {
          return false;
        }
        _emit(_state.copyWith(
          players: _withPosition(playerIndex, move.finalPosition),
          clearTransition: true,
          events: _append(_landed(playerIndex, player, move)),
        ));
      case MoveOutcome.win:
        if (move.finalPosition != move.landing) {
          // Ladder straight to 100.
          _emit(_state.copyWith(
            phase: GamePhase.climbingLadder,
            transitionFrom: move.landing,
            transitionTo: move.finalPosition,
            stats: _bump(playerIndex, (st) => st.copyWith(ladders: st.ladders + 1)),
          ));
          if (!await _wait(timings.ladderDuration(move.landing, move.finalPosition), gen)) {
            return false;
          }
          _emit(_state.copyWith(
            players: _withPosition(playerIndex, move.finalPosition),
            clearTransition: true,
            events: _append(_landed(playerIndex, player, move)),
          ));
        }
      case MoveOutcome.normal:
      case MoveOutcome.blocked:
        break;
    }

    if (_state.players[playerIndex].position == BoardConstants.finalCell) {
      _emit(_state.copyWith(
        phase: GamePhase.completed,
        winnerIndex: playerIndex,
        completedAt: DateTime.now(),
        events: _append(GameEvent(
          type: GameEventType.won,
          playerIndex: playerIndex,
          to: BoardConstants.finalCell,
          message: '🏆 ${player.name} wins!',
        )),
      ));
      return true;
    }

    await _endTurn(gen, extraTurn: rules.grantsExtraTurn(roll));
    return true;
  }

  /// Pauses computer auto-play and refuses human rolls until [resume].
  void pause() {
    if (_disposed || _state.isPaused) return;
    _emit(_state.copyWith(isPaused: true));
  }

  void resume() {
    if (_disposed || !_state.isPaused) return;
    _emit(_state.copyWith(isPaused: false));
    _scheduleComputerTurn(_generation);
  }

  /// Jumps to a known position without animation (online sync / reconnect).
  /// Cancels any in-flight turn.
  void loadSnapshot({
    required List<int> positions,
    required int currentPlayerIndex,
    int turnNumber = 1,
    int consecutiveSixes = 0,
    int? lastRoll,
    List<bool>? forfeited,
    int? winnerIndex,
  }) {
    if (_disposed) return;
    assert(positions.length == _state.players.length);
    _generation++;
    _started = true;
    final players = <Player>[
      for (final (i, p) in _state.players.indexed)
        p.copyWith(
          position: positions[i].clamp(0, BoardConstants.finalCell),
          forfeited: forfeited == null ? p.forfeited : forfeited[i],
        ),
    ];
    final winner = winnerIndex ??
        (players.indexWhere((p) => p.position == BoardConstants.finalCell) >= 0
            ? players.indexWhere((p) => p.position == BoardConstants.finalCell)
            : null);
    _emit(GameState(
      players: List.unmodifiable(players),
      stats: _state.stats,
      startedAt: _state.startedAt,
      currentPlayerIndex: currentPlayerIndex,
      phase: winner == null ? GamePhase.waiting : GamePhase.completed,
      winnerIndex: winner,
      completedAt: winner == null ? null : DateTime.now(),
      turnNumber: turnNumber,
      consecutiveSixes: consecutiveSixes,
      lastRoll: lastRoll,
      events: _state.events,
    ));
    _scheduleComputerTurn(_generation);
  }

  /// Marks a player as having left. If it was their turn, play passes on.
  void setForfeited(int index, {bool value = true}) {
    if (_disposed) return;
    final players = List<Player>.of(_state.players);
    if (players[index].forfeited == value) return;
    players[index] = players[index].copyWith(forfeited: value);
    var next = _state.copyWith(players: List.unmodifiable(players));
    if (value && index == _state.currentPlayerIndex && _state.phase == GamePhase.waiting) {
      next = next.copyWith(currentPlayerIndex: _nextActiveIndex(index, players), consecutiveSixes: 0);
    }
    _emit(next);
  }

  /// Ends the game early (online forfeit) with [winnerIndex] as the winner.
  void declareWinner(int winnerIndex) {
    if (_disposed || _state.isCompleted) return;
    _generation++;
    _emit(_state.copyWith(
      phase: GamePhase.completed,
      winnerIndex: winnerIndex,
      completedAt: DateTime.now(),
      clearTransition: true,
      events: _append(GameEvent(
        type: GameEventType.won,
        playerIndex: winnerIndex,
        to: _state.players[winnerIndex].position,
        message: '🏆 ${_state.players[winnerIndex].name} wins!',
      )),
    ));
  }

  /// Starts a fresh game with the same players and rules.
  void reset() {
    if (_disposed) return;
    _generation++;
    _emit(GameState(players: _initialPlayers));
    _scheduleComputerTurn(_generation);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _controller.close();
  }

  // ---------------------------------------------------------------------------

  Future<void> _endTurn(int gen, {required bool extraTurn}) async {
    final playerIndex = _state.currentPlayerIndex;
    final player = _state.currentPlayer;
    _emit(_state.copyWith(phase: GamePhase.switchingTurn));
    if (!await _wait(timings.switchTurn, gen)) return;

    if (extraTurn) {
      _emit(_state.copyWith(
        phase: GamePhase.waiting,
        turnNumber: _state.turnNumber + 1,
        events: _append(GameEvent(
          type: GameEventType.extraTurn,
          playerIndex: playerIndex,
          message: '🎲 ${player.name} rolled a six and goes again',
        )),
      ));
    } else {
      _emit(_state.copyWith(
        phase: GamePhase.waiting,
        currentPlayerIndex: _nextActiveIndex(playerIndex, _state.players),
        consecutiveSixes: 0,
        turnNumber: _state.turnNumber + 1,
      ));
    }
    _scheduleComputerTurn(gen);
  }

  void _scheduleComputerTurn(int gen) {
    if (!autoPlayComputer || !_started) return;
    if (_state.phase != GamePhase.waiting || _state.isPaused) return;
    if (!_state.currentPlayer.isComputer) return;
    unawaited(_computerTurn(gen));
  }

  Future<void> _computerTurn(int gen) async {
    final factor = (_state.currentPlayer.level ?? ComputerLevel.normal).thinkFactor;
    final think = timings.computerThink * factor;
    if (!await _wait(think, gen)) return;
    if (_state.isPaused || _state.phase != GamePhase.waiting) return;
    if (!_state.currentPlayer.isComputer) return;
    await rollDice();
  }

  /// Waits, then reports whether this turn is still the live one.
  Future<bool> _wait(Duration d, int gen) async {
    if (d > Duration.zero) await _delay(d);
    return !_disposed && gen == _generation;
  }

  /// Rolls for [player]. Humans and normal bots use the dice as is. A hard
  /// bot rolls twice and keeps the better result; an easy bot rolls twice
  /// and keeps the worse one half of the time.
  int _rollFor(Player player) {
    final level = player.isComputer ? player.level : null;
    if (level == null || level == ComputerLevel.normal) return _dice.roll();
    final a = _dice.roll();
    final b = _dice.roll();
    final sa = _score(player.position, a);
    final sb = _score(player.position, b);
    switch (level) {
      case ComputerLevel.hard:
        return sa >= sb ? a : b;
      case ComputerLevel.easy:
        final keepWorse = _dice.roll() <= _dice.sides ~/ 2;
        if (!keepWorse) return a;
        return sa <= sb ? a : b;
      case ComputerLevel.normal:
        return a;
    }
  }

  /// How good a roll is from [from]: progress made, big bonus for ladders
  /// and winning, big penalty for snakes.
  int _score(int from, int roll) {
    final m = rules.resolve(from: from, roll: roll);
    switch (m.outcome) {
      case MoveOutcome.win:
        return 1000;
      case MoveOutcome.ladder:
        return 100 + (m.finalPosition - from);
      case MoveOutcome.normal:
        return m.finalPosition - from;
      case MoveOutcome.blocked:
        return -10;
      case MoveOutcome.snake:
        return -100 - (from - m.finalPosition);
    }
  }

  /// Next seat that has not forfeited (wraps around; falls back to [from]).
  int _nextActiveIndex(int from, List<Player> players) {
    for (var i = 1; i <= players.length; i++) {
      final cand = rules.nextPlayerIndex(from + i - 1, players.length);
      if (!players[cand].forfeited) return cand;
    }
    return from;
  }

  List<PlayerStats> _bump(int index, PlayerStats Function(PlayerStats) update) {
    final list = List<PlayerStats>.of(_state.stats);
    list[index] = update(list[index]);
    return List.unmodifiable(list);
  }

  List<Player> _withPosition(int index, int position) {
    final list = List<Player>.of(_state.players);
    list[index] = list[index].copyWith(position: position);
    return List.unmodifiable(list);
  }

  List<GameEvent> _append(GameEvent event) {
    final list = List<GameEvent>.of(_state.events)..add(event);
    if (list.length > maxEvents) list.removeRange(0, list.length - maxEvents);
    return List.unmodifiable(list);
  }

  GameEvent _landed(int playerIndex, Player player, MoveResolution move) {
    return GameEvent(
      type: GameEventType.landed,
      playerIndex: playerIndex,
      from: move.landing,
      to: move.finalPosition,
      message: '${player.name} is now on ${move.finalPosition}',
    );
  }

  String _blockedMessage(Player player, MoveResolution move) {
    if (rules.config.needSixToStart && move.from == BoardConstants.startCell) {
      return '${player.name} needs a six to start';
    }
    final needed = BoardConstants.finalCell - move.from;
    return '${player.name} needs exactly $needed to finish';
  }

  void _emit(GameState next) {
    if (_disposed) return;
    _state = next;
    _controller.add(next);
  }
}
