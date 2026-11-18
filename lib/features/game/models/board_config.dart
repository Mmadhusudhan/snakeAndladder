import '../../../core/constants/board_constants.dart';

/// Where the snakes and ladders live on the board.
///
/// `snakes` maps head cell -> tail cell (head > tail).
/// `ladders` maps bottom cell -> top cell (bottom < top).
class BoardConfig {
  const BoardConfig({required this.snakes, required this.ladders});

  final Map<int, int> snakes;
  final Map<int, int> ladders;

  /// The classic layout: 10 snakes and 9 ladders.
  static const BoardConfig classic = BoardConfig(
    snakes: {
      16: 6,
      47: 26,
      49: 11,
      56: 53,
      62: 19,
      64: 60,
      87: 24,
      93: 73,
      95: 75,
      98: 78,
    },
    ladders: {
      1: 38,
      4: 14,
      9: 31,
      21: 42,
      28: 84,
      36: 44,
      51: 67,
      71: 91,
      80: 100,
    },
  );

  int? snakeTailAt(int cell) => snakes[cell];
  int? ladderTopAt(int cell) => ladders[cell];
  bool isSnakeHead(int cell) => snakes.containsKey(cell);
  bool isLadderBottom(int cell) => ladders.containsKey(cell);

  /// Returns a list of problems; an empty list means the board is valid.
  List<String> validate() {
    final issues = <String>[];
    bool onBoard(int c) => c >= 1 && c <= BoardConstants.cellCount;

    for (final e in snakes.entries) {
      if (!onBoard(e.key) || !onBoard(e.value)) {
        issues.add('Snake ${e.key}->${e.value} is off the board');
      } else if (e.key <= e.value) {
        issues.add('Snake ${e.key}->${e.value} must go down');
      }
      if (e.key == BoardConstants.finalCell) {
        issues.add('Snake head cannot be on the final cell');
      }
      if (ladders.containsKey(e.key)) {
        issues.add('Cell ${e.key} is both a snake head and a ladder bottom');
      }
      if (snakes.containsKey(e.value) || ladders.containsKey(e.value)) {
        issues.add('Snake tail ${e.value} lands on another snake or ladder');
      }
    }
    for (final e in ladders.entries) {
      if (!onBoard(e.key) || !onBoard(e.value)) {
        issues.add('Ladder ${e.key}->${e.value} is off the board');
      } else if (e.key >= e.value) {
        issues.add('Ladder ${e.key}->${e.value} must go up');
      }
      if (snakes.containsKey(e.value) || ladders.containsKey(e.value)) {
        issues.add('Ladder top ${e.value} lands on another snake or ladder');
      }
    }
    return issues;
  }

  bool get isValid => validate().isEmpty;
}
