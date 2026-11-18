import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:snakes_ladders/features/game/animations/dice_cube_math.dart';

void main() {
  test('opposite faces sum to seven', () {
    for (final f in DiceCubeMath.faces) {
      final opposite = DiceCubeMath.faces.firstWhere((o) => o.normal == -f.normal);
      expect(f.value + opposite.value, 7);
    }
  });

  test('target rotation brings each value to the front', () {
    for (var v = 1; v <= 6; v++) {
      final (rx, ry) = DiceCubeMath.targetRotation(v);
      expect(DiceCubeMath.frontValue(rx, ry), v, reason: 'value $v');
    }
  });

  test('face rotations point each face along its normal', () {
    for (final f in DiceCubeMath.faces) {
      final n = f.rotation.transform3(DiceCubeMath.faces.first.normal.clone());
      expect((n - f.normal).length, lessThan(1e-9), reason: 'face ${f.value}');
    }
  });

  test('spinTo adds whole turns and keeps the final orientation', () {
    final end = DiceCubeMath.spinTo(0.3, math.pi / 2, 2);
    expect(end, greaterThan(0.3 + 2 * 2 * math.pi));
    expect(DiceCubeMath.frontValue(0, end), DiceCubeMath.frontValue(0, math.pi / 2));
  });

  test('targetRotation rejects invalid values', () {
    expect(() => DiceCubeMath.targetRotation(7), throwsArgumentError);
  });
}
