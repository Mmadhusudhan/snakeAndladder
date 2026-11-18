import 'dart:collection';
import 'dart:math';

/// Source of dice values. Swappable so tests are deterministic and so online
/// play can use server-generated rolls.
abstract class Dice {
  int get sides;
  int roll();
}

/// Uniform random dice.
class RandomDice implements Dice {
  RandomDice({this.sides = 6, Random? random}) : _random = random ?? Random();

  @override
  final int sides;
  final Random _random;

  @override
  int roll() => _random.nextInt(sides) + 1;
}

/// Dice that returns a scripted sequence, then repeats the last value.
class FixedDice implements Dice {
  FixedDice(Iterable<int> values, {this.sides = 6})
      : _values = Queue.of(values),
        assert(values.isNotEmpty);

  @override
  final int sides;
  final Queue<int> _values;
  int? _last;

  @override
  int roll() {
    if (_values.isNotEmpty) _last = _values.removeFirst();
    return _last!;
  }
}

/// Dice fed from outside, one value per roll. Used to replay server-decided
/// online moves through the local engine so animations match local play.
class ScriptedDice implements Dice {
  ScriptedDice({this.sides = 6});

  @override
  final int sides;
  final Queue<int> _values = Queue();

  void enqueue(int value) => _values.add(value);
  bool get hasNext => _values.isNotEmpty;

  @override
  int roll() {
    if (_values.isEmpty) throw StateError('No scripted roll available');
    return _values.removeFirst();
  }
}
