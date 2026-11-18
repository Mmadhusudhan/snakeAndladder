import '../../../core/constants/board_constants.dart';
import '../models/board_config.dart';
import '../models/game_rules_config.dart';

/// What happened when a roll was applied.
enum MoveOutcome {
  /// Plain move, no special cell.
  normal,

  /// The roll could not be used (overshoot or need-six-to-start).
  blocked,

  /// Landed on a snake head.
  snake,

  /// Landed on a ladder bottom.
  ladder,

  /// Reached the final cell.
  win,
}

/// A resolved move: the path walked and where the token ends up.
class MoveResolution {
  const MoveResolution({
    required this.from,
    required this.roll,
    required this.path,
    required this.landing,
    required this.finalPosition,
    required this.outcome,
  });

  final int from;
  final int roll;

  /// Cells stepped through by the dice movement (excludes [from]).
  final List<int> path;

  /// Cell reached by the dice before snakes or ladders apply.
  final int landing;

  /// Cell after snakes or ladders apply.
  final int finalPosition;
  final MoveOutcome outcome;

  bool get moved => path.isNotEmpty;
}

/// Pure rules. No state, no timing, no UI. Fully unit-testable.
class GameRules {
  const GameRules({
    this.config = GameRulesConfig.classic,
    this.board = BoardConfig.classic,
  });

  final GameRulesConfig config;
  final BoardConfig board;

  /// Applies [roll] to a token on [from].
  MoveResolution resolve({required int from, required int roll}) {
    assert(roll >= 1 && roll <= config.diceSides, 'roll out of range');
    const finalCell = BoardConstants.finalCell;

    MoveResolution blocked() => MoveResolution(
          from: from,
          roll: roll,
          path: const [],
          landing: from,
          finalPosition: from,
          outcome: MoveOutcome.blocked,
        );

    if (from >= finalCell) return blocked();

    if (config.needSixToStart &&
        from == BoardConstants.startCell &&
        roll != config.diceSides) {
      return blocked();
    }

    var landing = from + roll;
    if (landing > finalCell) {
      if (config.exactRollToWin) return blocked();
      landing = finalCell;
    }

    final path = [for (var c = from + 1; c <= landing; c++) c];

    if (landing == finalCell) {
      return MoveResolution(
        from: from,
        roll: roll,
        path: path,
        landing: landing,
        finalPosition: landing,
        outcome: MoveOutcome.win,
      );
    }

    final snakeTail = board.snakeTailAt(landing);
    if (snakeTail != null) {
      return MoveResolution(
        from: from,
        roll: roll,
        path: path,
        landing: landing,
        finalPosition: snakeTail,
        outcome: MoveOutcome.snake,
      );
    }

    final ladderTop = board.ladderTopAt(landing);
    if (ladderTop != null) {
      return MoveResolution(
        from: from,
        roll: roll,
        path: path,
        landing: landing,
        finalPosition: ladderTop,
        outcome: ladderTop == finalCell ? MoveOutcome.win : MoveOutcome.ladder,
      );
    }

    return MoveResolution(
      from: from,
      roll: roll,
      path: path,
      landing: landing,
      finalPosition: landing,
      outcome: MoveOutcome.normal,
    );
  }

  /// Whether this roll earns another turn.
  bool grantsExtraTurn(int roll) =>
      config.extraTurnOnSix && roll == config.diceSides;

  /// Whether rolling this many sixes in a row forfeits the turn.
  bool forfeitsTurn(int consecutiveSixes) =>
      config.maxConsecutiveSixes > 0 &&
      consecutiveSixes >= config.maxConsecutiveSixes;

  /// Index of the player who plays after [current].
  int nextPlayerIndex(int current, int playerCount) {
    assert(playerCount > 0);
    return (current + 1) % playerCount;
  }
}
