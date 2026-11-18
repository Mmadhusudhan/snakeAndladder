import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/online_room.dart';
import '../data/services/local_room_service.dart';
import '../data/services/room_service.dart';
import '../features/game/engine/dice.dart';
import '../features/game/engine/game_engine.dart';
import '../features/game/models/board_config.dart';
import '../features/game/models/game_state.dart';
import '../features/game/models/player.dart';
import 'app_providers.dart';

/// Picks the real room service when Firebase and the backend are available,
/// otherwise an offline simulation so the online flow still works.
final roomServiceProvider = Provider<RoomService>((ref) {
  final status = ref.watch(firebaseStatusProvider).value;
  final api = ref.watch(apiClientProvider);
  final user = ref.watch(authStateProvider).value;
  if (status != null && status.available && api.isEnabled && user != null && !user.isOffline) {
    return ApiRoomService(api: api);
  }
  final profile = ref.watch(profileProvider).value;
  final local = LocalRoomService(
    uid: user?.uid ?? 'local',
    name: profile?.displayName ?? user?.fallbackName ?? 'You',
    avatar: profile?.avatar ?? '🦁',
    simulateOpponents: true,
  );
  ref.onDispose(local.dispose);
  return local;
});

/// The room the signed-in user is currently in, if any.
final myRoomIdProvider = StreamProvider<String?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(roomServiceProvider).watchMyRoomId(user.uid);
});

final roomProvider = StreamProvider.autoDispose.family<OnlineRoom?, String>((ref, roomId) {
  return ref.watch(roomServiceProvider).watchRoom(roomId);
});

/// What the online game screen renders.
class OnlineGameView {
  const OnlineGameView({
    this.room,
    this.game,
    this.mySeat,
    this.rollPending = false,
    this.replaying = false,
    this.error,
    this.secondsLeft = 0,
  });

  final OnlineRoom? room;

  /// Local engine state used for the board and animations.
  final GameState? game;
  final int? mySeat;

  /// A roll request is in flight (button disabled until the move arrives).
  final bool rollPending;

  /// Moves from the server are still being animated.
  final bool replaying;
  final String? error;
  final int secondsLeft;

  bool get isMyTurn => room?.state != null && mySeat != null && room!.state!.currentSeat == mySeat;

  /// The current player idled past the deadline; anyone may roll for them.
  bool get canRollForIdle =>
      room != null && room!.isPlaying && !isMyTurn && secondsLeft == 0 && game != null && game!.phase == GamePhase.waiting;

  bool get canRoll =>
      room != null && room!.isPlaying && game != null && game!.phase == GamePhase.waiting && !rollPending && !replaying && (isMyTurn || canRollForIdle);

  OnlineGameView copyWith({
    OnlineRoom? room,
    GameState? game,
    int? mySeat,
    bool? rollPending,
    bool? replaying,
    String? error,
    bool clearError = false,
    int? secondsLeft,
  }) {
    return OnlineGameView(
      room: room ?? this.room,
      game: game ?? this.game,
      mySeat: mySeat ?? this.mySeat,
      rollPending: rollPending ?? this.rollPending,
      replaying: replaying ?? this.replaying,
      error: clearError ? null : (error ?? this.error),
      secondsLeft: secondsLeft ?? this.secondsLeft,
    );
  }
}

/// Mirrors a server room into a local [GameEngine]: new server moves are
/// fed through a [ScriptedDice] so they animate exactly like local play, and
/// the board is re-synced from the server if anything ever disagrees.
class OnlineGameController extends Notifier<OnlineGameView> {
  OnlineGameController(this._roomId);

  final String _roomId;
  GameEngine? _engine;
  ScriptedDice? _dice;
  StreamSubscription<OnlineRoom?>? _roomSub;
  StreamSubscription<GameState>? _engineSub;
  Timer? _ticker;
  int _replayed = 0;
  bool _pumping = false;
  OnlineRoom? _latest;

  @override
  OnlineGameView build() {
    final roomId = _roomId;
    final service = ref.watch(roomServiceProvider);
    final user = ref.watch(authStateProvider).value;
    ref.onDispose(() {
      _roomSub?.cancel();
      _engineSub?.cancel();
      _ticker?.cancel();
      _engine?.dispose();
      if (user != null) unawaited(service.setPresence(roomId, user.uid, false));
    });
    if (user != null) unawaited(service.setPresence(roomId, user.uid, true));
    _roomSub = service.watchRoom(roomId).listen(_onRoom, onError: (Object e) {
      state = state.copyWith(error: '$e');
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    return const OnlineGameView();
  }

  EngineTimings get timings => _engine?.timings ?? const EngineTimings();
  BoardConfig get board => _engine?.rules.board ?? BoardConfig.classic;

  void _tick() {
    final st = state.room?.state;
    if (st == null) return;
    final left = st.timeLeft(DateTime.now()).inSeconds;
    if (left != state.secondsLeft) state = state.copyWith(secondsLeft: left);
  }

  void _onRoom(OnlineRoom? room) {
    final user = ref.read(authStateProvider).value;
    if (room == null) {
      state = state.copyWith(error: 'Room no longer exists');
      return;
    }
    _latest = room;
    final mySeat = user == null ? null : room.seatOf(user.uid)?.seat;
    state = state.copyWith(room: room, mySeat: mySeat, secondsLeft: room.state?.timeLeft(DateTime.now()).inSeconds ?? 0);
    if (room.state == null) return; // still in the lobby
    if (_engine == null) _createEngine(room);
    unawaited(_pump());
  }

  void _createEngine(OnlineRoom room) {
    final dice = ScriptedDice();
    final engine = GameEngine(
      players: [
        for (final s in room.seats)
          Player(id: s.uid, name: s.name, avatar: s.avatar, colorIndex: s.colorIndex, forfeited: s.forfeited),
      ],
      rulesConfig: room.rules,
      dice: dice,
      autoPlayComputer: false,
    );
    _dice = dice;
    _engine = engine;
    _engineSub = engine.stream.listen((g) => state = state.copyWith(game: g));
    final st = room.state!;
    engine.loadSnapshot(
      positions: [for (final s in room.seats) st.positions[s.seat] ?? 0],
      currentPlayerIndex: st.currentSeat,
      turnNumber: st.turn,
      consecutiveSixes: st.consecutiveSixes,
      lastRoll: st.lastRoll,
      forfeited: [for (final s in room.seats) s.forfeited],
      winnerIndex: room.effectiveWinnerSeat,
    );
    _replayed = st.moveCount;
    state = state.copyWith(game: engine.state);
  }

  /// Replays any moves the server has that we have not animated yet.
  Future<void> _pump() async {
    if (_pumping) return;
    final engine = _engine;
    final dice = _dice;
    if (engine == null || dice == null) return;
    _pumping = true;
    try {
      while (true) {
        final room = _latest;
        if (room == null) break;
        final pending = room.moves.where((m) => m.n >= _replayed).toList();
        if (pending.isEmpty) break;
        state = state.copyWith(replaying: true, rollPending: false);
        final move = pending.first;
        if (engine.state.currentPlayerIndex != move.seat || engine.state.phase != GamePhase.waiting) {
          _resync(room);
          break;
        }
        dice.enqueue(move.roll);
        await engine.rollDice();
        _replayed = move.n + 1;
        if (engine.isDisposed) return;
        // The local rules must agree with the server; if not, trust the server.
        final mine = engine.state.players[move.seat].position;
        if (mine != move.to) _resync(room);
      }
      final room = _latest;
      if (room != null && !engine.isDisposed) _syncMeta(room);
    } finally {
      _pumping = false;
      if (!(_engine?.isDisposed ?? true)) state = state.copyWith(replaying: false);
    }
  }

  void _resync(OnlineRoom room) {
    final st = room.state;
    final engine = _engine;
    if (st == null || engine == null) return;
    engine.loadSnapshot(
      positions: [for (final s in room.seats) st.positions[s.seat] ?? 0],
      currentPlayerIndex: st.currentSeat,
      turnNumber: st.turn,
      consecutiveSixes: st.consecutiveSixes,
      lastRoll: st.lastRoll,
      forfeited: [for (final s in room.seats) s.forfeited],
      winnerIndex: room.effectiveWinnerSeat,
    );
    _replayed = st.moveCount;
  }

  /// Applies forfeits and early endings that do not come as moves.
  void _syncMeta(OnlineRoom room) {
    final engine = _engine!;
    for (final s in room.seats) {
      if (s.forfeited && !engine.state.players[s.seat].forfeited) engine.setForfeited(s.seat);
    }
    final winner = room.effectiveWinnerSeat;
    if (room.isFinished && winner != null && !engine.state.isCompleted) engine.declareWinner(winner);
    if (room.isPlaying && engine.state.phase == GamePhase.waiting && engine.state.currentPlayerIndex != room.state!.currentSeat) {
      _resync(room);
    }
  }

  Future<void> roll() async {
    if (!state.canRoll) return;
    state = state.copyWith(rollPending: true, clearError: true);
    try {
      await ref.read(roomServiceProvider).roll(_roomId);
    } catch (e) {
      state = state.copyWith(rollPending: false, error: _describe(e));
    }
  }

  Future<void> leave() async {
    try {
      await ref.read(roomServiceProvider).leaveRoom(_roomId);
    } catch (e) {
      debugPrint('leave failed: $e');
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  static String _describe(Object e) {
    final s = '$e';
    return s.replaceFirst(RegExp(r'^(ApiException|StateError|Bad state): ?'), '').replaceFirst(RegExp(r'^API \d+: '), '');
  }
}

final onlineGameProvider =
    NotifierProvider.autoDispose.family<OnlineGameController, OnlineGameView, String>(OnlineGameController.new);
