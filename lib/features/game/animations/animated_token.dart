import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// How a token travels to its next position.
enum TokenMoveStyle {
  /// Small slide (e.g. another token moved in and we re-spread).
  settle,

  /// One cell hop with a bounce and a scale-up at the apex.
  hop,

  /// Long leap used for snakes / ladders until Phase 3 path-following.
  leap,
}

/// Positions [child] on the board and animates it between targets with a
/// hop. Must be a direct child of a [Stack].
class AnimatedToken extends StatefulWidget {
  const AnimatedToken({
    super.key,
    required this.target,
    required this.size,
    required this.duration,
    required this.style,
    required this.child,
    this.hopHeight = 18,
  });

  /// Centre of the token in board coordinates.
  final Offset target;
  final double size;
  final Duration duration;
  final TokenMoveStyle style;
  final double hopHeight;
  final Widget child;

  @override
  State<AnimatedToken> createState() => _AnimatedTokenState();
}

class _AnimatedTokenState extends State<AnimatedToken>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Offset _from;
  late Offset _to;
  TokenMoveStyle _style = TokenMoveStyle.settle;

  @override
  void initState() {
    super.initState();
    _from = _to = widget.target;
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..value = 1;
  }

  @override
  void didUpdateWidget(AnimatedToken old) {
    super.didUpdateWidget(old);
    if (widget.target != _to) {
      _from = _currentPosition;
      _to = widget.target;
      _style = widget.style;
      _controller
        ..duration = widget.duration
        ..forward(from: 0);
    }
  }

  double get _t => switch (_style) {
        TokenMoveStyle.settle => Curves.easeInOut.transform(_controller.value),
        TokenMoveStyle.hop => Curves.easeInOutSine.transform(_controller.value),
        TokenMoveStyle.leap => Curves.easeInOutCubic.transform(_controller.value),
      };

  Offset get _currentPosition => Offset.lerp(_from, _to, _t)!;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _t;
        final arc = math.sin(t * math.pi);
        final pos = _currentPosition;
        final (lift, scale) = switch (_style) {
          TokenMoveStyle.settle => (0.0, 1.0),
          TokenMoveStyle.hop => (arc * widget.hopHeight, 1 + 0.22 * arc),
          TokenMoveStyle.leap => (arc * widget.hopHeight * 2.2, 1 + 0.4 * arc),
        };
        final done = _controller.value >= 1;
        // Tiny landing squash right after a hop.
        final squash = done ? 1.0 : (t > 0.92 ? 1 - 0.1 * ((t - 0.92) / 0.08) : 1.0);
        return Positioned(
          left: pos.dx - widget.size / 2,
          top: pos.dy - widget.size / 2 - lift,
          width: widget.size,
          height: widget.size,
          child: Transform.scale(
            scaleX: scale / squash,
            scaleY: scale * squash,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
