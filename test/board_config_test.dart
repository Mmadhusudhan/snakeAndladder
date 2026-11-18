import 'package:flutter_test/flutter_test.dart';
import 'package:snakes_ladders/features/game/models/board_config.dart';

void main() {
  test('classic board is valid', () {
    expect(BoardConfig.classic.validate(), isEmpty);
    expect(BoardConfig.classic.snakes.length, 10);
    expect(BoardConfig.classic.ladders.length, 9);
  });

  test('snake must go down and ladder must go up', () {
    const bad = BoardConfig(snakes: {5: 20}, ladders: {50: 30});
    final issues = bad.validate();
    expect(issues, contains(contains('must go down')));
    expect(issues, contains(contains('must go up')));
  });

  test('a cell cannot be both a snake head and a ladder bottom', () {
    const bad = BoardConfig(snakes: {40: 10}, ladders: {40: 80});
    expect(bad.validate(), contains(contains('both a snake head and a ladder bottom')));
  });

  test('chained snakes and ladders are rejected', () {
    const bad = BoardConfig(snakes: {40: 20}, ladders: {20: 80});
    expect(bad.isValid, isFalse);
  });

  test('cells must be on the board', () {
    const bad = BoardConfig(snakes: {101: 5}, ladders: {0: 9});
    expect(bad.validate().length, 2);
  });
}
