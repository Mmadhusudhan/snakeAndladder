import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

import '../../../core/theme/app_colors.dart';
import '../animations/dice_cube_math.dart';

/// A real 3D dice cube. While [isRolling] it jumps, tumbles and lands on
/// [targetValue] exactly as [rollDuration] elapses, with a bounce.
class DiceWidget extends StatefulWidget {
  const DiceWidget({
    super.key,
    required this.value,
    required this.isRolling,
    required this.enabled,
    required this.onTap,
    this.targetValue,
    this.rollDuration = const Duration(milliseconds: 1000),
    this.size = 84,
  });

  /// Settled value (null before the first roll).
  final int? value;

  /// Value the roll will land on, known when the roll starts.
  final int? targetValue;
  final bool isRolling;
  final bool enabled;
  final VoidCallback onTap;
  final Duration rollDuration;
  final double size;

  @override
  State<DiceWidget> createState() => DiceWidgetState();
}

class DiceWidgetState extends State<DiceWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _rng = math.Random();

  double _fromX = 0, _fromY = 0, _toX = 0, _toY = 0;
  double _wobble = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.rollDuration);
    final (rx, ry) = DiceCubeMath.targetRotation(widget.value ?? 1);
    _fromX = _toX = rx;
    _fromY = _toY = ry;
    _controller.value = 1;
    if (widget.isRolling) _startRoll();
  }

  @override
  void didUpdateWidget(DiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRolling && !oldWidget.isRolling) {
      _startRoll();
    } else if (!widget.isRolling && oldWidget.isRolling && _controller.isAnimating) {
      // Engine finished early (e.g. reset): snap to the final face.
      _controller.value = 1;
    } else if (!widget.isRolling && widget.value != oldWidget.value && widget.value != null) {
      _snapTo(widget.value!);
    }
  }

  void _snapTo(int value) {
    final (rx, ry) = DiceCubeMath.targetRotation(value);
    _fromX = _toX = rx;
    _fromY = _toY = ry;
    _controller.value = 1;
  }

  void _startRoll() {
    final target = widget.targetValue ?? (_rng.nextInt(6) + 1);
    final (rx, ry) = DiceCubeMath.targetRotation(target);
    _fromX = _currentX;
    _fromY = _currentY;
    _toX = DiceCubeMath.spinTo(_fromX, rx, 2 + _rng.nextInt(2));
    _toY = DiceCubeMath.spinTo(_fromY, ry, 1 + _rng.nextInt(2));
    _wobble = (_rng.nextDouble() - 0.5) * 0.8;
    _controller
      ..duration = widget.rollDuration
      ..forward(from: 0);
  }

  double get _t => Curves.easeOutCubic.transform(_controller.value);

  /// The value currently facing the viewer (for tests and debugging).
  @visibleForTesting
  int get shownValue => DiceCubeMath.frontValue(_currentX, _currentY);

  /// Whether the tumble animation is still running.
  @visibleForTesting
  bool get isTumbling => _controller.isAnimating;
  double get _currentX => _fromX + (_toX - _fromX) * _t;
  double get _currentY => _fromY + (_toY - _fromY) * _t;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.isRolling
          ? 'Dice rolling'
          : widget.value == null
              ? 'Roll dice'
              : 'Dice shows ${widget.value}. Roll dice',
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: SizedBox(
          width: size * 1.4,
          height: size * 1.6,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final raw = _controller.value;
              final rolling = _controller.isAnimating;
              // Jump up then bounce back down.
              final height = rolling ? (1 - Curves.bounceOut.transform(raw)) * size * 0.55 : 0.0;
              // Squash on the first landing.
              final squash = rolling && raw > 0.55 && raw < 0.7
                  ? 1 - 0.12 * math.sin((raw - 0.55) / 0.15 * math.pi)
                  : 1.0;
              final rz = rolling ? _wobble * math.sin(_t * math.pi) : 0.0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Ground shadow shrinks while the dice is in the air.
                  Positioned(
                    bottom: size * 0.08,
                    child: Container(
                      width: size * (1.05 - height / size * 0.5),
                      height: size * 0.22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(size),
                        color: Colors.black.withValues(alpha: 0.35 - height / size * 0.2),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: size * 0.3 + height,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..scaleByDouble(1 / squash, squash, 1, 1),
                      child: _DiceCube(
                        size: size,
                        rx: _currentX,
                        ry: _currentY,
                        rz: rz,
                        glow: widget.enabled && !rolling,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Renders the six faces of the cube with perspective, back-face culling and
/// simple directional lighting.
class _DiceCube extends StatelessWidget {
  const _DiceCube({
    required this.size,
    required this.rx,
    required this.ry,
    required this.rz,
    required this.glow,
  });

  final double size;
  final double rx;
  final double ry;
  final double rz;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final half = size / 2;
    final cubeRotation = Matrix4.rotationZ(rz)
      ..multiply(DiceCubeMath.rotation(rx, ry));
    final perspective = Matrix4.identity()..setEntry(3, 2, 0.0018);
    final light = Vector3(-0.4, -0.75, -0.55).normalized();

    final visible = <(double, Widget)>[];
    for (final face in DiceCubeMath.faces) {
      final n = cubeRotation.transform3(face.normal.clone());
      if (n.z >= -0.03) continue; // back face or edge-on
      final shade = (0.62 + 0.38 * math.max(0, n.dot(light))).clamp(0.55, 1.0);
      final transform = perspective.clone()
        ..multiply(cubeRotation)
        ..multiply(face.rotation)
        ..translateByDouble(0.0, 0.0, -half, 1.0);
      visible.add((
        n.z,
        Transform(
          alignment: Alignment.center,
          transform: transform,
          child: _Face(value: face.value, size: size, shade: shade),
        ),
      ));
    }
    visible.sort((a, b) => b.$1.compareTo(a.$1)); // farthest first

    return Container(
      width: size,
      height: size,
      decoration: glow
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.7),
                  blurRadius: size * 0.35,
                  spreadRadius: size * 0.04,
                ),
              ],
            )
          : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [for (final v in visible) Positioned.fill(child: v.$2)],
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.value, required this.size, required this.shade});

  final int value;
  final double size;
  final double shade;

  @override
  Widget build(BuildContext context) {
    final base = Color.lerp(const Color(0xFF8A8A8A), Colors.white, shade)!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.09),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(base, Colors.white, 0.25)!, base],
        ),
        border: Border.all(color: Color.lerp(base, Colors.black, 0.25)!, width: 1.2),
      ),
      child: CustomPaint(painter: DiceFacePainter(value)),
    );
  }
}

/// Draws the pips for a dice face (1..6).
class DiceFacePainter extends CustomPainter {
  const DiceFacePainter(this.face);

  final int face;

  static const Map<int, List<Offset>> pips = {
    1: [Offset(0.5, 0.5)],
    2: [Offset(0.25, 0.25), Offset(0.75, 0.75)],
    3: [Offset(0.25, 0.25), Offset(0.5, 0.5), Offset(0.75, 0.75)],
    4: [Offset(0.25, 0.25), Offset(0.75, 0.25), Offset(0.25, 0.75), Offset(0.75, 0.75)],
    5: [
      Offset(0.25, 0.25),
      Offset(0.75, 0.25),
      Offset(0.5, 0.5),
      Offset(0.25, 0.75),
      Offset(0.75, 0.75),
    ],
    6: [
      Offset(0.25, 0.22),
      Offset(0.75, 0.22),
      Offset(0.25, 0.5),
      Offset(0.75, 0.5),
      Offset(0.25, 0.78),
      Offset(0.75, 0.78),
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width * 0.085;
    final paint = Paint()..color = face == 1 ? const Color(0xFFD32F2F) : const Color(0xFF1E1E1E);
    final shine = Paint()..color = const Color(0x66FFFFFF);
    for (final p in pips[face.clamp(1, 6)]!) {
      final c = Offset(p.dx * size.width, p.dy * size.height);
      canvas.drawCircle(c, face == 1 ? r * 1.5 : r, paint);
      canvas.drawCircle(c + Offset(-r * 0.3, -r * 0.3), r * 0.3, shine);
    }
  }

  @override
  bool shouldRepaint(DiceFacePainter old) => old.face != face;
}
