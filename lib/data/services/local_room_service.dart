import 'dart:async';
import 'dart:math';

import '../../features/game/engine/game_rules.dart';
import '../../features/game/models/game_rules_config.dart';
import '../models/online_room.dart';
import 'room_service.dart';

/// A faithful in-process copy of the server's room logic, for tests and for
/// an offline "simulated online" mode. With [simulateOpponents] a bot joins
/// your room / queue and rolls on its turn, so the whole online flow can be
/// exercised without a backend.
class LocalRoomService implements RoomService {
  LocalRoomService({
    required this.uid,
    this.name = 'You',
    this.avatar = '🦁',
    this.simulateOpponents = false,
    Random? random,
    this.turnSeconds = 30,
    this.botDelay = const Duration(milliseconds: 1200),
    DateTime Function()? now,
  })  : _rng = random ?? Random(),
        _now = now ?? DateTime.now;

  final String uid;
  final String name;
  final String avatar;
  final bool simulateOpponents;
  final int turnSeconds;
  final Duration botDelay;
  final Random _rng;
  final DateTime Function() _now;

  final Map<String, OnlineRoom> _rooms = {};
  final Map<String, String> _codes = {};
  final Map<String, String?> _userRooms = {};
  final _roomChanges = StreamController<String>.broadcast();
  final _userRoomChanges = StreamController<String>.broadcast();
  final List<Timer> _timers = [];
  bool _queued = false;
  int _botCounter = 0;

  static const _bots = [('Mango', '🐵'), ('Tembo', '🐘'), ('Koko', '🦜')];

  @override
  String? get modeNote => simulateOpponents ? 'Offline simulation: opponents are bots on this device.' : null;

  Map<String, OnlineRoom> get rooms => Map.unmodifiable(_rooms);

  OnlineRoom _require(String id) {
    final r = _rooms[id];
    if (r == null) throw StateError('Room not found');
    return r;
  }

  void _put(OnlineRoom room) {
    _rooms[room.id] = room;
    _roomChanges.add(room.id);
  }

  void _setUserRoom(String user, String? roomId) {
    _userRooms[user] = roomId;
    _userRoomChanges.add(user);
  }

  String _newCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => alphabet[_rng.nextInt(alphabet.length)]).join();
  }

  int _deadline() => _now().millisecondsSinceEpoch + turnSeconds * 1000;

  // --- public API -----------------------------------------------------------

  @override
  Future<OnlineRoom> createRoom({int maxPlayers = 2, GameRulesConfig? rules}) async {
    final existing = _userRooms[uid];
    if (existing != null && (_rooms[existing]?.isOpen == true || _rooms[existing]?.isPlaying == true)) {
      throw StateError('You are already in a room');
    }
    final id = 'local_${_now().millisecondsSinceEpoch.toRadixString(36)}_${_rng.nextInt(1 << 20)}';
    final room = OnlineRoom(
      id: id,
      code: _newCode(),
      hostUid: uid,
      status: RoomStatus.open,
      maxPlayers: maxPlayers.clamp(2, 4),
      rules: rules ?? GameRulesConfig.classic,
      seats: [OnlineSeat(seat: 0, uid: uid, name: name, avatar: avatar, colorIndex: 0)],
    );
    _codes[room.code] = id;
    _put(room);
    _setUserRoom(uid, id);
    if (simulateOpponents) _later(botDelay, () => _botJoin(id));
    return room;
  }

  @override
  Future<OnlineRoom> joinByCode(String code) async {
    final id = _codes[code.trim().toUpperCase()];
    if (id == null) throw StateError('No room with that code');
    return _join(id, uid, name, avatar);
  }

  OnlineRoom _join(String id, String user, String userName, String userAvatar) {
    var room = _require(id);
    if (room.seatOf(user) != null) return room;
    if (!room.isOpen) throw StateError('Game already started');
    if (room.isFull) throw StateError('Room is full');
    var seat = 0;
    while (room.seatAt(seat) != null) {
      seat++;
    }
    room = room.copyWith(seats: [
      ...room.seats,
      OnlineSeat(seat: seat, uid: user, name: userName, avatar: userAvatar, colorIndex: seat),
    ]..sort((a, b) => a.seat.compareTo(b.seat)));
    _put(room);
    _setUserRoom(user, id);
    return room;
  }

  @override
  Future<OnlineRoom> startRoom(String roomId) async {
    var room = _require(roomId);
    if (!room.isHost(uid)) throw StateError('Only the host can start');
    if (!room.canStart) throw StateError('Need at least 2 players');
    room = _start(room);
    _put(room);
    _scheduleBot(room.id);
    return room;
  }

  OnlineRoom _start(OnlineRoom room) {
    final seats = [
      for (final (i, s) in room.seats.indexed)
        OnlineSeat(seat: i, uid: s.uid, name: s.name, avatar: s.avatar, colorIndex: i),
    ];
    return room.copyWith(
      status: RoomStatus.playing,
      seats: seats,
      state: OnlineState(
        currentSeat: 0,
        positions: {for (final s in seats) s.seat: 0},
        turnDeadlineMs: _deadline(),
      ),
    );
  }

  @override
  Future<void> roll(String roomId) async => _roll(roomId, uid);

  void _roll(String roomId, String actor) {
    var room = _require(roomId);
    if (!room.isPlaying) throw StateError('Game is not in progress');
    final mine = room.seatOf(actor);
    if (mine == null) throw StateError('You are not in this room');
    final st = room.state!;
    final auto = mine.seat != st.currentSeat;
    if (auto && _now().millisecondsSinceEpoch < st.turnDeadlineMs) throw StateError('Not your turn');

    final rules = GameRules(config: room.rules);
    final seat = st.currentSeat;
    final roll = _rng.nextInt(6) + 1;
    final sixes = roll == 6 ? st.consecutiveSixes + 1 : 0;
    final positions = Map<int, int>.of(st.positions);
    final n = st.moveCount;
    OnlineMove move;
    OnlineState next;
    var status = room.status;
    int? winnerSeat;
    if (rules.forfeitsTurn(sixes)) {
      move = OnlineMove(n: n, seat: seat, roll: roll, from: positions[seat]!, landing: positions[seat]!, to: positions[seat]!, outcome: 'blocked', forfeit: true, auto: auto);
      next = OnlineState(currentSeat: _nextActive(room, seat), positions: positions, lastRoll: roll, turn: st.turn + 1, moveCount: n + 1, turnDeadlineMs: _deadline());
    } else {
      final res = rules.resolve(from: positions[seat]!, roll: roll);
      positions[seat] = res.finalPosition;
      move = OnlineMove(n: n, seat: seat, roll: roll, from: res.from, landing: res.landing, to: res.finalPosition, outcome: res.outcome.name, extraTurn: res.outcome != MoveOutcome.win && rules.grantsExtraTurn(roll), auto: auto);
      if (res.outcome == MoveOutcome.win) {
        status = RoomStatus.finished;
        winnerSeat = seat;
        next = OnlineState(currentSeat: seat, positions: positions, phase: 'finished', lastRoll: roll, turn: st.turn, winnerSeat: seat, moveCount: n + 1, turnDeadlineMs: st.turnDeadlineMs);
      } else {
        final extra = rules.grantsExtraTurn(roll);
        next = OnlineState(
          currentSeat: extra ? seat : _nextActive(room, seat),
          positions: positions,
          lastRoll: roll,
          turn: st.turn + 1,
          consecutiveSixes: extra ? sixes : 0,
          moveCount: n + 1,
          turnDeadlineMs: _deadline(),
        );
      }
    }
    room = room.copyWith(status: status, state: next, moves: [...room.moves, move], winnerSeat: winnerSeat);
    _put(room);
    if (room.isFinished) {
      _release(room);
    } else {
      _scheduleBot(room.id);
    }
  }

  int _nextActive(OnlineRoom room, int from) {
    final n = room.seats.length;
    for (var i = 1; i <= n; i++) {
      final cand = (from + i) % n;
      final s = room.seatAt(cand);
      if (s != null && !s.forfeited) return cand;
    }
    return from;
  }

  @override
  Future<void> leaveRoom(String roomId) async {
    var room = _rooms[roomId];
    if (room == null) return;
    final mine = room.seatOf(uid);
    if (mine == null) return;
    if (room.isOpen) {
      final seats = room.seats.where((s) => s.uid != uid).toList();
      if (seats.isEmpty) {
        room = room.copyWith(status: RoomStatus.closed, seats: const []);
        _codes.remove(room.code);
      } else {
        room = room.copyWith(seats: seats, hostUid: room.hostUid == uid ? seats.first.uid : room.hostUid);
      }
    } else if (room.isPlaying) {
      final seats = [for (final s in room.seats) s.uid == uid ? OnlineSeat(seat: s.seat, uid: s.uid, name: s.name, avatar: s.avatar, colorIndex: s.colorIndex, forfeited: true) : s];
      room = room.copyWith(seats: seats);
      final active = seats.where((s) => !s.forfeited).toList();
      if (active.length <= 1) {
        final winner = active.isEmpty ? null : active.first.seat;
        room = room.copyWith(
          status: RoomStatus.finished,
          winnerSeat: winner,
          endedBy: 'forfeit',
          state: OnlineState(
            currentSeat: room.state!.currentSeat,
            positions: room.state!.positions,
            phase: 'finished',
            lastRoll: room.state!.lastRoll,
            turn: room.state!.turn,
            winnerSeat: winner,
            moveCount: room.state!.moveCount,
            turnDeadlineMs: room.state!.turnDeadlineMs,
          ),
        );
      } else if (room.state!.currentSeat == mine.seat) {
        final st = room.state!;
        room = room.copyWith(
          state: OnlineState(
            currentSeat: _nextActive(room, mine.seat),
            positions: st.positions,
            lastRoll: st.lastRoll,
            turn: st.turn,
            moveCount: st.moveCount,
            turnDeadlineMs: _deadline(),
          ),
        );
      }
    }
    _put(room);
    _setUserRoom(uid, null);
    if (room.isFinished) _release(room);
  }

  void _release(OnlineRoom room) {
    for (final s in room.seats) {
      _setUserRoom(s.uid, null);
    }
    _codes.remove(room.code);
  }

  @override
  Future<QuickMatchResult> joinQueue({int maxPlayers = 2}) async {
    final existing = _userRooms[uid];
    if (existing != null && (_rooms[existing]?.isOpen == true || _rooms[existing]?.isPlaying == true)) {
      return QuickMatchResult(status: 'in_room', roomId: existing);
    }
    _queued = true;
    if (simulateOpponents) {
      _later(botDelay, () async {
        if (!_queued) return;
        _queued = false;
        final room = await createRoom(maxPlayers: maxPlayers);
        var r = room;
        for (var i = 1; i < maxPlayers; i++) {
          final (bn, ba) = _bots[(_botCounter++) % _bots.length];
          r = _join(room.id, 'bot_$bn$i', bn, ba);
        }
        _put(_start(r));
        _scheduleBot(room.id);
      });
    }
    return const QuickMatchResult(status: 'queued');
  }

  @override
  Future<void> leaveQueue() async => _queued = false;

  @override
  Future<String?> currentRoomId() async => _userRooms[uid];

  @override
  Stream<OnlineRoom?> watchRoom(String roomId) async* {
    yield _rooms[roomId];
    yield* _roomChanges.stream.where((id) => id == roomId).map((id) => _rooms[id]);
  }

  @override
  Stream<String?> watchMyRoomId(String user) async* {
    yield _userRooms[user];
    yield* _userRoomChanges.stream.where((u) => u == user).map((u) => _userRooms[u]);
  }

  @override
  Future<void> setPresence(String roomId, String uid, bool online) async {}

  // --- simulated opponents -------------------------------------------------

  void _botJoin(String roomId) {
    final room = _rooms[roomId];
    if (room == null || !room.isOpen || room.isFull) return;
    final (bn, ba) = _bots[(_botCounter++) % _bots.length];
    _join(roomId, 'bot_$bn${room.seats.length}', bn, ba);
  }

  void _scheduleBot(String roomId) {
    if (!simulateOpponents) return;
    final room = _rooms[roomId];
    if (room == null || !room.isPlaying) return;
    final current = room.seatAt(room.state!.currentSeat);
    if (current == null || !current.uid.startsWith('bot_')) return;
    _later(botDelay * 2, () {
      final r = _rooms[roomId];
      if (r == null || !r.isPlaying || r.state!.currentSeat != current.seat) return;
      _roll(roomId, current.uid);
    });
  }

  void _later(Duration d, FutureOr<void> Function() f) {
    _timers.add(Timer(d, () => f()));
  }

  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _roomChanges.close();
    _userRoomChanges.close();
  }
}
