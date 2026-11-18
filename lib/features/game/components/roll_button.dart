import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/services/audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/settings_providers.dart';

/// The roll button. Pulses gently while it is the human's turn and gives a
/// press-down squash on tap.
class RollButton extends ConsumerStatefulWidget {
  const RollButton({super.key, required this.enabled, required this.onPressed, this.label = 'ROLL'});

  final bool enabled;
  final VoidCallback onPressed;
  final String label;

  @override
  ConsumerState<RollButton> createState() => _RollButtonState();
}

class _RollButtonState extends ConsumerState<RollButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _sync();
  }

  @override
  void didUpdateWidget(RollButton old) {
    super.didUpdateWidget(old);
    if (old.enabled != widget.enabled) _sync();
  }

  void _sync() {
    if (widget.enabled) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..animateTo(0, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final p = Curves.easeInOut.transform(_pulse.value);
        final scale = (_pressed ? 0.93 : 1.0) * (1 + 0.04 * p);
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: widget.enabled
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.25 + 0.4 * p),
                        blurRadius: 14 + 10 * p,
                        spreadRadius: 1 + 2 * p,
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: widget.enabled ? 1 : 0.55,
          child: ElevatedButton.icon(
            onPressed: widget.enabled
                ? () {
                    ref.read(audioServiceProvider).play(Sfx.click);
                    ref.read(hapticsProvider).light();
                    widget.onPressed();
                  }
                : null,
            icon: const Icon(Icons.casino_rounded),
            label: Text(widget.label),
          ),
        ),
      ),
    );
  }
}
