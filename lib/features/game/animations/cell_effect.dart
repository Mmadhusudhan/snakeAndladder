import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// A one-shot burst drawn over a cell when a token lands on it. Rebuild with
/// a new [key] to play it again. Must be a direct child of a [Stack].
class CellEffect extends StatelessWidget {
  const CellEffect({
    super.key,
    required this.center,
    required this.radius,
    required this.color,
    this.duration = const Duration(milliseconds: 650),
    this.sparkles = 0,
  });

  final Offset center;
  final double radius;
  final Color color;
  final Duration duration;

  /// Number of small particles thrown outwards (0 = ripple only).
  final int sparkles;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2.6;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: duration,
          curve: Curves.easeOut,
          builder: (context, t, _) => CustomPaint(
            painter: _BurstPainter(t: t, color: color, sparkles: sparkles),
          ),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter({required this.t, required this.color, required this.sparkles});

  final double t;
  final Color color;
  final int sparkles;

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final c = size.center(Offset.zero);
    final maxR = size.width / 2;
    final fade = (1 - t).clamp(0.0, 1.0);

    // Expanding ring.
    canvas.drawCircle(
      c,
      maxR * (0.25 + 0.75 * t),
      Paint()
        ..color = color.withValues(alpha: 0.8 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * fade + 1,
    );
    // Soft fill flash.
    canvas.drawCircle(
      c,
      maxR * 0.45 * (1 - t * 0.5),
      Paint()..color = color.withValues(alpha: 0.35 * fade),
    );

    for (var i = 0; i < sparkles; i++) {
      final angle = i / sparkles * 2 * math.pi + t * 0.6;
      final dist = maxR * (0.2 + 0.8 * Curves.easeOutQuad.transform(t));
      final p = c + Offset(math.cos(angle), math.sin(angle)) * dist;
      canvas.drawCircle(p, 3.5 * fade + 0.5, Paint()..color = color.withValues(alpha: fade));
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t || old.color != color;
}
