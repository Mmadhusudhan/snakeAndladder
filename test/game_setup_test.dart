import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snakes_ladders/features/game/models/bot_personality.dart';
import 'package:snakes_ladders/providers/game_providers.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  GameSetupNotifier n() => container.read(gameSetupProvider.notifier);
  GameSetup s() => container.read(gameSetupProvider);

  test('vs computer seats you first and bots with distinct personalities', () {
    n().setMode(GameMode.vsComputer, playerCount: 4);
    final players = s().players;
    expect(players.first.isComputer, isFalse);
    expect(players.first.name, 'You');
    final bots = players.where((p) => p.isComputer).toList();
    expect(bots.length, 3);
    expect(bots.map((b) => b.botId).toSet().length, 3);
    expect(bots.every((b) => b.level == ComputerLevel.normal), isTrue);
  });

  test('local multiplayer has only humans', () {
    n().setMode(GameMode.localMultiplayer, playerCount: 3);
    expect(s().players.every((p) => !p.isComputer), isTrue);
    expect(s().hasComputer, isFalse);
  });

  test('practice is one easy bot with relaxed rules', () {
    n().setMode(GameMode.practice);
    expect(s().players.length, 2);
    expect(s().players[1].level, ComputerLevel.easy);
    expect(s().rules.exactRollToWin, isFalse);
  });

  test('changing player count keeps edited names and colours', () {
    n().setMode(GameMode.localMultiplayer, playerCount: 2);
    n().renamePlayer(0, 'Zara');
    n().setColor(0, 3);
    n().setPlayerCount(4);
    expect(s().players.length, 4);
    expect(s().players[0].name, 'Zara');
    expect(s().players[0].colorIndex, 3);
    n().setPlayerCount(2);
    expect(s().players.length, 2);
    expect(s().players[0].name, 'Zara');
  });

  test('setBotLevel applies to every bot', () {
    n().setMode(GameMode.vsComputer, playerCount: 3);
    n().setBotLevel(ComputerLevel.hard);
    expect(s().botLevel, ComputerLevel.hard);
    expect(s().players.where((p) => p.isComputer).every((p) => p.level == ComputerLevel.hard), isTrue);
    expect(s().players.first.level, isNull);
  });

  test('setColor swaps with the player who had that colour', () {
    n().setMode(GameMode.localMultiplayer, playerCount: 3);
    n().setColor(2, 0);
    expect(s().players[2].colorIndex, 0);
    expect(s().players[0].colorIndex, 2);
    final colours = s().players.map((p) => p.colorIndex).toSet();
    expect(colours.length, 3);
  });

  test('blank names fall back to a default', () {
    n().setMode(GameMode.localMultiplayer);
    n().renamePlayer(1, '   ');
    expect(s().players[1].name, 'Player 2');
  });
}
