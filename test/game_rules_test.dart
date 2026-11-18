import 'package:flutter_test/flutter_test.dart';
import 'package:snakes_ladders/features/game/engine/game_rules.dart';
import 'package:snakes_ladders/features/game/models/board_config.dart';
import 'package:snakes_ladders/features/game/models/game_rules_config.dart';

void main() {
  const rules = GameRules();

  group('plain movement', () {
    test('moves forward by the roll and records the path', () {
      final m = rules.resolve(from: 2, roll: 3);
      expect(m.outcome, MoveOutcome.normal);
      expect(m.path, [3, 4, 5]);
      expect(m.finalPosition, 5);
    });

    test('from the start cell a roll of 1 lands on cell 1 (ladder)', () {
      final m = rules.resolve(from: 0, roll: 1);
      expect(m.outcome, MoveOutcome.ladder);
      expect(m.landing, 1);
      expect(m.finalPosition, 38);
    });
  });

  group('snakes and ladders', () {
    test('landing on a snake head slides to the tail', () {
      final m = rules.resolve(from: 10, roll: 6); // 16 -> 6
      expect(m.outcome, MoveOutcome.snake);
      expect(m.landing, 16);
      expect(m.finalPosition, 6);
    });

    test('landing on a ladder bottom climbs to the top', () {
      final m = rules.resolve(from: 25, roll: 3); // 28 -> 84
      expect(m.outcome, MoveOutcome.ladder);
      expect(m.finalPosition, 84);
    });

    test('ladder to 100 counts as a win', () {
      final m = rules.resolve(from: 77, roll: 3); // 80 -> 100
      expect(m.outcome, MoveOutcome.win);
      expect(m.finalPosition, 100);
    });
  });

  group('winning', () {
    test('exact roll reaches 100', () {
      final m = rules.resolve(from: 97, roll: 3);
      expect(m.outcome, MoveOutcome.win);
      expect(m.path, [98, 99, 100]);
    });

    test('overshooting is blocked when exact roll is required', () {
      final m = rules.resolve(from: 97, roll: 4);
      expect(m.outcome, MoveOutcome.blocked);
      expect(m.moved, isFalse);
      expect(m.finalPosition, 97);
    });

    test('overshooting clamps to 100 when exact roll is off', () {
      const relaxed = GameRules(config: GameRulesConfig(exactRollToWin: false));
      final m = relaxed.resolve(from: 97, roll: 6);
      expect(m.outcome, MoveOutcome.win);
      expect(m.finalPosition, 100);
      expect(m.path, [98, 99, 100]);
    });

    test('a finished player cannot move', () {
      expect(rules.resolve(from: 100, roll: 1).outcome, MoveOutcome.blocked);
    });
  });

  group('need six to start', () {
    const strict = GameRules(config: GameRulesConfig(needSixToStart: true));

    test('blocks non-six from the start cell', () {
      expect(strict.resolve(from: 0, roll: 3).outcome, MoveOutcome.blocked);
    });

    test('allows a six from the start cell', () {
      final m = strict.resolve(from: 0, roll: 6);
      expect(m.outcome, MoveOutcome.normal);
      expect(m.finalPosition, 6);
    });

    test('does not affect players already on the board', () {
      expect(strict.resolve(from: 5, roll: 2).outcome, MoveOutcome.normal);
    });
  });

  group('turn rules', () {
    test('six grants an extra turn by default', () {
      expect(rules.grantsExtraTurn(6), isTrue);
      expect(rules.grantsExtraTurn(5), isFalse);
    });

    test('extra turn can be disabled', () {
      const r = GameRules(config: GameRulesConfig(extraTurnOnSix: false));
      expect(r.grantsExtraTurn(6), isFalse);
    });

    test('three sixes forfeit, two do not', () {
      expect(rules.forfeitsTurn(2), isFalse);
      expect(rules.forfeitsTurn(3), isTrue);
    });

    test('forfeit can be disabled', () {
      const r = GameRules(config: GameRulesConfig(maxConsecutiveSixes: 0));
      expect(r.forfeitsTurn(10), isFalse);
    });

    test('next player wraps around', () {
      expect(rules.nextPlayerIndex(0, 3), 1);
      expect(rules.nextPlayerIndex(2, 3), 0);
    });
  });

  test('custom boards are honoured', () {
    const custom = GameRules(board: BoardConfig(snakes: {9: 2}, ladders: {3: 7}));
    expect(custom.resolve(from: 1, roll: 2).finalPosition, 7);
    expect(custom.resolve(from: 7, roll: 2).finalPosition, 2);
  });
}
