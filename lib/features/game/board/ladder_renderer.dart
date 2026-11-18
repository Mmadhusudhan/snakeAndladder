import 'dart:ui';

import 'package:flutter/animation.dart';

import '../../../core/theme/app_colors.dart';

/// A ladder between two cell centres.
class LadderShape {
  const LadderShape({
    required this.bottom,
    required this.top,
    required this.bottomCenter,
    required this.topCenter,
  });

  final int bottom;
  final int top;
  final Offset bottomCenter;
  final Offset topCenter;

  /// Point along the ladder at fraction [t] (0 = bottom, 1 = top).
  Offset pointAt(double t) => Offset.lerp(bottomCenter, topCenter, t.clamp(0, 1))!;

  double get length => (topCenter - bottomCenter).distance;

  Offset get direction {
    final d = topCenter - bottomCenter;
    final l = d.distance;
    return l == 0 ? const Offset(0, -1) : d / l;
  }

  Offset get normal => Offset(-direction.dy, direction.dx);

  /// The rails stop short of the cell centres so numbers stay readable.
  Offset railStart(double cellSize) => bottomCenter + direction * (cellSize * 0.12);
  Offset railEnd(double cellSize) => topCenter - direction * (cellSize * 0.12);

  /// Centres of the rungs, bottom to top.
  List<Offset> rungPositions(double cellSize) {
    final start = railStart(cellSize);
    final end = railEnd(cellSize);
    final usable = (end - start).distance;
    final spacing = cellSize * 0.34;
    final count = (usable / spacing).floor();
    return [
      for (var i = 0; i <= count; i++) Offset.lerp(start, end, count == 0 ? 0.5 : i / count)!,
    ];
  }

  /// Where a climbing token stops: the bottom cell, every rung, the top cell.
  List<Offset> climbWaypoints(double cellSize) =>
      [bottomCenter, ...rungPositions(cellSize), topCenter];

  /// Position of a token climbing rung by rung at overall progress [p].
  /// Each rung-to-rung hop is eased so the climb has a rhythm.
  Offset climbPositionAt(double p, double cellSize) {
    final wp = climbWaypoints(cellSize);
    final segments = wp.length - 1;
    final f = p.clamp(0.0, 1.0) * segments;
    final i = f.floor().clamp(0, segments - 1);
    final frac = Curves.easeInOut.transform((f - i).clamp(0.0, 1.0));
    return Offset.lerp(wp[i], wp[i + 1], frac)!;
  }

  /// Index of the rung the token is on (or just left) at progress [p], or
  /// null when still on the ground / already on top.
  int? activeRungAt(double p, double cellSize) {
    final rungs = rungPositions(cellSize).length;
    final segments = rungs + 1;
    final i = (p.clamp(0.0, 1.0) * segments).floor();
    if (i <= 0 || i > rungs) return null;
    return i - 1;
  }
}

/// Draws a wooden ladder with two rails and evenly spaced rungs.
class LadderRenderer {
  const LadderRenderer();

  void paint(Canvas canvas, LadderShape ladder, double cellSize) {
    if (ladder.length == 0) return;
    final normal = ladder.normal;
    final railGap = cellSize * 0.18;
    final railWidth = cellSize * 0.075;
    final start = ladder.railStart(cellSize);
    final end = ladder.railEnd(cellSize);

    final shadow = Paint()
      ..color = const Color(0x44000000)
      ..strokeWidth = railWidth + 2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    final railDark = Paint()
      ..color = AppColors.woodDark
      ..strokeWidth = railWidth + 2
      ..strokeCap = StrokeCap.round;
    final rail = Paint()
      ..color = AppColors.wood
      ..strokeWidth = railWidth
      ..strokeCap = StrokeCap.round;
    final railHighlight = Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = railWidth * 0.35
      ..strokeCap = StrokeCap.round;
    final rungDark = Paint()
      ..color = AppColors.woodDark
      ..strokeWidth = railWidth * 0.8 + 2
      ..strokeCap = StrokeCap.round;
    final rung = Paint()
      ..color = const Color(0xFFB07A3E)
      ..strokeWidth = railWidth * 0.8
      ..strokeCap = StrokeCap.round;

    final leftStart = start + normal * railGap;
    final leftEnd = end + normal * railGap;
    final rightStart = start - normal * railGap;
    final rightEnd = end - normal * railGap;

    for (final (a, b) in [(leftStart, leftEnd), (rightStart, rightEnd)]) {
      canvas.drawLine(a + const Offset(2, 3), b + const Offset(2, 3), shadow);
    }

    for (final c in ladder.rungPositions(cellSize)) {
      canvas.drawLine(c + normal * railGap, c - normal * railGap, rungDark);
      canvas.drawLine(c + normal * railGap, c - normal * railGap, rung);
    }

    for (final (a, b) in [(leftStart, leftEnd), (rightStart, rightEnd)]) {
      canvas.drawLine(a, b, railDark);
      canvas.drawLine(a, b, rail);
      canvas.drawLine(a - normal * railWidth * 0.2, b - normal * railWidth * 0.2, railHighlight);
    }
  }

  /// Glow drawn over the ladder while a token climbs it: the whole ladder
  /// gets a soft halo and the rung under the token lights up.
  void paintActive(Canvas canvas, LadderShape ladder, double cellSize, double progress) {
    final railGap = cellSize * 0.18;
    final halo = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.28)
      ..strokeWidth = railGap * 2.6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawLine(ladder.railStart(cellSize), ladder.railEnd(cellSize), halo);

    final rungIndex = ladder.activeRungAt(progress, cellSize);
    if (rungIndex == null) return;
    final c = ladder.rungPositions(cellSize)[rungIndex];
    final normal = ladder.normal;
    canvas.drawLine(
      c + normal * railGap,
      c - normal * railGap,
      Paint()
        ..color = AppColors.cellFinal
        ..strokeWidth = cellSize * 0.075
        ..strokeCap = StrokeCap.round,
    );
  }
}
