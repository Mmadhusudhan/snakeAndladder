import '../../features/game/models/game_rules_config.dart';

enum RoomStatus { open, playing, finished, closed }

/// Deep-converts Realtime Database maps (which arrive as `Map<Object?, Object?>`
/// and sometimes as `List` when keys are 0..n) into `Map<String, dynamic>`.
Map<String, dynamic> asStringMap(Object? v) {
  if (v is Map) return {for (final e in v.entries) '${e.key}': e.value};
  if (v is List) return {for (var i = 0; i < v.length; i++) if (v[i] != null) '$i': v[i]};
  return const {};
}

int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? fallback : fallback);

class OnlineSeat {
  const OnlineSeat({
    required this.seat,
    required this.uid,
    required this.name,
    required this.avatar,
    required this.colorIndex,
    this.forfeited = false,
  });

  final int seat;
  final String uid;
  final String name;
  final String avatar;
  final int colorIndex;
  final bool forfeited;

  factory OnlineSeat.fromMap(int seat, Map<String, dynamic> m) => OnlineSeat(
        seat: seat,
        uid: '${m['uid']}',
        name: (m['name'] as String?) ?? 'Player',
        avatar: (m['avatar'] as String?) ?? '🙂',
        colorIndex: _int(m['colorIndex'], seat),
        forfeited: m['forfeited'] == true,
      );

  Map<String, dynamic> toMap() =>
      {'uid': uid, 'name': name, 'avatar': avatar, 'colorIndex': colorIndex, 'forfeited': forfeited};
}

/// One server-decided move, replayed by clients for the animation.
class OnlineMove {
  const OnlineMove({
    required this.n,
    required this.seat,
    required this.roll,
    required this.from,
    required this.landing,
    required this.to,
    required this.outcome,
    this.extraTurn = false,
    this.forfeit = false,
    this.auto = false,
  });

  final int n;
  final int seat;
  final int roll;
  final int from;
  final int landing;
  final int to;

  /// normal | blocked | snake | ladder | win
  final String outcome;
  final bool extraTurn;

  /// Three sixes: the roll was wasted.
  final bool forfeit;

  /// Rolled by someone else because the player idled past the deadline.
  final bool auto;

  factory OnlineMove.fromMap(Map<String, dynamic> m) => OnlineMove(
        n: _int(m['n']),
        seat: _int(m['seat']),
        roll: _int(m['roll'], 1),
        from: _int(m['from']),
        landing: _int(m['landing']),
        to: _int(m['to']),
        outcome: (m['outcome'] as String?) ?? 'normal',
        extraTurn: m['extraTurn'] == true,
        forfeit: m['forfeit'] == true,
        auto: m['auto'] == true,
      );

  Map<String, dynamic> toMap() => {
        'n': n, 'seat': seat, 'roll': roll, 'from': from, 'landing': landing, 'to': to,
        'outcome': outcome, 'extraTurn': extraTurn, 'forfeit': forfeit, 'auto': auto,
      };
}

class OnlineState {
  const OnlineState({
    required this.currentSeat,
    required this.positions,
    this.phase = 'waiting',
    this.lastRoll,
    this.turn = 1,
    this.consecutiveSixes = 0,
    this.winnerSeat,
    this.moveCount = 0,
    this.turnDeadlineMs = 0,
  });

  final int currentSeat;
  final Map<int, int> positions;
  final String phase;
  final int? lastRoll;
  final int turn;
  final int consecutiveSixes;
  final int? winnerSeat;
  final int moveCount;
  final int turnDeadlineMs;

  bool get isFinished => phase == 'finished';

  Duration timeLeft(DateTime now) {
    final ms = turnDeadlineMs - now.millisecondsSinceEpoch;
    return ms <= 0 ? Duration.zero : Duration(milliseconds: ms);
  }

  factory OnlineState.fromMap(Map<String, dynamic> m) => OnlineState(
        currentSeat: _int(m['currentSeat']),
        positions: {for (final e in asStringMap(m['positions']).entries) _int(e.key): _int(e.value)},
        phase: (m['phase'] as String?) ?? 'waiting',
        lastRoll: m['lastRoll'] == null ? null : _int(m['lastRoll']),
        turn: _int(m['turn'], 1),
        consecutiveSixes: _int(m['consecutiveSixes']),
        winnerSeat: m['winnerSeat'] == null ? null : _int(m['winnerSeat']),
        moveCount: _int(m['moveCount']),
        turnDeadlineMs: _int(m['turnDeadline']),
      );

  Map<String, dynamic> toMap() => {
        'currentSeat': currentSeat,
        'positions': {for (final e in positions.entries) '${e.key}': e.value},
        'phase': phase,
        'lastRoll': lastRoll,
        'turn': turn,
        'consecutiveSixes': consecutiveSixes,
        'winnerSeat': winnerSeat,
        'moveCount': moveCount,
        'turnDeadline': turnDeadlineMs,
      };
}

/// A room as mirrored from `rooms/{id}` in Realtime Database.
class OnlineRoom {
  const OnlineRoom({
    required this.id,
    required this.code,
    required this.hostUid,
    required this.status,
    required this.maxPlayers,
    required this.rules,
    required this.seats,
    this.state,
    this.moves = const [],
    this.quick = false,
    this.winnerSeat,
    this.endedBy,
  });

  final String id;
  final String code;
  final String hostUid;
  final RoomStatus status;
  final int maxPlayers;
  final GameRulesConfig rules;
  final List<OnlineSeat> seats;
  final OnlineState? state;

  /// Sorted by `n`.
  final List<OnlineMove> moves;
  final bool quick;
  final int? winnerSeat;
  final String? endedBy;

  bool get isOpen => status == RoomStatus.open;
  bool get isPlaying => status == RoomStatus.playing;
  bool get isFinished => status == RoomStatus.finished;
  bool get isFull => seats.length >= maxPlayers;
  bool isHost(String uid) => hostUid == uid;
  bool get canStart => isOpen && seats.length >= 2;

  OnlineSeat? seatOf(String uid) {
    for (final s in seats) {
      if (s.uid == uid) return s;
    }
    return null;
  }

  OnlineSeat? seatAt(int seat) {
    for (final s in seats) {
      if (s.seat == seat) return s;
    }
    return null;
  }

  int? get effectiveWinnerSeat => winnerSeat ?? state?.winnerSeat;

  factory OnlineRoom.fromMap(String id, Object? raw) {
    final m = asStringMap(raw);
    final meta = asStringMap(m['meta']);
    final rulesMap = asStringMap(meta['rules']);
    final seats = [
      for (final e in asStringMap(m['seats']).entries)
        OnlineSeat.fromMap(_int(e.key), asStringMap(e.value)),
    ]..sort((a, b) => a.seat.compareTo(b.seat));
    final moves = [
      for (final e in asStringMap(m['moves']).entries) OnlineMove.fromMap(asStringMap(e.value)),
    ]..sort((a, b) => a.n.compareTo(b.n));
    final statusName = (meta['status'] as String?) ?? 'open';
    return OnlineRoom(
      id: id,
      code: (meta['code'] as String?) ?? '',
      hostUid: '${meta['hostUid'] ?? ''}',
      status: RoomStatus.values.firstWhere((s) => s.name == statusName, orElse: () => RoomStatus.closed),
      maxPlayers: _int(meta['maxPlayers'], 2),
      rules: GameRulesConfig(
        exactRollToWin: rulesMap['exactRollToWin'] != false,
        extraTurnOnSix: rulesMap['extraTurnOnSix'] != false,
        needSixToStart: rulesMap['needSixToStart'] == true,
        maxConsecutiveSixes: _int(rulesMap['maxConsecutiveSixes'], 3),
      ),
      seats: seats,
      state: m['state'] == null ? null : OnlineState.fromMap(asStringMap(m['state'])),
      moves: moves,
      quick: meta['quick'] == true,
      winnerSeat: meta['winnerSeat'] == null ? null : _int(meta['winnerSeat']),
      endedBy: meta['endedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'meta': {
          'code': code,
          'hostUid': hostUid,
          'status': status.name,
          'maxPlayers': maxPlayers,
          'quick': quick,
          'winnerSeat': winnerSeat,
          'endedBy': endedBy,
          'rules': {
            'exactRollToWin': rules.exactRollToWin,
            'extraTurnOnSix': rules.extraTurnOnSix,
            'needSixToStart': rules.needSixToStart,
            'maxConsecutiveSixes': rules.maxConsecutiveSixes,
            'diceSides': rules.diceSides,
          },
        },
        'seats': {for (final s in seats) '${s.seat}': s.toMap()},
        if (state != null) 'state': state!.toMap(),
        'moves': {for (final mv in moves) '${mv.n}': mv.toMap()},
      };

  OnlineRoom copyWith({
    String? hostUid,
    RoomStatus? status,
    List<OnlineSeat>? seats,
    OnlineState? state,
    List<OnlineMove>? moves,
    int? winnerSeat,
    String? endedBy,
  }) {
    return OnlineRoom(
      id: id,
      code: code,
      hostUid: hostUid ?? this.hostUid,
      status: status ?? this.status,
      maxPlayers: maxPlayers,
      rules: rules,
      seats: seats ?? this.seats,
      state: state ?? this.state,
      moves: moves ?? this.moves,
      quick: quick,
      winnerSeat: winnerSeat ?? this.winnerSeat,
      endedBy: endedBy ?? this.endedBy,
    );
  }
}

/// Result of asking for a random opponent.
class QuickMatchResult {
  const QuickMatchResult({required this.status, this.roomId});

  /// queued | matched | in_room
  final String status;
  final String? roomId;

  bool get isQueued => status == 'queued';
}
