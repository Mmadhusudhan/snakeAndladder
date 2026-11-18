import 'package:flutter_test/flutter_test.dart';
import 'package:snakes_ladders/features/game/engine/dice.dart';
import 'package:snakes_ladders/features/game/engine/game_engine.dart';
import 'package:snakes_ladders/features/game/models/game_rules_config.dart';
import 'package:snakes_ladders/features/game/models/game_state.dart';
import 'package:snakes_ladders/features/game/models/player.dart';

List<Player> twoHumans() => const [
      Player(id: 'a', name: 'Ann', colorIndex: 0),
      Player(id: 'b', name: 'Ben', colorIndex: 1),
    ];

GameEngine engineWith(
  List<int> rolls, {
  List<Player>? players,
  GameRulesConfig rules = GameRulesConfig.classic,
  bool autoPlayComputer = false,
}) {
  return GameEngine(
    players: players ?? twoHumans(),
    rulesConfig: rules,
    dice: FixedDice(rolls),
    timings: EngineTimings.instant,
    autoPlayComputer: autoPlayComputer,
  )..start();
}

void main() {
  test('starts waiting on player 0 with everyone at the start', () {
    final e = engineWith([1]);
    expect(e.state.phase, GamePhase.waiting);
    expect(e.state.currentPlayerIndex, 0);
    expect(e.state.players.every((p) => p.position == 0), isTrue);
    e.dispose();
  });

  test('a roll moves the player and passes the turn', () async {
    final e = engineWith([3]);
    expect(await e.rollDice(), isTrue);
    expect(e.state.players[0].position, 3);
    expect(e.state.lastRoll, 3);
    expect(e.state.currentPlayerIndex, 1);
    expect(e.state.phase, GamePhase.waiting);
    expect(e.state.turnNumber, 2);
    e.dispose();
  });

  test('rolling a six keeps the turn', () async {
    final e = engineWith([6, 2]);
    await e.rollDice();
    expect(e.state.players[0].position, 6);
    expect(e.state.currentPlayerIndex, 0);
    expect(e.state.consecutiveSixes, 1);
    expect(e.state.events.last.type, GameEventType.extraTurn);
    await e.rollDice();
    expect(e.state.players[0].position, 8);
    expect(e.state.currentPlayerIndex, 1);
    expect(e.state.consecutiveSixes, 0);
    e.dispose();
  });

  test('three sixes in a row forfeit the turn without moving', () async {
    final e = engineWith([6, 6, 6]);
    await e.rollDice();
    await e.rollDice();
    expect(e.state.players[0].position, 12);
    await e.rollDice();
    expect(e.state.players[0].position, 12);
    expect(e.state.currentPlayerIndex, 1);
    expect(e.state.events.any((ev) => ev.type == GameEventType.forfeit), isTrue);
    e.dispose();
  });

  test('landing on a snake slides down and reports the event', () async {
    // 0 -> 6 (extra turn) -> 10 -> 16 is a snake head -> 6 ... use 4 then 6.
    final e = engineWith([4, 6, 6, 1]);
    await e.rollDice(); // Ann to 4 -> ladder to 14
    expect(e.state.players[0].position, 14);
    expect(e.state.events.any((ev) => ev.type == GameEventType.ladder), isTrue);
    await e.rollDice(); // Ben rolls 6 -> 6, extra turn
    await e.rollDice(); // Ben rolls 6 -> 12, extra turn
    await e.rollDice(); // Ben rolls 1 -> 13
    expect(e.state.players[1].position, 13);
    e.dispose();
  });

  test('snake head sends the token to the tail', () async {
    final e = engineWith([5, 5, 5]); // Ann: 5, Ben: 5, Ann: 10 -> ... use 47
    final custom = GameEngine(
      players: twoHumans(),
      dice: FixedDice([6, 6, 4]),
      timings: EngineTimings.instant,
      rulesConfig: const GameRulesConfig(maxConsecutiveSixes: 0),
    )..start();
    await custom.rollDice(); // 6
    await custom.rollDice(); // 12
    await custom.rollDice(); // 16 -> snake to 6
    expect(custom.state.players[0].position, 6);
    expect(custom.state.events.any((ev) => ev.type == GameEventType.snake), isTrue);
    final landed = custom.state.events.firstWhere((ev) => ev.type == GameEventType.landed);
    expect(landed.from, 16);
    expect(landed.to, 6);
    expect(custom.state.transitionTo, isNull);
    custom.dispose();
    e.dispose();
  });

  test('exact roll wins and locks the game', () async {
    final players = [
      const Player(id: 'a', name: 'Ann', colorIndex: 0, position: 97),
      const Player(id: 'b', name: 'Ben', colorIndex: 1, position: 50),
    ];
    final e = engineWith([4, 2, 3], players: players);
    await e.rollDice(); // 4 overshoots -> blocked, turn passes
    expect(e.state.players[0].position, 97);
    expect(e.state.events.last.type, GameEventType.blocked);
    expect(e.state.currentPlayerIndex, 1);
    await e.rollDice(); // Ben 52
    await e.rollDice(); // Ann exact 3 -> 100
    expect(e.state.phase, GamePhase.completed);
    expect(e.state.winnerIndex, 0);
    expect(e.state.isInputLocked, isTrue);
    expect(await e.rollDice(), isFalse);
    e.dispose();
  });

  test('pendingRoll is known while rolling and lastRoll only afterwards', () async {
    final e = GameEngine(
      players: twoHumans(),
      dice: FixedDice([4]),
      timings: const EngineTimings(roll: Duration(milliseconds: 5)),
      autoPlayComputer: false,
    )..start();
    final future = e.rollDice();
    expect(e.state.phase, GamePhase.rolling);
    expect(e.state.pendingRoll, 4);
    expect(e.state.lastRoll, isNull);
    await future;
    expect(e.state.lastRoll, 4);
    e.dispose();
  });

  test('a second roll during a turn is ignored', () async {
    final e = GameEngine(
      players: twoHumans(),
      dice: FixedDice([2, 3]),
      timings: const EngineTimings(roll: Duration(milliseconds: 5)),
      autoPlayComputer: false,
    )..start();
    final first = e.rollDice();
    final second = e.rollDice();
    expect(await second, isFalse);
    expect(await first, isTrue);
    expect(e.state.players[0].position, 2);
    e.dispose();
  });

  test('pause blocks rolling and resume allows it', () async {
    final e = engineWith([2]);
    e.pause();
    expect(await e.rollDice(), isFalse);
    e.resume();
    expect(await e.rollDice(), isTrue);
    e.dispose();
  });

  test('reset returns everyone to the start', () async {
    final e = engineWith([3, 4]);
    await e.rollDice();
    await e.rollDice();
    e.reset();
    expect(e.state.players.every((p) => p.position == 0), isTrue);
    expect(e.state.currentPlayerIndex, 0);
    expect(e.state.events, isEmpty);
    expect(e.state.turnNumber, 1);
    e.dispose();
  });

  test('computer players play automatically until someone wins', () async {
    final e = GameEngine(
      players: const [
        Player(id: 'a', name: 'Bot A', colorIndex: 0, type: PlayerType.computer),
        Player(id: 'b', name: 'Bot B', colorIndex: 1, type: PlayerType.computer),
      ],
      dice: FixedDice([5]),
      timings: EngineTimings.instant,
    );
    final done = e.stream.firstWhere((s) => s.isCompleted);
    e.start();
    final finalState = await done.timeout(const Duration(seconds: 5));
    // Rolling 5 forever: 5,10,...,80 -> ladder to 100.
    expect(finalState.winnerIndex, 0);
    expect(finalState.players[0].position, 100);
    e.dispose();
  });

  test('slide and climb durations grow with distance and are capped', () {
    const t = EngineTimings();
    expect(t.snakeDuration(56, 53), const Duration(milliseconds: 700 + 18 * 3));
    expect(t.snakeDuration(87, 24), const Duration(milliseconds: 700 + 18 * 63));
    expect(t.ladderDuration(28, 84), const Duration(milliseconds: 700 + 22 * 56));
    expect(t.ladderDuration(1, 100), t.maxTransition);
    expect(EngineTimings.instant.snakeDuration(87, 24), Duration.zero);
  });

  test('dispose stops an in-flight turn', () async {
    final e = GameEngine(
      players: twoHumans(),
      dice: FixedDice([3]),
      timings: const EngineTimings(roll: Duration(milliseconds: 20)),
    )..start();
    final rolling = e.rollDice();
    e.dispose();
    expect(await rolling, isFalse);
  });
}
