import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/animation.dart';

import '../../../core/theme/app_colors.dart';

/// A pre-computed snake: its curved spine sampled into points, ready to be
/// drawn and followed by a sliding token.
class SnakeShape {
  SnakeShape._({
    required this.head,
    required this.tail,
    required this.path,
    required this.points,
    required this.tangents,
    required this.colorIndex,
    required this.seed,
  });

  final int head;
  final int tail;
  final Path path;

  /// Sampled spine from head (index 0) to tail.
  final List<Offset> points;

  /// Unit tangent at each sample, pointing from head towards tail.
  final List<Offset> tangents;
  final int colorIndex;
  final int seed;

  Color get bodyColor => AppColors.snakes[colorIndex % AppColors.snakes.length].$1;
  Color get bellyColor => AppColors.snakes[colorIndex % AppColors.snakes.length].$2;

  Offset get headCenter => points.first;
  Offset get tailCenter => points.last;

  /// Point on the un-swayed spine at fraction [t] (0 = head, 1 = tail).
  Offset pointAt(double t) => _lerpSamples(points, t);

  /// Unit tangent at fraction [t].
  Offset tangentAt(double t) {
    final v = _lerpSamples(tangents, t);
    final d = v.distance;
    return d == 0 ? const Offset(0, 1) : v / d;
  }

  /// Lateral sway of sample [i] at animation [time] (0..1 looping).
  /// Zero at both ends so the head and tail stay inside their cells.
  Offset swayAt(int i, double time, double cellSize, {double intensity = 1}) {
    final t = points.length == 1 ? 0.0 : i / (points.length - 1);
    final tan = tangents[i];
    final normal = Offset(-tan.dy, tan.dx);
    final envelope = 4 * t * (1 - t);
    final wave = math.sin(time * 2 * math.pi + seed + t * 7) *
        cellSize *
        0.07 *
        envelope *
        intensity;
    return normal * wave;
  }

  /// All spine samples with sway applied.
  List<Offset> swayedPoints(double time, double cellSize, {double intensity = 1}) {
    return List<Offset>.generate(
      points.length,
      (i) => points[i] + swayAt(i, time, cellSize, intensity: intensity),
    );
  }

  /// Point on the swayed spine at fraction [t]; this is what a sliding token
  /// follows so it stays glued to the drawn body.
  Offset swayedPointAt(double t, double time, double cellSize, {double intensity = 1}) {
    final clamped = t.clamp(0.0, 1.0);
    final f = clamped * (points.length - 1);
    final i = f.floor();
    final j = math.min(i + 1, points.length - 1);
    final a = points[i] + swayAt(i, time, cellSize, intensity: intensity);
    final b = points[j] + swayAt(j, time, cellSize, intensity: intensity);
    return Offset.lerp(a, b, f - i)!;
  }

  Offset _lerpSamples(List<Offset> list, double t) {
    final clamped = t.clamp(0.0, 1.0);
    final f = clamped * (list.length - 1);
    final i = f.floor();
    final j = math.min(i + 1, list.length - 1);
    return Offset.lerp(list[i], list[j], f - i)!;
  }

  /// Builds a snake between two cell centres. [seed] varies the curve so
  /// every snake looks different.
  factory SnakeShape.build({
    required int head,
    required int tail,
    required Offset headCenter,
    required Offset tailCenter,
    required double cellSize,
    required int seed,
  }) {
    final rng = math.Random(seed * 7919 + head * 31 + tail);
    final delta = tailCenter - headCenter;
    final length = delta.distance;
    final dir = length == 0 ? const Offset(0, 1) : delta / length;
    final normal = Offset(-dir.dy, dir.dx);
    final side = rng.nextBool() ? 1.0 : -1.0;
    final amp1 = cellSize * (0.9 + rng.nextDouble() * 0.9) * side;
    final amp2 = cellSize * (0.9 + rng.nextDouble() * 0.9) * -side;
    final c1 = headCenter + dir * (length * 0.3) + normal * amp1;
    final c2 = headCenter + dir * (length * 0.7) + normal * amp2;

    final path = Path()
      ..moveTo(headCenter.dx, headCenter.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, tailCenter.dx, tailCenter.dy);

    final points = <Offset>[];
    final tangents = <Offset>[];
    final step = math.max(2.0, cellSize * 0.11);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d <= metric.length; d += step) {
        final t = metric.getTangentForOffset(d);
        if (t == null) continue;
        points.add(t.position);
        tangents.add(t.vector);
      }
      final end = metric.getTangentForOffset(metric.length);
      if (end != null && (points.isEmpty || points.last != end.position)) {
        points.add(end.position);
        tangents.add(end.vector);
      }
    }
    return SnakeShape._(
      head: head,
      tail: tail,
      path: path,
      points: points,
      tangents: tangents,
      colorIndex: seed,
      seed: seed,
    );
  }
}

/// Draws a [SnakeShape] with a tapering, shaded 3D-style body, an animated
/// head, eyes and a flicking tongue. [time] is 0..1 and loops.
///
/// While a token slides down the snake, pass [bite] (0..1 progress of the
/// slide): the snake lunges and opens wide at the start, thrashes harder,
/// and a swallow bulge travels down the body with the token.
class SnakeRenderer {
  const SnakeRenderer();

  void paint(
    Canvas canvas,
    SnakeShape snake,
    double cellSize,
    double time, {
    double? bite,
  }) {
    final n = snake.points.length;
    if (n < 2) return;

    final body = snake.bodyColor;
    final belly = snake.bellyColor;
    final outline = Color.lerp(body, const Color(0xFF000000), 0.45)!;
    final band = Color.lerp(body, const Color(0xFF000000), 0.22)!;
    final shine = Color.lerp(belly, const Color(0xFFFFFFFF), 0.4)!;

    final outlinePaint = Paint()..color = outline;
    final bodyPaint = Paint()..color = body;
    final bandPaint = Paint()..color = band;
    final shinePaint = Paint()..color = shine.withValues(alpha: 0.75);
    final shadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    // Lunge envelope: strong at the start of a bite, fading by a third in.
    final lunge = bite == null ? 0.0 : (bite < 0.35 ? math.sin(math.pi * bite / 0.35) : 0.0);
    final thrash = bite == null ? 1.0 : 1 + 1.6 * math.sin(math.pi * bite);
    final pts = snake.swayedPoints(time, cellSize, intensity: thrash);

    double radiusAt(int i) {
      final t = i / (n - 1);
      var r = lerpDouble(cellSize * 0.19, cellSize * 0.05, Curves.easeIn.transform(t))!;
      if (bite != null) {
        // Swallow bulge travelling with the token.
        final d = t - bite;
        r *= 1 + 0.55 * math.exp(-(d * d) / 0.0025);
      }
      return r;
    }

    for (var i = n - 1; i >= 0; i--) {
      final r = radiusAt(i);
      canvas.drawCircle(pts[i] + Offset(r * 0.25, r * 0.5), r + 1, shadowPaint);
    }
    for (var i = n - 1; i >= 0; i--) {
      canvas.drawCircle(pts[i], radiusAt(i) + 1.6, outlinePaint);
    }
    for (var i = n - 1; i >= 0; i--) {
      final r = radiusAt(i);
      final isBand = (i ~/ 3).isOdd;
      canvas.drawCircle(pts[i], r, isBand ? bandPaint : bodyPaint);
      canvas.drawCircle(pts[i] + Offset(-r * 0.3, -r * 0.3), r * 0.42, shinePaint);
    }

    _paintHead(canvas, snake, pts, cellSize, time, body, outline, lunge);
  }

  void _paintHead(
    Canvas canvas,
    SnakeShape snake,
    List<Offset> pts,
    double cellSize,
    double time,
    Color body,
    Color outline,
    double lunge,
  ) {
    final toBody = snake.tangents.first;
    final facing = -toBody;
    final angle = math.atan2(facing.dy, facing.dx);
    final bob = math.sin(time * 2 * math.pi * 2 + snake.seed) * cellSize * 0.03;
    final headPos = pts.first + facing * (cellSize * 0.16 * lunge);
    final headScale = 1 + 0.3 * lunge;

    final headW = cellSize * 0.56 * headScale;
    final headH = cellSize * 0.42 * headScale;

    canvas.save();
    canvas.translate(headPos.dx, headPos.dy);
    canvas.rotate(angle + bob * 0.4 - lunge * 0.15);

    final headRect = Rect.fromCenter(
      center: Offset(headW * 0.18, 0),
      width: headW,
      height: headH,
    );
    final headColor = Color.lerp(body, const Color(0xFFFFFFFF), 0.08)!;
    canvas.drawOval(headRect.inflate(1.6), Paint()..color = outline);
    canvas.drawOval(headRect, Paint()..color = headColor);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(headW * 0.1, -headH * 0.12),
        width: headW * 0.6,
        height: headH * 0.42,
      ),
      Paint()..color = const Color(0x33FFFFFF),
    );

    // Mouth: idle open/close, or a wide bite.
    final idleOpen = (math.sin(time * 2 * math.pi * 1.5 + snake.seed * 2) + 1) / 2;
    final mouthOpen = math.max(idleOpen * 0.5, lunge);
    if (lunge > 0.05) {
      // Gaping jaw: a dark wedge with two fangs.
      final jaw = Path()
        ..moveTo(headW * 0.3, 0)
        ..lineTo(headW * 0.7, -headH * 0.42 * lunge)
        ..lineTo(headW * 0.7, headH * 0.42 * lunge)
        ..close();
      canvas.drawPath(jaw, Paint()..color = const Color(0xFF5A0F1C));
      final fang = Paint()..color = const Color(0xFFFFFFFF);
      for (final sign in const [-1.0, 1.0]) {
        final tip = Path()
          ..moveTo(headW * 0.58, sign * headH * 0.34 * lunge)
          ..lineTo(headW * 0.64, sign * headH * 0.12 * lunge)
          ..lineTo(headW * 0.68, sign * headH * 0.36 * lunge)
          ..close();
        canvas.drawPath(tip, fang);
      }
    } else {
      final mouthPaint = Paint()
        ..color = const Color(0xFF7A1F2B)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = cellSize * (0.03 + 0.05 * mouthOpen);
      canvas.drawLine(Offset(headW * 0.36, 0), Offset(headW * 0.64, 0), mouthPaint);
    }

    // Tongue flicks in and out (hidden while biting).
    if (lunge < 0.3) {
      final flick = (math.sin(time * 2 * math.pi * 3 + snake.seed) + 1) / 2;
      final tongueLen = cellSize * (0.12 + 0.22 * flick);
      final tonguePaint = Paint()
        ..color = const Color(0xFFE53950)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cellSize * 0.035
        ..strokeCap = StrokeCap.round;
      final tongueBase = Offset(headW * 0.66, 0);
      final tongueTip = tongueBase + Offset(tongueLen, 0);
      canvas.drawLine(tongueBase, tongueTip, tonguePaint);
      canvas.drawLine(tongueTip, tongueTip + Offset(cellSize * 0.07, -cellSize * 0.06), tonguePaint);
      canvas.drawLine(tongueTip, tongueTip + Offset(cellSize * 0.07, cellSize * 0.06), tonguePaint);
    }

    // Eyes with blinking; narrowed and red-rimmed during a bite.
    final blink = ((time * 4 + snake.seed * 0.37) % 1.0) > 0.92 && lunge < 0.1;
    final eyeOffsetX = headW * 0.28;
    final eyeOffsetY = headH * 0.3;
    final eyeR = cellSize * 0.075 * (1 + 0.2 * lunge);
    final whitePaint = Paint()..color = Color.lerp(const Color(0xFFFFFFFF), const Color(0xFFFFB3A7), lunge)!;
    final pupilPaint = Paint()..color = const Color(0xFF1B1B1B);
    for (final sign in const [-1.0, 1.0]) {
      final center = Offset(eyeOffsetX, eyeOffsetY * sign);
      if (blink) {
        canvas.drawLine(
          center + Offset(-eyeR, 0),
          center + Offset(eyeR, 0),
          Paint()
            ..color = outline
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
        continue;
      }
      canvas.drawCircle(center, eyeR + 1, Paint()..color = outline);
      canvas.drawCircle(center, eyeR, whitePaint);
      canvas.drawCircle(center + Offset(eyeR * 0.35, 0), eyeR * (0.55 - 0.2 * lunge), pupilPaint);
      canvas.drawCircle(center + Offset(eyeR * 0.15, -eyeR * 0.3), eyeR * 0.2, whitePaint);
      if (lunge > 0.2) {
        // Angry brow.
        canvas.drawLine(
          center + Offset(-eyeR * 1.1, sign * -eyeR * 1.2),
          center + Offset(eyeR * 1.1, sign * -eyeR * 0.5),
          Paint()
            ..color = outline
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    canvas.restore();
  }
}
