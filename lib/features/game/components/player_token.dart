import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';

/// A round, glossy token with the player's avatar.
class PlayerToken extends StatelessWidget {
  const PlayerToken({
    super.key,
    required this.size,
    required this.colorIndex,
    required this.avatar,
    this.isCurrent = false,
  });

  final double size;
  final int colorIndex;
  final String avatar;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.players[colorIndex % AppColors.players.length];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [
            Color.lerp(color, Colors.white, 0.45)!,
            color,
            Color.lerp(color, Colors.black, 0.35)!,
          ],
          stops: const [0, 0.55, 1],
        ),
        border: Border.all(
          color: isCurrent ? AppColors.gold : Colors.white,
          width: isCurrent ? size * 0.11 : size * 0.07,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.12),
          ),
          if (isCurrent)
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.7),
              blurRadius: size * 0.45,
            ),
        ],
      ),
      child: Center(
        child: Text(
          avatar,
          style: TextStyle(fontSize: size * 0.48, height: 1),
        ),
      ),
    );
  }
}
