import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../animations/animated_token.dart';
import '../animations/cell_effect.dart';
import '../components/player_token.dart';
import '../engine/game_engine.dart';
import '../models/board_config.dart';
import '../models/game_state.dart';
import 'board_painter.dart';

/// The square board with animated snakes, ladders and player tokens.
///
/// Tokens hop cell by cell while moving. When a token lands on a snake it
/// slides along the snake's spine (which thrashes and swallows); on a
/// ladder it climbs rung by rung.
class BoardWidget extends StatefulWidget {
  const BoardWidget({
    super.key,
    required this.size,
    required this.board,
    required this.state,
    required this.timings,
  });

  final double size;
  final BoardConfig board;
  final GameState state;
  final EngineTimings timings;

  @override
  State<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget>
    with TickerProviderStateMixin {
  late final AnimationController _ticker;
  late final AnimationController _transition;
  BoardLayout? _layout;

  /// Snake head / ladder bottom of the transition being animated.
  int? _transitionFrom;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _transition = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _syncTransition();
  }

  @override
  void didUpdateWidget(BoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTransition();
  }

  /// Starts the slide / climb controller when the engine enters a snake or
  /// ladder phase. The engine waits the same duration, so the token reaches
  /// the end just as the engine commits the new position.
  void _syncTransition() {
    final s = widget.state;
    final from = s.transitionFrom;
    final to = s.transitionTo;
    final active =
        from != null &&
        to != null &&
        (s.phase == GamePhase.slidingSnake ||
            s.phase == GamePhase.climbingLadder);
    if (!active) {
      if (_transitionFrom != null) {
        _transitionFrom = null;
        _transition.stop();
      }
      return;
    }
    if (_transitionFrom == from) return;
    _transitionFrom = from;
    final duration = s.phase == GamePhase.slidingSnake
        ? widget.timings.snakeDuration(from, to)
        : widget.timings.ladderDuration(from, to);
    // Finish a touch early so the token is already there when the engine
    // commits the position.
    final ms = math.max(1, duration.inMilliseconds - 60);
    _transition
      ..duration = Duration(milliseconds: ms)
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _transition.dispose();
    _layout?.dispose();
    super.dispose();
  }

  BoardLayout _layoutFor(double size) {
    final current = _layout;
    if (current != null &&
        current.size == size &&
        current.board == widget.board) {
      return current;
    }
    current?.dispose();
    return _layout = BoardLayout(size: size, board: widget.board);
  }

  bool get _inTransition => _transitionFrom != null;

  /// Cell at which each player's token should be drawn right now.
  int _displayCell(int index) {
    final s = widget.state;
    final p = s.players[index];
    if (index == s.currentPlayerIndex &&
        s.transitionTo != null &&
        p.position == s.transitionFrom) {
      return s.transitionTo!;
    }
    return p.position;
  }

  bool _isTransitioning(int index) =>
      _inTransition &&
      index == widget.state.currentPlayerIndex &&
      widget.state.players[index].position == widget.state.transitionFrom;

  Duration _durationFor(int index) {
    final s = widget.state;
    if (index != s.currentPlayerIndex) return const Duration(milliseconds: 300);
    if (s.phase == GamePhase.moving) return widget.timings.step;
    return const Duration(milliseconds: 300);
  }

  TokenMoveStyle _styleFor(int index) {
    final s = widget.state;
    if (index == s.currentPlayerIndex && s.phase == GamePhase.moving) {
      return TokenMoveStyle.hop;
    }
    return TokenMoveStyle.settle;
  }

  /// Burst drawn for the most recent landing / snake / ladder event.
  Widget? _landingEffect(BoardLayout layout) {
    final s = widget.state;
    final e = s.lastEvent;
    if (e == null) return null;
    final cs = layout.geometry.cellSize;
    final previous = s.events.length >= 2
        ? s.events[s.events.length - 2].type
        : null;
    final (int cell, Color color, int sparkles) = switch (e.type) {
      GameEventType.moved => (e.to!, AppColors.gold, 0),
      GameEventType.snake => (e.from!, AppColors.sunset, 10),
      GameEventType.ladder => (e.from!, AppColors.jungleLight, 8),
      GameEventType.landed => (
        e.to!,
        previous == GameEventType.snake
            ? AppColors.sunset
            : AppColors.jungleLight,
        6,
      ),
      GameEventType.won => (e.to!, AppColors.gold, 14),
      _ => (-1, AppColors.gold, 0),
    };
    if (cell < 0) return null;
    return CellEffect(
      key: ValueKey('effect-${s.events.length}-${e.type}'),
      center: layout.geometry.centerOf(cell),
      radius: cs * 0.5,
      color: color,
      sparkles: sparkles,
      duration: Duration(milliseconds: sparkles > 0 ? 900 : 600),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final layout = _layoutFor(size);
    final cs = layout.geometry.cellSize;
    final tokenSize = cs * 0.56;
    final state = widget.state;

    final cells = <int, List<int>>{};
    for (var i = 0; i < state.players.length; i++) {
      if (_isTransitioning(i)) continue;
      cells.putIfAbsent(_displayCell(i), () => []).add(i);
    }

    final currentPlayer = state.currentPlayer;
    final highlight = currentPlayer.position;
    final snakeHead = state.phase == GamePhase.slidingSnake
        ? _transitionFrom
        : null;
    final ladderBottom = state.phase == GamePhase.climbingLadder
        ? _transitionFrom
        : null;
    final merged = Listenable.merge([_ticker, _transition]);

    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cs * 0.3),
          border: Border.all(color: AppColors.woodDark, width: cs * 0.09),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(cs * 0.22),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: merged,
                  builder: (context, _) => CustomPaint(
                    painter: BoardPainter(
                      layout: layout,
                      time: _ticker.value,
                      highlightCell: highlight,
                      highlightColor:
                          AppColors.players[currentPlayer.colorIndex],
                      activeSnakeHead: snakeHead,
                      activeLadderBottom: ladderBottom,
                      transitionProgress: _transition.value,
                    ),
                  ),
                ),
              ),
              ?_landingEffect(layout),
              for (final entry in cells.entries)
                for (final (slot, index) in entry.value.indexed)
                  _positionedToken(
                    layout: layout,
                    cell: entry.key,
                    slot: slot,
                    slotCount: entry.value.length,
                    index: index,
                    tokenSize: tokenSize,
                  ),
              for (var i = 0; i < state.players.length; i++)
                if (_isTransitioning(i))
                  _pathToken(
                    layout: layout,
                    index: i,
                    tokenSize: tokenSize,
                    merged: merged,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  /// The current player's token riding a snake or climbing a ladder.
  Widget _pathToken({
    required BoardLayout layout,
    required int index,
    required double tokenSize,
    required Listenable merged,
  }) {
    final state = widget.state;
    final player = state.players[index];
    final cs = layout.geometry.cellSize;
    final from = _transitionFrom!;
    final isSnake = state.phase == GamePhase.slidingSnake;
    final snake = isSnake ? layout.snakeAt(from) : null;
    final ladder = isSnake ? null : layout.ladderAt(from);
    final token = IgnorePointer(
      child: PlayerToken(
        size: tokenSize,
        colorIndex: player.colorIndex,
        avatar: player.avatar,
        isCurrent: true,
      ),
    );

    return AnimatedBuilder(
      key: ValueKey('token-${player.id}'),
      animation: merged,
      builder: (context, child) {
        final p = _transition.value;
        Offset center;
        double tilt;
        double scale;
        if (snake != null) {
          // Hang on at the mouth briefly, then accelerate down the body.
          final slide = Curves.easeInOutCubic.transform(p);
          final thrash = 1 + 1.6 * math.sin(math.pi * p);
          center = snake.swayedPointAt(
            slide,
            _ticker.value,
            cs,
            intensity: thrash,
          );
          final tan = snake.tangentAt(slide);
          // Lean into the curve; keep upright-ish so the avatar stays readable.
          tilt =
              math.atan2(tan.dy, tan.dx) * 0.12 +
              math.sin(p * math.pi * 6) * 0.08;
          scale = 1 - 0.12 * math.sin(math.pi * p);
        } else if (ladder != null) {
          center = ladder.climbPositionAt(p, cs);
          final segments = ladder.climbWaypoints(cs).length - 1;
          final step = (p * segments).floor();
          final frac = (p * segments) - step;
          // Alternate lean per rung, with a little push-up at each hop.
          tilt = (step.isEven ? 1 : -1) * 0.14 * math.sin(frac * math.pi);
          scale = 1 + 0.12 * math.sin(frac * math.pi);
        } else {
          center = layout.geometry.centerOf(
            state.transitionTo ?? player.position,
          );
          tilt = 0;
          scale = 1;
        }
        center += Offset(cs * 0.05, cs * 0.08);
        return Positioned(
          left: center.dx - tokenSize / 2,
          top: center.dy - tokenSize / 2,
          width: tokenSize,
          height: tokenSize,
          child: Transform.rotate(
            angle: tilt,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: token,
    );
  }

  Widget _positionedToken({
    required BoardLayout layout,
    required int cell,
    required int slot,
    required int slotCount,
    required int index,
    required double tokenSize,
  }) {
    final player = widget.state.players[index];
    final cs = layout.geometry.cellSize;
    final center = layout.geometry.centerOf(cell);
    final spread = _spreadOffset(slot, slotCount, cs);
    final size = slotCount == 1 ? tokenSize : tokenSize * 0.78;
    final pos = center + spread + Offset(cs * 0.05, cs * 0.08);
    return AnimatedToken(
      key: ValueKey('token-${player.id}'),
      target: pos,
      size: size,
      duration: _durationFor(index),
      style: _styleFor(index),
      hopHeight: cs * 0.45,
      child: IgnorePointer(
        child: PlayerToken(
          size: size,
          colorIndex: player.colorIndex,
          avatar: player.avatar,
          isCurrent:
              index == widget.state.currentPlayerIndex &&
              !widget.state.isCompleted,
        ),
      ),
    );
  }

  static Offset _spreadOffset(int slot, int count, double cs) {
    if (count <= 1) return Offset.zero;
    const layouts = <List<Offset>>[
      [],
      [Offset.zero],
      [Offset(-0.18, -0.1), Offset(0.18, 0.1)],
      [Offset(-0.2, -0.12), Offset(0.2, -0.12), Offset(0, 0.16)],
      [
        Offset(-0.18, -0.16),
        Offset(0.18, -0.16),
        Offset(-0.18, 0.16),
        Offset(0.18, 0.16),
      ],
    ];
    final o = layouts[count.clamp(1, 4)][slot];
    return Offset(o.dx * cs, o.dy * cs);
  }
}
