import 'package:flutter_test/flutter_test.dart';
import 'package:snakes_ladders/features/game/engine/dice.dart';
import 'package:snakes_ladders/features/game/engine/game_engine.dart';
import 'package:snakes_ladders/features/game/models/bot_personality.dart';
import 'package:snakes_ladders/features/game/models/game_state.dart';
import 'package:snakes_ladders/features/game/models/player.dart';

Player bot(ComputerLevel level, {int position = 0}) => Player(
      id: 'bot',
      name: 'Bot',
      colorIndex: 1,
      type: PlayerType.computer,
      level: level,
      botId: 'mango',
      position: position,
    );

const human = Player(id: 'h', name: 'Ann', colorIndex: 0);

GameEngine engine(List<int> rolls, Player first, {Player second = human}) => GameEngine(
      players: [first, second],
      dice: FixedDice(rolls),
      timings: EngineTimings.instant,
      autoPlayComputer: false,
    )..start();

void main() {
  group('computer rolling', () {
    test('normal bot uses the dice as is', () async {
      final e = engine([2, 5], bot(ComputerLevel.normal));
      await e.rollDice();
      expect(e.state.lastRoll, 2);
      e.dispose();
    });

    test('hard bot keeps the better of two rolls', () async {
      // From 10: a 6 lands on the snake at 16, a 3 is a plain move.
      final e = engine([6, 3], bot(ComputerLevel.hard, position: 10));
      await e.rollDice();
      expect(e.state.lastRoll, 3);
      expect(e.state.players[0].position, 13);
      e.dispose();
    });

    test('hard bot prefers a ladder and a win', () async {
      final ladder = engine([2, 1], bot(ComputerLevel.hard, position: 2)); // 1 -> 3 plain, 2 -> 4 ladder
      await ladder.rollDice();
      expect(ladder.state.lastRoll, 2);
      expect(ladder.state.players[0].position, 14);
      ladder.dispose();

      final win = engine([1, 3], bot(ComputerLevel.hard, position: 97));
      await win.rollDice();
      expect(win.state.lastRoll, 3);
      expect(win.state.phase, GamePhase.completed);
      win.dispose();
    });

    test('easy bot keeps the worse roll when the coin says so', () async {
      // rolls: a=3, b=6 (snake from 10), coin=1 (<= 3 -> keep worse).
      final e = engine([3, 6, 1], bot(ComputerLevel.easy, position: 10));
      await e.rollDice();
      expect(e.state.lastRoll, 6);
      expect(e.state.players[0].position, 6); // slid down the snake
      e.dispose();
    });

    test('easy bot keeps the first roll when the coin says so', () async {
      final e = engine([3, 6, 5], bot(ComputerLevel.easy, position: 10));
      await e.rollDice();
      expect(e.state.lastRoll, 3);
      e.dispose();
    });

    test('humans are never affected by a level', () async {
      const luckyHuman = Player(id: 'h', name: 'Ann', colorIndex: 0, level: ComputerLevel.hard, position: 10);
      final e = engine([6, 1], luckyHuman);
      await e.rollDice();
      expect(e.state.lastRoll, 6);
      e.dispose();
    });
  });

  group('stats', () {
    test('counts rolls, sixes, ladders, snakes, blocked and cells', () async {
      // Ann: 4 (ladder 4->14), Bot: 6 (extra), 6, 4 -> 16 snake. Ann at 14: ...
      final e = GameEngine(
        players: const [
          Player(id: 'a', name: 'Ann', colorIndex: 0, position: 97),
          Player(id: 'b', name: 'Ben', colorIndex: 1, position: 10),
        ],
        dice: FixedDice([5, 6, 2, 1]),
        timings: EngineTimings.instant,
        autoPlayComputer: false,
      )..start();
      await e.rollDice(); // Ann 5 -> blocked
      await e.rollDice(); // Ben 6 -> 16 snake -> 6, extra turn
      await e.rollDice(); // Ben 2 -> 8
      await e.rollDice(); // Ann 1 -> 98
      final a = e.state.stats[0];
      final b = e.state.stats[1];
      expect(a.rolls, 2);
      expect(a.blocked, 1);
      expect(a.cellsMoved, 1);
      expect(b.rolls, 2);
      expect(b.sixes, 1);
      expect(b.snakes, 1);
      expect(b.cellsMoved, 8);
      expect(b.ladders, 0);
      e.dispose();
    });

    test('ranking orders by position, then fewer rolls', () {
      final s = GameState(
        players: const [
          Player(id: 'a', name: 'A', colorIndex: 0, position: 40),
          Player(id: 'b', name: 'B', colorIndex: 1, position: 70),
          Player(id: 'c', name: 'C', colorIndex: 2, position: 40),
        ],
        stats: const [PlayerStats(rolls: 9), PlayerStats(rolls: 5), PlayerStats(rolls: 7)],
      );
      expect(s.ranking, [1, 2, 0]);
    });

    test('completedAt is set when the game ends', () async {
      final e = engine([3], const Player(id: 'a', name: 'A', colorIndex: 0, position: 97));
      expect(e.state.completedAt, isNull);
      await e.rollDice();
      expect(e.state.completedAt, isNotNull);
      expect(e.state.elapsed, greaterThanOrEqualTo(Duration.zero));
      e.dispose();
    });
  });

  group('personalities', () {
    test('every bot has a win line and remarks cycle', () {
      for (final b in BotPersonality.all) {
        expect(b.remarkFor(GameEventType.won, 0), isNotNull);
        expect(b.remarkFor(GameEventType.moved, 0), isNull);
        final lines = b.remarks[GameEventType.ladder]!;
        expect(b.remarkFor(GameEventType.ladder, lines.length), lines.first);
      }
      expect(BotPersonality.byId('nope'), isNull);
      expect(BotPersonality.byId('koko')?.avatar, '🦜');
    });

    test('possessive handles the default "You" name', () {
      expect(const Player(id: 'a', name: 'You', colorIndex: 0).possessive, 'Your');
      expect(const Player(id: 'a', name: 'Ann', colorIndex: 0).possessive, "Ann's");
    });

    test('think delay scales with level', () {
      expect(ComputerLevel.hard.thinkFactor, lessThan(ComputerLevel.normal.thinkFactor));
      expect(ComputerLevel.easy.thinkFactor, greaterThan(ComputerLevel.normal.thinkFactor));
    });
  });
}
