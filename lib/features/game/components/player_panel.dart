import 'package:material_ui/material_ui.dart';

import '../../../core/constants/board_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../models/bot_personality.dart';
import '../models/game_state.dart';
import '../models/player.dart';

/// Shows every player, their position and whose turn it is.
class PlayerPanel extends StatelessWidget {
  const PlayerPanel({
    super.key,
    required this.state,
    this.axis = Axis.vertical,
  });

  final GameState state;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final (i, p) in state.players.indexed)
        _PlayerCard(
          player: p,
          isCurrent: i == state.currentPlayerIndex && !state.isCompleted,
          isWinner: state.winnerIndex == i,
          compact: axis == Axis.horizontal,
          remark: remarkFor(state, i),
        ),
    ];
    if (axis == Axis.horizontal) {
      return Row(
        children: [for (final c in cards) Expanded(child: c)],
      );
    }
    return Column(children: cards);
  }
}

/// What a bot has to say about the latest event, if the event is theirs.
String? remarkFor(GameState state, int index) {
  final e = state.lastEvent;
  if (e == null || e.playerIndex != index) return null;
  final personality = state.players[index].personality;
  if (personality == null) return null;
  return personality.remarkFor(e.type, state.events.length);
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.player,
    required this.isCurrent,
    required this.isWinner,
    required this.compact,
    this.remark,
  });

  final Player player;
  final bool isCurrent;
  final bool isWinner;
  final bool compact;
  final String? remark;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.players[player.colorIndex % AppColors.players.length];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final positionText = player.position == BoardConstants.startCell
        ? 'Start'
        : player.position == BoardConstants.finalCell
            ? 'Finish'
            : '${player.position}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.all(compact ? 4 : 6),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 14,
        vertical: compact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: isCurrent
            ? color.withValues(alpha: isDark ? 0.28 : 0.18)
            : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrent ? AppColors.gold : color.withValues(alpha: 0.5),
          width: isCurrent ? 2.5 : 1.5,
        ),
        boxShadow: isCurrent
            ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 16)]
            : null,
      ),
      child: compact ? _buildCompact(theme, color, positionText) : _buildFull(theme, color, positionText),
    );
  }

  Widget _avatar(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(player.avatar, style: TextStyle(fontSize: size * 0.5, height: 1)),
    );
  }

  Widget _buildFull(ThemeData theme, Color color, String positionText) {
    return Row(
      children: [
        _avatar(color, 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (player.isComputer) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.smart_toy_rounded, size: 16, color: theme.hintColor),
                    if (player.level case final level?) ...[
                      const SizedBox(width: 4),
                      Text(level.label, style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
                    ],
                  ],
                ],
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  remark != null
                      ? '“$remark”'
                      : isWinner
                          ? '🏆 Winner'
                          : (isCurrent ? (player.isComputer ? 'Thinking…' : 'Your turn') : 'Waiting'),
                  key: ValueKey(remark ?? '$isWinner$isCurrent'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: remark != null
                        ? AppColors.sunset
                        : isCurrent || isWinner
                            ? AppColors.gold
                            : theme.hintColor,
                    fontWeight: FontWeight.w600,
                    fontStyle: remark != null ? FontStyle.italic : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              positionText,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: color),
            ),
            Text('cell', style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
          ],
        ),
      ],
    );
  }

  Widget _buildCompact(ThemeData theme, Color color, String positionText) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _avatar(color, 34),
        const SizedBox(height: 4),
        Text(
          player.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          positionText,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: color),
        ),
      ],
    );
  }
}

/// The latest thing that happened, with a soft cross-fade.
class EventBanner extends StatelessWidget {
  const EventBanner({super.key, required this.state});

  final GameState state;

  String get _text {
    if (state.isPaused) return 'Paused';
    final e = state.lastEvent;
    if (state.phase == GamePhase.waiting) {
      final p = state.currentPlayer;
      if (p.isComputer) return '${p.name} is thinking…';
      return '${p.possessive} turn — roll the dice!';
    }
    if (state.phase == GamePhase.rolling) return '${state.currentPlayer.name} is rolling…';
    return e?.message ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Text(
        _text,
        key: ValueKey(_text),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: state.lastEvent?.type == GameEventType.snake && state.phase == GamePhase.slidingSnake
              ? AppColors.sunset
              : null,
        ),
      ),
    );
  }
}
