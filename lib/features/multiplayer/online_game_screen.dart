import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/online_providers.dart';
import '../game/board/board_widget.dart';
import '../game/components/dice_widget.dart';
import '../game/components/game_audio_bridge.dart';
import '../game/components/player_panel.dart';
import '../game/components/roll_button.dart';
import '../game/components/turn_banner.dart';
import '../game/models/board_config.dart';
import '../game/models/game_state.dart';
import '../game/screens/game_result_screen.dart';

/// The online match: same board and animations as local play, but every
/// roll is decided by the server and replayed here.
class OnlineGameScreen extends ConsumerStatefulWidget {
  const OnlineGameScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends ConsumerState<OnlineGameScreen> {
  bool _resultShown = false;

  OnlineGameController get _controller => ref.read(onlineGameProvider(widget.roomId).notifier);

  void _roll() => _controller.roll();

  Future<void> _confirmLeave() async {
    final view = ref.read(onlineGameProvider(widget.roomId));
    final playing = view.room?.isPlaying ?? false;
    final ok = !playing ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Leave the game?'),
                content: const Text('Leaving counts as a loss and the others play on.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
                  ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave')),
                ],
              ),
            ) ==
            true;
    if (!ok || !mounted) return;
    await _controller.leave();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _showResult(GameState game) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await GameResultScreen.show(context, game);
    if (!mounted) return;
    await _controller.leave();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(onlineGameProvider(widget.roomId));
    final controller = ref.read(onlineGameProvider(widget.roomId).notifier);
    final room = view.room;
    final game = view.game;
    final brightness = Theme.of(context).brightness;

    ref.listen<OnlineGameView>(onlineGameProvider(widget.roomId), (prev, next) {
      final g = next.game;
      if (g != null && g.isCompleted && !next.replaying && !_resultShown) {
        _resultShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _showResult(g));
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!), backgroundColor: AppColors.sunset));
        controller.clearError();
      }
    });

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _roll,
        const SingleActivator(LogicalKeyboardKey.enter): _roll,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Container(
            decoration: AppTheme.background(brightness),
            child: SafeArea(
              child: room == null || game == null
                  ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                  : Stack(
                      children: [
                        GameAudioBridge(state: game),
                        LayoutBuilder(
                          builder: (context, c) {
                            final wide = c.maxWidth > c.maxHeight * 1.05;
                            return wide ? _wide(c, view, game) : _tall(c, view, game);
                          },
                        ),
                        Positioned(left: 0, right: 0, top: 56, child: TurnBanner(state: game)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(OnlineGameView view) {
    final room = view.room!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Leave',
            onPressed: _confirmLeave,
            icon: const Icon(Icons.exit_to_app_rounded, color: AppColors.gold, size: 28),
          ),
          Expanded(
            child: Column(
              children: [
                const Text('ONLINE MATCH', textAlign: TextAlign.center, style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
                Text('Room ${room.code}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ),
          _Countdown(seconds: view.secondsLeft, active: room.isPlaying),
        ],
      ),
    );
  }

  Widget _diceArea(OnlineGameView view, GameState game, {double size = 84}) {
    final label = view.canRollForIdle ? 'ROLL FOR THEM' : 'ROLL';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DiceWidget(
          size: size,
          value: game.lastRoll,
          targetValue: game.pendingRoll,
          isRolling: game.phase == GamePhase.rolling,
          rollDuration: _controller.timings.roll,
          enabled: view.canRoll,
          onTap: _roll,
        ),
        const SizedBox(height: 6),
        RollButton(enabled: view.canRoll, onPressed: _roll, label: label),
      ],
    );
  }

  Widget _tall(BoxConstraints c, OnlineGameView view, GameState game) {
    const topBar = 56.0;
    const panelMin = 190.0;
    final boardSize = (c.maxWidth - 24).clamp(200.0, c.maxHeight - topBar - panelMin);
    return Column(
      children: [
        _topBar(view),
        Expanded(
          child: Center(child: BoardWidget(size: boardSize, board: _controllerBoard, state: game, timings: _controller.timings)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EventBanner(state: game),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: PlayerPanel(state: game, axis: Axis.horizontal)),
                  const SizedBox(width: 8),
                  _diceArea(view, game, size: 70),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _wide(BoxConstraints c, OnlineGameView view, GameState game) {
    final boardSize = (c.maxHeight - 24).clamp(200.0, c.maxWidth - 300);
    return Row(
      children: [
        Expanded(
          child: Center(child: BoardWidget(size: boardSize, board: _controllerBoard, state: game, timings: _controller.timings)),
        ),
        SizedBox(
          width: (c.maxWidth - boardSize - 24).clamp(260.0, 380.0),
          child: Column(
            children: [
              _topBar(view),
              Expanded(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 12), child: PlayerPanel(state: game))),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [EventBanner(state: game), const SizedBox(height: 16), _diceArea(view, game, size: 96)]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  BoardConfig get _controllerBoard => _controller.board;
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.seconds, required this.active});

  final int seconds;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final urgent = seconds <= 5;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: (urgent ? AppColors.sunset : AppColors.gold).withValues(alpha: active ? 0.2 : 0.08),
        border: Border.all(color: urgent ? AppColors.sunset : AppColors.gold),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_rounded, size: 16, color: urgent ? AppColors.sunset : AppColors.gold),
          const SizedBox(width: 4),
          Text(active ? '${seconds}s' : '—', style: TextStyle(fontWeight: FontWeight.w800, color: urgent ? AppColors.sunset : AppColors.gold)),
        ],
      ),
    );
  }
}
