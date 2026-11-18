import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/services/audio_service.dart';
import '../../../core/services/haptics_service.dart';
import '../../../providers/settings_providers.dart';
import '../models/game_state.dart';

/// Turns game state changes into sounds and vibration. Pure mapping, no UI.
class GameAudioMapper {
  const GameAudioMapper();

  /// Returns what to play for the transition [prev] -> [next].
  List<Sfx> sfxFor(GameState? prev, GameState next) {
    final out = <Sfx>[];
    if (prev == null) return out;
    if (next.phase == GamePhase.rolling && prev.phase != GamePhase.rolling) out.add(Sfx.dice);
    if (next.phase == GamePhase.moving && prev.phase == GamePhase.moving) {
      final i = next.currentPlayerIndex;
      if (i < prev.players.length && next.players[i].position != prev.players[i].position) out.add(Sfx.step);
    }
    for (final e in next.events.skip(prev.events.length)) {
      switch (e.type) {
        case GameEventType.snake:
          out.add(Sfx.snake);
        case GameEventType.ladder:
          out.add(Sfx.ladder);
        case GameEventType.won:
          out.add(Sfx.win);
        case GameEventType.extraTurn:
          out.add(Sfx.six);
        case GameEventType.blocked:
        case GameEventType.forfeit:
          out.add(Sfx.blocked);
        default:
          break;
      }
    }
    final turnPassed = next.phase == GamePhase.waiting &&
        prev.phase != GamePhase.waiting &&
        next.currentPlayerIndex != prev.currentPlayerIndex &&
        !next.currentPlayer.isComputer &&
        !next.isCompleted;
    if (turnPassed) out.add(Sfx.turn);
    return out;
  }
}

/// Place once on a game screen; feed it the latest [GameState].
class GameAudioBridge extends ConsumerStatefulWidget {
  const GameAudioBridge({super.key, required this.state, this.child});

  final GameState state;
  final Widget? child;

  @override
  ConsumerState<GameAudioBridge> createState() => _GameAudioBridgeState();
}

class _GameAudioBridgeState extends ConsumerState<GameAudioBridge> {
  static const _mapper = GameAudioMapper();

  @override
  void didUpdateWidget(GameAudioBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.state, widget.state)) return;
    final audio = ref.read(audioServiceProvider);
    final haptics = ref.read(hapticsProvider);
    for (final sfx in _mapper.sfxFor(oldWidget.state, widget.state)) {
      audio.play(sfx);
      _buzz(haptics, sfx);
    }
  }

  void _buzz(HapticsService haptics, Sfx sfx) {
    switch (sfx) {
      case Sfx.step:
        haptics.selection();
      case Sfx.dice:
      case Sfx.six:
      case Sfx.turn:
        haptics.light();
      case Sfx.ladder:
        haptics.medium();
      case Sfx.snake:
      case Sfx.win:
      case Sfx.blocked:
        haptics.heavy();
      case Sfx.click:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}
