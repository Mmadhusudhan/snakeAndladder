import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

/// One face of a dice cube.
class DiceFace {
  const DiceFace(this.value, this.normal, this.rotation);

  /// Pips shown on the face.
  final int value;

  /// Outward normal in cube space. Flutter's +Z points into the screen, so
  /// the face towards the viewer has normal (0, 0, -1).
  final Vector3 normal;

  /// Rotation that turns a face lying in the XY plane (normal -Z) so that it
  /// points along [normal].
  final Matrix4 rotation;
}

/// Pure maths for a 3D dice: which way each face points and how to rotate
/// the cube so a given value faces the viewer. Opposite faces sum to 7.
class DiceCubeMath {
  DiceCubeMath._();

  static final List<DiceFace> faces = [
    DiceFace(1, Vector3(0, 0, -1), Matrix4.identity()),
    DiceFace(6, Vector3(0, 0, 1), Matrix4.rotationY(math.pi)),
    DiceFace(2, Vector3(1, 0, 0), Matrix4.rotationY(-math.pi / 2)),
    DiceFace(5, Vector3(-1, 0, 0), Matrix4.rotationY(math.pi / 2)),
    DiceFace(3, Vector3(0, -1, 0), Matrix4.rotationX(-math.pi / 2)),
    DiceFace(4, Vector3(0, 1, 0), Matrix4.rotationX(math.pi / 2)),
  ];

  /// Cube rotation (about X then Y) that brings [value] to the front.
  static (double rx, double ry) targetRotation(int value) {
    switch (value) {
      case 1:
        return (0, 0);
      case 6:
        return (0, math.pi);
      case 2:
        return (0, math.pi / 2);
      case 5:
        return (0, -math.pi / 2);
      case 4:
        return (-math.pi / 2, 0);
      case 3:
        return (math.pi / 2, 0);
      default:
        throw ArgumentError.value(value, 'value', 'must be 1..6');
    }
  }

  /// The cube's rotation matrix for the given angles.
  static Matrix4 rotation(double rx, double ry) =>
      Matrix4.rotationX(rx)..multiply(Matrix4.rotationY(ry));

  /// A face normal after rotating the cube.
  static Vector3 rotatedNormal(DiceFace face, double rx, double ry) =>
      rotation(rx, ry).transform3(face.normal.clone());

  /// The value whose face points most directly at the viewer.
  static int frontValue(double rx, double ry) {
    var best = faces.first;
    var bestZ = double.infinity;
    for (final f in faces) {
      final z = rotatedNormal(f, rx, ry).z;
      if (z < bestZ) {
        bestZ = z;
        best = f;
      }
    }
    return best.value;
  }

  /// Nearest angle to [from] that is congruent to [target] (mod 2π), plus
  /// [extraTurns] full rotations so the dice visibly tumbles.
  static double spinTo(double from, double target, int extraTurns) {
    const twoPi = 2 * math.pi;
    var delta = (target - from) % twoPi;
    if (delta < 0) delta += twoPi;
    return from + delta + extraTurns * twoPi;
  }
}
