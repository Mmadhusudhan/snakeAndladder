
import 'package:flutter_test/flutter_test.dart';
import 'package:snakes_ladders/core/utils/board_geometry.dart';

void main() {
  group('BoardGeometry zigzag numbering', () {
    test('bottom row runs left to right', () {
      expect(BoardGeometry.rowColOf(1), (0, 0));
      expect(BoardGeometry.rowColOf(10), (0, 9));
    });

    test('second row runs right to left', () {
      expect(BoardGeometry.rowColOf(11), (1, 9));
      expect(BoardGeometry.rowColOf(20), (1, 0));
    });

    test('100 is in the top-left corner', () {
      expect(BoardGeometry.rowColOf(100), (9, 0));
      expect(BoardGeometry.rowColOf(91), (9, 9));
    });

    test('cellAtRowCol inverts rowColOf for every cell', () {
      for (var cell = 1; cell <= 100; cell++) {
        final (r, c) = BoardGeometry.rowColOf(cell);
        expect(BoardGeometry.cellAtRowCol(r, c), cell);
      }
    });
  });

  group('BoardGeometry pixels', () {
    const g = BoardGeometry(400);

    test('cell size is a tenth of the board', () {
      expect(g.cellSize, 40);
    });

    test('cell 1 is bottom-left and 100 is top-left', () {
      expect(g.centerOf(1), const Offset(20, 380));
      expect(g.centerOf(100), const Offset(20, 20));
      expect(g.centerOf(10), const Offset(380, 380));
    });

    test('start cell draws at cell 1', () {
      expect(g.centerOf(0), g.centerOf(1));
    });

    test('cellAt round-trips every centre and rejects outside points', () {
      for (var cell = 1; cell <= 100; cell++) {
        expect(g.cellAt(g.centerOf(cell)), cell);
      }
      expect(g.cellAt(const Offset(-1, 10)), isNull);
      expect(g.cellAt(const Offset(10, 400)), isNull);
    });
  });
}
