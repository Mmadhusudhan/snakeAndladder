import 'package:flutter_test/flutter_test.dart';
import 'package:snakes_ladders/features/game/board/board_painter.dart';
import 'package:snakes_ladders/features/game/board/ladder_renderer.dart';
import 'package:snakes_ladders/features/game/models/board_config.dart';

void main() {
  final layout = BoardLayout(size: 400, board: BoardConfig.classic);
  const cs = 40.0;

  group('SnakeShape', () {
    test('spine starts at the head cell and ends at the tail cell', () {
      for (final s in layout.snakes) {
        expect(s.pointAt(0), layout.geometry.centerOf(s.head));
        expect((s.pointAt(1) - layout.geometry.centerOf(s.tail)).distance, lessThan(0.5));
      }
    });

    test('sway never moves the head or tail out of their cells', () {
      final s = layout.snakes.first;
      for (final time in [0.0, 0.25, 0.5, 0.8]) {
        expect(s.swayedPointAt(0, time, cs, intensity: 3), s.pointAt(0));
        expect((s.swayedPointAt(1, time, cs, intensity: 3) - s.pointAt(1)).distance, lessThan(0.5));
      }
    });

    test('swayed points differ from the spine in the middle', () {
      final s = layout.snakes.first;
      final moved = s.swayedPointAt(0.5, 0.2, cs);
      expect((moved - s.pointAt(0.5)).distance, greaterThan(0.1));
    });

    test('tangent is a unit vector', () {
      final s = layout.snakes.last;
      for (final t in [0.0, 0.3, 0.7, 1.0]) {
        expect(s.tangentAt(t).distance, closeTo(1, 1e-6));
      }
    });
  });

  group('LadderShape', () {
    final ladder = layout.ladderAt(28)!; // 28 -> 84, a long one

    test('rungs are spaced along the rails and sit between the ends', () {
      final rungs = ladder.rungPositions(cs);
      expect(rungs.length, greaterThan(5));
      for (var i = 1; i < rungs.length; i++) {
        expect((rungs[i] - rungs[i - 1]).distance, closeTo((rungs[1] - rungs[0]).distance, 1e-6));
      }
      expect((rungs.first - ladder.bottomCenter).distance, lessThan(ladder.length));
      expect((rungs.last - ladder.topCenter).distance, lessThan(ladder.length));
    });

    test('climb starts at the bottom cell and ends at the top cell', () {
      expect(ladder.climbPositionAt(0, cs), ladder.bottomCenter);
      expect(ladder.climbPositionAt(1, cs), ladder.topCenter);
    });

    test('climb is monotonic towards the top', () {
      var last = double.infinity;
      for (var p = 0.0; p <= 1.0; p += 0.02) {
        final d = (ladder.topCenter - ladder.climbPositionAt(p, cs)).distance;
        expect(d, lessThanOrEqualTo(last + 1e-6));
        last = d;
      }
    });

    test('active rung is null on the ground and on top, and increases', () {
      expect(ladder.activeRungAt(0, cs), isNull);
      expect(ladder.activeRungAt(1, cs), isNull);
      final rungs = ladder.rungPositions(cs).length;
      var lastRung = -1;
      for (var p = 0.05; p < 0.999; p += 0.01) {
        final r = ladder.activeRungAt(p, cs);
        if (r != null) {
          expect(r, greaterThanOrEqualTo(lastRung));
          expect(r, lessThan(rungs));
          lastRung = r;
        }
      }
      expect(lastRung, rungs - 1);
    });
  });

  test('short ladder with no rungs still climbs', () {
    const tiny = LadderShape(bottom: 1, top: 2, bottomCenter: Offset(0, 0), topCenter: Offset(10, 0));
    expect(tiny.rungPositions(40).length, 1);
    expect(tiny.climbPositionAt(0.5, 40).dx, inInclusiveRange(0, 10));
  });
}
