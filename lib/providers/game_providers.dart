import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/game/engine/game_engine.dart';
import '../features/game/models/board_config.dart';
import '../features/game/models/bot_personality.dart';
import '../features/game/models/game_rules_config.dart';
import '../features/game/models/game_state.dart';
import '../features/game/models/player.dart';

/// Which kind of match the user picked.
enum GameMode { vsComputer, localMultiplayer, practice }

/// Everything needed to start a game.
class GameSetup {
  const GameSetup({
    required this.mode,
    required this.players,
    this.rules = GameRulesConfig.classic,
    this.board = BoardConfig.classic,
    this.botLevel = ComputerLevel.normal,
  });

  final GameMode mode;
  final List<Player> players;
  final GameRulesConfig rules;
  final BoardConfig board;

  /// Strength applied to every computer player in the match.
  final ComputerLevel botLevel;

  static const List<String> defaultAvatars = ['🦁', '🐸', '🦊', '🐼'];

  bool get hasComputer => players.any((p) => p.isComputer);
  int get humanCount => players.where((p) => !p.isComputer).length;

  /// Default line-up for a mode. Against the computer, seat 0 is you and the
  /// rest are bots with their own personalities. Practice is you versus one
  /// easy bot with relaxed rules.
  factory GameSetup.defaultFor(GameMode mode, {int playerCount = 2}) {
    final count = playerCount.clamp(2, 4);
    final level = mode == GameMode.practice ? ComputerLevel.easy : ComputerLevel.normal;
    final players = <Player>[];
    var botIndex = 0;
    for (var i = 0; i < count; i++) {
      final isComputer = mode != GameMode.localMultiplayer && i > 0;
      if (isComputer) {
        final bot = BotPersonality.all[botIndex++ % BotPersonality.all.length];
        players.add(Player(
          id: 'p$i',
          name: bot.name,
          colorIndex: i,
          avatar: bot.avatar,
          type: PlayerType.computer,
          level: level,
          botId: bot.id,
        ));
      } else {
        players.add(Player(
          id: 'p$i',
          name: i == 0 && mode != GameMode.localMultiplayer ? 'You' : 'Player ${i + 1}',
          colorIndex: i,
          avatar: defaultAvatars[i],
        ));
      }
    }
    final rules = mode == GameMode.practice
        ? const GameRulesConfig(exactRollToWin: false)
        : GameRulesConfig.classic;
    return GameSetup(mode: mode, players: players, rules: rules, botLevel: level);
  }

  GameSetup copyWith({
    GameMode? mode,
    List<Player>? players,
    GameRulesConfig? rules,
    BoardConfig? board,
    ComputerLevel? botLevel,
  }) {
    return GameSetup(
      mode: mode ?? this.mode,
      players: players ?? this.players,
      rules: rules ?? this.rules,
      board: board ?? this.board,
      botLevel: botLevel ?? this.botLevel,
    );
  }
}

/// Holds the setup chosen on the home / setup screens.
class GameSetupNotifier extends Notifier<GameSetup> {
  @override
  GameSetup build() => GameSetup.defaultFor(GameMode.vsComputer);

  void set(GameSetup setup) => state = setup;

  void setMode(GameMode mode, {int? playerCount}) {
    state = GameSetup.defaultFor(mode, playerCount: playerCount ?? state.players.length);
  }

  /// Changes the number of seats while keeping names, avatars, colours and
  /// rules the user already chose.
  void setPlayerCount(int count) {
    final fresh = GameSetup.defaultFor(state.mode, playerCount: count);
    final players = <Player>[];
    for (var i = 0; i < fresh.players.length; i++) {
      final existing = i < state.players.length ? state.players[i] : null;
      final p = existing ?? fresh.players[i];
      players.add(p.copyWith(level: p.isComputer ? state.botLevel : null));
    }
    state = state.copyWith(players: players);
  }

  /// Applies a strength to every bot in the match.
  void setBotLevel(ComputerLevel level) {
    state = state.copyWith(
      botLevel: level,
      players: [
        for (final p in state.players) p.isComputer ? p.copyWith(level: level) : p,
      ],
    );
  }

  /// Gives [index] the colour [colorIndex], swapping with whoever had it.
  void setColor(int index, int colorIndex) {
    final players = List<Player>.of(state.players);
    final previous = players[index].colorIndex;
    for (var i = 0; i < players.length; i++) {
      if (i != index && players[i].colorIndex == colorIndex) {
        players[i] = players[i].copyWith(colorIndex: previous);
      }
    }
    players[index] = players[index].copyWith(colorIndex: colorIndex);
    state = state.copyWith(players: players);
  }

  void renamePlayer(int index, String name) {
    final players = List<Player>.of(state.players);
    final trimmed = name.trim();
    players[index] = players[index]
        .copyWith(name: trimmed.isEmpty ? 'Player ${index + 1}' : trimmed);
    state = state.copyWith(players: players);
  }

  void setAvatar(int index, String avatar) {
    final players = List<Player>.of(state.players);
    players[index] = players[index].copyWith(avatar: avatar);
    state = state.copyWith(players: players);
  }

  void setRules(GameRulesConfig rules) => state = state.copyWith(rules: rules);
}

final gameSetupProvider =
    NotifierProvider<GameSetupNotifier, GameSetup>(GameSetupNotifier.new);

/// Bridges the pure [GameEngine] into Riverpod. A new engine is created
/// whenever the setup changes, and disposed when the game screen closes.
class GameController extends Notifier<GameState> {
  late GameEngine _engine;
  StreamSubscription<GameState>? _subscription;

  @override
  GameState build() {
    final setup = ref.watch(gameSetupProvider);
    _engine = GameEngine(
      players: setup.players,
      rulesConfig: setup.rules,
      board: setup.board,
    );
    _subscription = _engine.stream.listen((s) => state = s);
    ref.onDispose(() {
      _subscription?.cancel();
      _engine.dispose();
    });
    // Start after build completes so a computer going first can roll.
    Future.microtask(_engine.start);
    return _engine.state;
  }

  EngineTimings get timings => _engine.timings;

  Future<bool> rollDice() => _engine.rollDice();
  void pause() => _engine.pause();
  void resume() => _engine.resume();
  void restart() => _engine.reset();
}

final gameControllerProvider =
    NotifierProvider.autoDispose<GameController, GameState>(GameController.new);
