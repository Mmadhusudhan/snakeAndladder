/// Tunable rules. Every rule in the game is driven from here so modes
/// (classic, quick, kids) can be built by changing values, not code.
class GameRulesConfig {
  const GameRulesConfig({
    this.exactRollToWin = true,
    this.extraTurnOnSix = true,
    this.needSixToStart = false,
    this.maxConsecutiveSixes = 3,
    this.diceSides = 6,
  })  : assert(diceSides >= 2),
        assert(maxConsecutiveSixes >= 0);

  /// Must land exactly on 100. Overshooting means the token does not move.
  final bool exactRollToWin;

  /// Rolling a six gives the same player another turn.
  final bool extraTurnOnSix;

  /// A player needs a six to leave the start area.
  final bool needSixToStart;

  /// Rolling this many sixes in a row forfeits the turn (0 disables).
  final int maxConsecutiveSixes;

  /// Sides on the dice.
  final int diceSides;

  static const GameRulesConfig classic = GameRulesConfig();

  GameRulesConfig copyWith({
    bool? exactRollToWin,
    bool? extraTurnOnSix,
    bool? needSixToStart,
    int? maxConsecutiveSixes,
    int? diceSides,
  }) {
    return GameRulesConfig(
      exactRollToWin: exactRollToWin ?? this.exactRollToWin,
      extraTurnOnSix: extraTurnOnSix ?? this.extraTurnOnSix,
      needSixToStart: needSixToStart ?? this.needSixToStart,
      maxConsecutiveSixes: maxConsecutiveSixes ?? this.maxConsecutiveSixes,
      diceSides: diceSides ?? this.diceSides,
    );
  }
}
