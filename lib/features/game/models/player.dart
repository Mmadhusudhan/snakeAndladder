import '../../../core/constants/board_constants.dart';
import 'bot_personality.dart';

/// Who controls a player.
enum PlayerType { human, computer }

/// A participant in a game.
class Player {
  const Player({
    required this.id,
    required this.name,
    required this.colorIndex,
    this.type = PlayerType.human,
    this.avatar = '🙂',
    this.position = BoardConstants.startCell,
    this.level,
    this.botId,
    this.forfeited = false,
  });

  final String id;
  final String name;
  final PlayerType type;

  /// Index into the player colour palette (0..3).
  final int colorIndex;

  /// Emoji avatar shown on the token.
  final String avatar;

  /// Current cell (0 = not yet on the board).
  final int position;

  /// Strength of a computer player (ignored for humans).
  final ComputerLevel? level;

  /// Which [BotPersonality] this computer player uses, if any.
  final String? botId;

  BotPersonality? get personality => BotPersonality.byId(botId);

  /// Left an online game; their turns are skipped.
  final bool forfeited;

  bool get isComputer => type == PlayerType.computer;

  /// "Ann's" or "Your", for sentences such as "Your turn".
  String get possessive => name.trim().toLowerCase() == 'you' ? 'Your' : "$name's";
  bool get hasStarted => position > BoardConstants.startCell;

  Player copyWith({
    String? name,
    PlayerType? type,
    int? colorIndex,
    String? avatar,
    int? position,
    ComputerLevel? level,
    String? botId,
    bool? forfeited,
  }) {
    return Player(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      colorIndex: colorIndex ?? this.colorIndex,
      avatar: avatar ?? this.avatar,
      position: position ?? this.position,
      level: level ?? this.level,
      botId: botId ?? this.botId,
      forfeited: forfeited ?? this.forfeited,
    );
  }

  @override
  String toString() => 'Player($name @ $position)';
}
