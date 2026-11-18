import 'dart:ui';

import '../constants/board_constants.dart';

/// Converts between board cell numbers (1..100) and pixel coordinates for a
/// square board rendered at [size] logical pixels.
///
/// Cell 1 is at the bottom-left. Numbering zigzags: row 0 (bottom) runs left
/// to right, row 1 runs right to left, and so on, finishing with 100 in the
/// top-left corner.
class BoardGeometry {
  const BoardGeometry(this.size);

  /// Side length of the square board in logical pixels.
  final double size;

  /// Side length of a single cell.
  double get cellSize => size / BoardConstants.size;

  /// Returns (row, col) for a cell number, where row 0 is the bottom row and
  /// col 0 is the left column.
  static (int row, int col) rowColOf(int cell) {
    assert(cell >= 1 && cell <= BoardConstants.cellCount, 'cell out of range');
    final index = cell - 1;
    final row = index ~/ BoardConstants.size;
    var col = index % BoardConstants.size;
    if (row.isOdd) col = BoardConstants.size - 1 - col;
    return (row, col);
  }

  /// Returns the cell number at (row, col) or null if out of range.
  static int? cellAtRowCol(int row, int col) {
    if (row < 0 || row >= BoardConstants.size) return null;
    if (col < 0 || col >= BoardConstants.size) return null;
    final c = row.isOdd ? BoardConstants.size - 1 - col : col;
    return row * BoardConstants.size + c + 1;
  }

  /// Rectangle covering a cell. Cell 0 (start) maps to the cell-1 square.
  Rect rectOf(int cell) {
    final (row, col) = rowColOf(cell == BoardConstants.startCell ? 1 : cell);
    final cs = cellSize;
    final left = col * cs;
    final top = (BoardConstants.size - 1 - row) * cs;
    return Rect.fromLTWH(left, top, cs, cs);
  }

  /// Pixel centre of a cell.
  Offset centerOf(int cell) => rectOf(cell).center;

  /// Cell number under a local pixel offset, or null when outside the board.
  int? cellAt(Offset point) {
    if (point.dx < 0 || point.dy < 0 || point.dx >= size || point.dy >= size) {
      return null;
    }
    final col = point.dx ~/ cellSize;
    final rowFromTop = point.dy ~/ cellSize;
    final row = BoardConstants.size - 1 - rowFromTop;
    return cellAtRowCol(row, col);
  }
}
