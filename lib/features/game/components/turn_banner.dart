import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../models/game_state.dart';

/// A short "Ben's turn" ribbon that slides in whenever the turn passes to a
/// different player, so pass-and-play groups know who holds the device.
/// Non-blocking: it fades out on its own.
class TurnBanner extends StatefulWidget {
  const TurnBanner({super.key, required this.state});

  final GameState state;

  @override
  State<TurnBanner> createState() => _TurnBannerState();
}

class _TurnBannerState extends State<TurnBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int? _announced;
  int _shownFor = -1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _maybeAnnounce(first: true);
  }

  @override
  void didUpdateWidget(TurnBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeAnnounce();
  }

  void _maybeAnnounce({bool first = false}) {
    final s = widget.state;
    if (s.phase != GamePhase.waiting || s.isPaused) return;
    final idx = s.currentPlayerIndex;
    if (_announced == idx && s.turnNumber == _shownFor) return;
    // Only announce when the seat actually changes (extra turns stay quiet),
    // or at the very start of the game.
    if (_announced == idx && !first) return;
    _announced = idx;
    _shownFor = s.turnNumber;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final idx = _announced ?? s.currentPlayerIndex;
    final player = s.players[idx];
    final color = AppColors.players[player.colorIndex % AppColors.players.length];
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          if (t == 0 || t >= 1) return const SizedBox.shrink();
          // Slide in fast, hold, fade out.
          final enter = Curves.easeOutBack.transform((t / 0.25).clamp(0, 1));
          final exit = t > 0.7 ? Curves.easeIn.transform((t - 0.7) / 0.3) : 0.0;
          return Opacity(
            opacity: (1 - exit).clamp(0, 1),
            child: Transform.translate(
              offset: Offset((1 - enter) * -60, 0),
              child: Transform.scale(scale: 0.9 + 0.1 * enter, child: child),
            ),
          );
        },
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.gold, width: 3),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(player.avatar, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Text(
                  player.isComputer ? '${player.name} is rolling' : '${player.possessive} turn',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
