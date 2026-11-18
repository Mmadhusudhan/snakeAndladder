import 'game_state.dart';

/// How strong a computer opponent is.
///
/// Snakes & Ladders is pure luck, so "difficulty" works on the dice: a hard
/// bot rolls twice and keeps the better result, an easy bot sometimes keeps
/// the worse one. Normal bots roll exactly like a human. This is shown to
/// the player in the setup screen, never hidden.
enum ComputerLevel { easy, normal, hard }

extension ComputerLevelInfo on ComputerLevel {
  String get label => switch (this) {
        ComputerLevel.easy => 'Easy',
        ComputerLevel.normal => 'Normal',
        ComputerLevel.hard => 'Hard',
      };

  String get description => switch (this) {
        ComputerLevel.easy => 'Bots are a bit unlucky and slow to think',
        ComputerLevel.normal => 'Bots roll just like you do',
        ComputerLevel.hard => 'Bots get lucky more often and play fast',
      };

  /// Multiplier on the engine's base thinking delay.
  double get thinkFactor => switch (this) {
        ComputerLevel.easy => 1.5,
        ComputerLevel.normal => 1.0,
        ComputerLevel.hard => 0.65,
      };
}

/// A named computer opponent with an avatar and a few things to say.
class BotPersonality {
  const BotPersonality({
    required this.id,
    required this.name,
    required this.avatar,
    required this.remarks,
  });

  final String id;
  final String name;
  final String avatar;
  final Map<GameEventType, List<String>> remarks;

  /// A line for [type], chosen by [salt] so the same event does not always
  /// produce the same sentence. Null when the bot has nothing to say.
  String? remarkFor(GameEventType type, int salt) {
    final lines = remarks[type];
    if (lines == null || lines.isEmpty) return null;
    return lines[salt % lines.length];
  }

  static const List<BotPersonality> all = [
    BotPersonality(
      id: 'mango',
      name: 'Mango',
      avatar: '🐵',
      remarks: {
        GameEventType.ladder: ['Wheee, up I go!', 'Banana-powered climb!'],
        GameEventType.snake: ['Ouch! Sneaky snake.', 'Hey, that tickles!'],
        GameEventType.extraTurn: ['Six! Again, again!'],
        GameEventType.blocked: ['So close…'],
        GameEventType.won: ['Monkey business pays off!'],
      },
    ),
    BotPersonality(
      id: 'tembo',
      name: 'Tembo',
      avatar: '🐘',
      remarks: {
        GameEventType.ladder: ['Slow and steady… and up.', 'A ladder never forgets.'],
        GameEventType.snake: ['Hmph. I shall remember this.', 'Down we go.'],
        GameEventType.extraTurn: ['Another step forward.'],
        GameEventType.blocked: ['Patience.'],
        GameEventType.won: ['The herd wins.'],
      },
    ),
    BotPersonality(
      id: 'koko',
      name: 'Koko',
      avatar: '🦜',
      remarks: {
        GameEventType.ladder: ['Squawk! Top of the world!', 'Flying up!'],
        GameEventType.snake: ['Squawk?! Not fair!', 'Feathers everywhere!'],
        GameEventType.extraTurn: ['Six! Six! Six!'],
        GameEventType.blocked: ['Squawk… almost.'],
        GameEventType.won: ['Koko wins! Koko wins!'],
      },
    ),
  ];

  static BotPersonality? byId(String? id) {
    if (id == null) return null;
    for (final b in all) {
      if (b.id == id) return b;
    }
    return null;
  }
}
