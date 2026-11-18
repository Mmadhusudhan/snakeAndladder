import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/game_providers.dart';
import '../board/board_widget.dart';
import '../components/dice_widget.dart';
import '../components/game_audio_bridge.dart';
import '../components/player_panel.dart';
import '../components/roll_button.dart';
import '../components/turn_banner.dart';
import '../models/game_state.dart';
import 'game_result_screen.dart';

/// The playable board screen. Works in portrait (board on top, controls
/// below) and landscape / desktop (board left, controls right).
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _resultShown = false;

  void _roll() => ref.read(gameControllerProvider.notifier).rollDice();

  Future<void> _showPause() async {
    final controller = ref.read(gameControllerProvider.notifier);
    controller.pause();
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paused', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, 'resume'),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Resume'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'restart'),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Restart'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'quit'),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Quit to home'),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'restart':
        _resultShown = false;
        controller.restart();
        controller.resume();
      case 'quit':
        Navigator.of(context).pop();
      default:
        controller.resume();
    }
  }

  Future<void> _showResult(GameState state) async {
    if (state.winner == null) return;
    final controller = ref.read(gameControllerProvider.notifier);
    // Save to history / stats while the winning burst plays.
    final recording = ref.read(matchRecorderProvider).record(
          ref.read(authStateProvider).value,
          state,
          ref.read(gameSetupProvider),
        );
    await Future.wait([
      recording.catchError((Object e) {
        debugPrint('Could not record match: $e');
        return null;
      }),
      Future<void>.delayed(const Duration(milliseconds: 900)),
    ]);
    if (!mounted) return;
    final action = await GameResultScreen.show(context, state);
    if (!mounted) return;
    switch (action) {
      case ResultAction.playAgain:
      case null:
        _resultShown = false;
        controller.restart();
      case ResultAction.changePlayers:
        Navigator.of(context).pop();
      case ResultAction.home:
        Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final setup = ref.watch(gameSetupProvider);

    ref.listen<GameState>(gameControllerProvider, (prev, next) {
      if (next.isCompleted && !_resultShown) {
        _resultShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _showResult(next));
      }
    });

    final brightness = Theme.of(context).brightness;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _roll,
        const SingleActivator(LogicalKeyboardKey.enter): _roll,
        const SingleActivator(LogicalKeyboardKey.escape): _showPause,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Container(
            decoration: AppTheme.background(brightness),
            child: SafeArea(
              child: Stack(
                children: [
                  GameAudioBridge(state: state),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > constraints.maxHeight * 1.05;
                      return wide
                          ? _buildWide(context, constraints, state, controller, setup)
                          : _buildTall(context, constraints, state, controller, setup);
                    },
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 56,
                    child: TurnBanner(state: state),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Pause',
            onPressed: _showPause,
            icon: const Icon(Icons.pause_circle_filled_rounded, color: AppColors.gold, size: 30),
          ),
          const Expanded(
            child: Text(
              'SNAKES & LADDERS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 2,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Restart',
            onPressed: () {
              _resultShown = false;
              ref.read(gameControllerProvider.notifier).restart();
            },
            icon: const Icon(Icons.refresh_rounded, color: AppColors.gold, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _diceArea(GameState state, GameController controller, {double size = 84}) {
    final enabled = state.awaitingHumanRoll;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DiceWidget(
          size: size,
          value: state.lastRoll,
          targetValue: state.pendingRoll,
          isRolling: state.phase == GamePhase.rolling,
          rollDuration: controller.timings.roll,
          enabled: enabled,
          onTap: _roll,
        ),
        const SizedBox(height: 6),
        RollButton(enabled: enabled, onPressed: _roll),
      ],
    );
  }

  Widget _buildTall(
    BuildContext context,
    BoxConstraints c,
    GameState state,
    GameController controller,
    GameSetup setup,
  ) {
    const topBar = 48.0;
    const panelMin = 190.0;
    final boardSize = (c.maxWidth - 24).clamp(200.0, c.maxHeight - topBar - panelMin);
    return Column(
      children: [
        _topBar(context),
        Expanded(
          child: Center(
            child: BoardWidget(
              size: boardSize,
              board: setup.board,
              state: state,
              timings: controller.timings,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EventBanner(state: state),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: PlayerPanel(state: state, axis: Axis.horizontal)),
                  const SizedBox(width: 8),
                  _diceArea(state, controller, size: 70),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWide(
    BuildContext context,
    BoxConstraints c,
    GameState state,
    GameController controller,
    GameSetup setup,
  ) {
    final boardSize = (c.maxHeight - 24).clamp(200.0, c.maxWidth - 300);
    return Row(
      children: [
        Expanded(
          child: Center(
            child: BoardWidget(
              size: boardSize,
              board: setup.board,
              state: state,
              timings: controller.timings,
            ),
          ),
        ),
        SizedBox(
          width: (c.maxWidth - boardSize - 24).clamp(260.0, 380.0),
          child: Column(
            children: [
              _topBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: PlayerPanel(state: state),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    EventBanner(state: state),
                    const SizedBox(height: 16),
                    _diceArea(state, controller, size: 96),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
