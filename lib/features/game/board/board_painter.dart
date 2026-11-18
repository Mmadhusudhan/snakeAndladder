import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../core/constants/board_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/board_geometry.dart';
import '../models/board_config.dart';
import 'ladder_renderer.dart';
import 'snake_renderer.dart';

/// Caches everything that does not change frame to frame: the cell grid,
/// numbers and ladders are recorded into a [ui.Picture]; snake spines are
/// sampled once per board size.
class BoardLayout {
  BoardLayout({required this.size, required this.board})
      : geometry = BoardGeometry(size) {
    var seed = 0;
    for (final e in board.snakes.entries) {
      snakes.add(SnakeShape.build(
        head: e.key,
        tail: e.value,
        headCenter: geometry.centerOf(e.key),
        tailCenter: geometry.centerOf(e.value),
        cellSize: geometry.cellSize,
        seed: seed++,
      ));
    }
    for (final e in board.ladders.entries) {
      ladders.add(LadderShape(
        bottom: e.key,
        top: e.value,
        bottomCenter: geometry.centerOf(e.key),
        topCenter: geometry.centerOf(e.value),
      ));
    }
  }

  final double size;
  final BoardConfig board;
  final BoardGeometry geometry;
  final List<SnakeShape> snakes = [];
  final List<LadderShape> ladders = [];
  ui.Picture? _staticLayer;

  SnakeShape? snakeAt(int head) {
    for (final s in snakes) {
      if (s.head == head) return s;
    }
    return null;
  }

  LadderShape? ladderAt(int bottom) {
    for (final l in ladders) {
      if (l.bottom == bottom) return l;
    }
    return null;
  }

  ui.Picture staticLayer() {
    final existing = _staticLayer;
    if (existing != null) return existing;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _paintCells(canvas);
    const ladderRenderer = LadderRenderer();
    for (final l in ladders) {
      ladderRenderer.paint(canvas, l, geometry.cellSize);
    }
    return _staticLayer = recorder.endRecording();
  }

  void _paintCells(Canvas canvas) {
    final cs = geometry.cellSize;
    final numberStyle = TextStyle(
      color: AppColors.cellNumber,
      fontSize: cs * 0.27,
      fontWeight: FontWeight.w800,
    );
    final border = Paint()
      ..color = AppColors.cellBorder.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var cell = 1; cell <= BoardConstants.cellCount; cell++) {
      final rect = geometry.rectOf(cell);
      final (row, col) = BoardGeometry.rowColOf(cell);
      Color fill = (row + col).isEven ? AppColors.cellA : AppColors.cellB;
      if (board.isSnakeHead(cell)) {
        fill = Color.lerp(fill, const Color(0xFFFFB3A7), 0.55)!;
      } else if (board.isLadderBottom(cell)) {
        fill = Color.lerp(fill, const Color(0xFFB9F6CA), 0.6)!;
      } else if (cell == BoardConstants.finalCell) {
        fill = AppColors.cellFinal;
      }
      final rrect = RRect.fromRectAndRadius(rect.deflate(0.8), Radius.circular(cs * 0.14));
      canvas.drawRRect(rrect, Paint()..color = fill);
      canvas.drawRRect(rrect, border);

      final tp = TextPainter(
        text: TextSpan(text: '$cell', style: numberStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, rect.topLeft + Offset(cs * 0.09, cs * 0.05));
    }

    // Crown on the final cell.
    final crown = TextPainter(
      text: TextSpan(text: '👑', style: TextStyle(fontSize: cs * 0.42)),
      textDirection: TextDirection.ltr,
    )..layout();
    final finalRect = geometry.rectOf(BoardConstants.finalCell);
    crown.paint(
      canvas,
      finalRect.center - Offset(crown.width / 2, crown.height / 2 - cs * 0.12),
    );
  }

  void dispose() {
    _staticLayer?.dispose();
    _staticLayer = null;
  }
}

/// Paints the whole board: cached static layer, animated snakes and the
/// glow under the current player's cell.
class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.layout,
    required this.time,
    this.highlightCell,
    this.highlightColor,
    this.activeSnakeHead,
    this.activeLadderBottom,
    this.transitionProgress = 0,
  });

  final BoardLayout layout;

  /// Looping animation value in 0..1.
  final double time;
  final int? highlightCell;
  final Color? highlightColor;

  /// Head cell of the snake currently swallowing a token, if any.
  final int? activeSnakeHead;

  /// Bottom cell of the ladder currently being climbed, if any.
  final int? activeLadderBottom;

  /// Progress (0..1) of the active slide / climb.
  final double transitionProgress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPicture(layout.staticLayer());

    final hc = highlightCell;
    if (hc != null && hc >= 1 && hc <= BoardConstants.cellCount) {
      final rect = layout.geometry.rectOf(hc);
      final pulse = 0.5 + 0.5 * ((time * 4) % 1.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(1.5), Radius.circular(layout.geometry.cellSize * 0.14)),
        Paint()
          ..color = (highlightColor ?? AppColors.gold).withValues(alpha: 0.35 + 0.3 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    final lb = activeLadderBottom;
    if (lb != null) {
      final ladder = layout.ladderAt(lb);
      if (ladder != null) {
        const LadderRenderer().paintActive(canvas, ladder, layout.geometry.cellSize, transitionProgress);
      }
    }

    const renderer = SnakeRenderer();
    for (final snake in layout.snakes) {
      renderer.paint(
        canvas,
        snake,
        layout.geometry.cellSize,
        time,
        bite: snake.head == activeSnakeHead ? transitionProgress : null,
      );
    }
  }

  @override
  bool shouldRepaint(BoardPainter old) =>
      old.layout != layout ||
      old.time != time ||
      old.highlightCell != highlightCell ||
      old.highlightColor != highlightColor ||
      old.activeSnakeHead != activeSnakeHead ||
      old.activeLadderBottom != activeLadderBottom ||
      old.transitionProgress != transitionProgress;
}
