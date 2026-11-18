/// Static numbers that describe the board.
class BoardConstants {
  BoardConstants._();

  /// Number of columns and rows.
  static const int size = 10;

  /// Total playable cells (1..100).
  static const int cellCount = size * size;

  /// Players begin off the board on this virtual cell.
  static const int startCell = 0;

  /// The winning cell.
  static const int finalCell = cellCount;
}
