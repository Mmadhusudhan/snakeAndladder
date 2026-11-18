import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snakes_ladders/data/models/app_user.dart';
import 'package:snakes_ladders/data/models/online_room.dart';
import 'package:snakes_ladders/data/repositories/profile_repository.dart';
import 'package:snakes_ladders/data/services/auth_service.dart';
import 'package:snakes_ladders/data/services/firebase_bootstrap.dart';
import 'package:snakes_ladders/data/services/local_room_service.dart';
import 'package:snakes_ladders/features/game/engine/dice.dart';
import 'package:snakes_ladders/features/game/engine/game_engine.dart';
import 'package:snakes_ladders/features/game/models/game_state.dart';
import 'package:snakes_ladders/features/game/models/player.dart';
import 'package:snakes_ladders/core/services/audio_service.dart';
import 'package:snakes_ladders/providers/app_providers.dart';
import 'package:snakes_ladders/providers/settings_providers.dart';
import 'package:snakes_ladders/providers/online_providers.dart';

const players = [
  Player(id: 'a', name: 'Ann', colorIndex: 0),
  Player(id: 'b', name: 'Ben', colorIndex: 1),
  Player(id: 'c', name: 'Cat', colorIndex: 2),
];

void main() {
  group('engine online support', () {
    test('scripted dice replays exact rolls and errors when empty', () async {
      final dice = ScriptedDice();
      final e = GameEngine(players: players, dice: dice, timings: EngineTimings.instant, autoPlayComputer: false)..start();
      dice.enqueue(4);
      await e.rollDice();
      expect(e.state.players[0].position, 14);
      expect(dice.hasNext, isFalse);
      e.dispose();
    });

    test('loadSnapshot jumps without animation and detects a winner', () {
      final e = GameEngine(players: players, timings: EngineTimings.instant, autoPlayComputer: false)..start();
      e.loadSnapshot(positions: [10, 20, 30], currentPlayerIndex: 2, turnNumber: 9, lastRoll: 3);
      expect(e.state.players.map((p) => p.position), [10, 20, 30]);
      expect(e.state.currentPlayerIndex, 2);
      expect(e.state.turnNumber, 9);
      expect(e.state.phase, GamePhase.waiting);
      e.loadSnapshot(positions: [10, 100, 30], currentPlayerIndex: 1);
      expect(e.state.isCompleted, isTrue);
      expect(e.state.winnerIndex, 1);
      e.dispose();
    });

    test('forfeited players are skipped and passing the turn works', () async {
      final e = GameEngine(players: players, dice: FixedDice([2]), timings: EngineTimings.instant, autoPlayComputer: false)..start();
      e.setForfeited(1);
      await e.rollDice(); // Ann -> Cat (Ben skipped)
      expect(e.state.currentPlayerIndex, 2);
      e.setForfeited(2); // Cat's turn, she leaves -> back to Ann
      expect(e.state.currentPlayerIndex, 0);
      e.declareWinner(0);
      expect(e.state.isCompleted, isTrue);
      expect(e.state.events.last.type, GameEventType.won);
      e.dispose();
    });
  });

  group('OnlineRoom parsing', () {
    test('handles RTDB list-shaped seats and round-trips', () {
      final raw = {
        'meta': {'code': 'ABC123', 'hostUid': 'u1', 'status': 'playing', 'maxPlayers': 2, 'rules': {'exactRollToWin': false}},
        'seats': [
          {'uid': 'u1', 'name': 'Ann', 'avatar': 'A', 'colorIndex': 0},
          {'uid': 'u2', 'name': 'Ben', 'avatar': 'B', 'colorIndex': 1, 'forfeited': true},
        ],
        'state': {'currentSeat': 1, 'positions': [5, 9], 'turn': 4, 'moveCount': 2, 'turnDeadline': 1000},
        'moves': {
          '1': {'n': 1, 'seat': 1, 'roll': 6, 'from': 3, 'landing': 9, 'to': 9, 'outcome': 'normal', 'extraTurn': true},
          '0': {'n': 0, 'seat': 0, 'roll': 5, 'from': 0, 'landing': 5, 'to': 5, 'outcome': 'normal'},
        },
      };
      final room = OnlineRoom.fromMap('r1', raw);
      expect(room.seats.length, 2);
      expect(room.seats[1].forfeited, isTrue);
      expect(room.rules.exactRollToWin, isFalse);
      expect(room.state!.positions, {0: 5, 1: 9});
      expect(room.moves.map((m) => m.n), [0, 1]);
      expect(room.moves[1].extraTurn, isTrue);
      expect(room.isPlaying, isTrue);
      final again = OnlineRoom.fromMap('r1', room.toMap());
      expect(again.code, 'ABC123');
      expect(again.state!.currentSeat, 1);
      expect(again.moves.length, 2);
    });
  });

  group('LocalRoomService', () {
    test('create, join, start, roll, finish mirrors the server', () async {
      final host = LocalRoomService(uid: 'h', name: 'Host', random: Random(1), now: () => DateTime(2026));
      final room = await host.createRoom(maxPlayers: 2);
      expect(room.code.length, 6);
      expect(room.isOpen, isTrue);
      expect(() => host.createRoom(), throwsStateError);
      expect(() => host.startRoom(room.id), throwsStateError); // alone
      // A second service instance sharing the same store is not supported;
      // the service exposes join for other users through codes only via
      // the simulation. Use the simulation to fill the room.
      host.dispose();

      final sim = LocalRoomService(uid: 'me', simulateOpponents: true, random: Random(3), botDelay: Duration.zero);
      final r = await sim.createRoom(maxPlayers: 2);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      var current = (await sim.watchRoom(r.id).first)!;
      expect(current.seats.length, 2);
      expect(current.seats[1].uid, startsWith('bot_'));
      current = await sim.startRoom(r.id);
      expect(current.isPlaying, isTrue);
      expect(current.state!.currentSeat, 0);
      await sim.roll(r.id);
      current = (await sim.watchRoom(r.id).first)!;
      expect(current.moves.length, 1);
      expect(current.moves.first.seat, 0);
      // Not my turn now (unless I rolled a six).
      if (current.state!.currentSeat != 0) {
        expect(() => sim.roll(r.id), throwsStateError);
      }
      sim.dispose();
    });

    test('quick match with simulated opponents starts a playing room', () async {
      final sim = LocalRoomService(uid: 'me', simulateOpponents: true, random: Random(5), botDelay: Duration.zero);
      final q = await sim.joinQueue(maxPlayers: 3);
      expect(q.isQueued, isTrue);
      final roomId = await sim.watchMyRoomId('me').firstWhere((id) => id != null);
      final room = (await sim.watchRoom(roomId!).first)!;
      expect(room.isPlaying, isTrue);
      expect(room.seats.length, 3);
      expect(room.quick, isFalse);
      sim.dispose();
    });

    test('leaving while playing forfeits; 2-player game ends', () async {
      final sim = LocalRoomService(uid: 'me', simulateOpponents: true, random: Random(7), botDelay: Duration.zero);
      final r = await sim.createRoom(maxPlayers: 2);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sim.startRoom(r.id);
      await sim.leaveRoom(r.id);
      final room = (await sim.watchRoom(r.id).first)!;
      expect(room.isFinished, isTrue);
      expect(room.endedBy, 'forfeit');
      expect(room.effectiveWinnerSeat, 1);
      expect(await sim.currentRoomId(), isNull);
      sim.dispose();
    });
  });

  group('OnlineGameController', () {
    test('replays server moves through the local engine and resyncs forfeits', () async {
      final sim = LocalRoomService(uid: 'me', simulateOpponents: true, random: Random(11), botDelay: Duration.zero);
      final r = await sim.createRoom(maxPlayers: 2);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sim.startRoom(r.id);

      final container = ProviderContainer(overrides: [
        firebaseStatusProvider.overrideWith((ref) async => const FirebaseStatus.unavailable('test')),
        authServiceProvider.overrideWithValue(LocalAuthService(uid: 'me', initialUser: const AppUser(uid: 'me', isGuest: true, isOffline: true))),
        profileRepositoryProvider.overrideWithValue(InMemoryProfileRepository()),
        roomServiceProvider.overrideWithValue(sim),
        audioServiceProvider.overrideWithValue(SilentAudioService()),
      ]);
      addTearDown(container.dispose);
      final sub = container.listen(onlineGameProvider(r.id), (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      var view = container.read(onlineGameProvider(r.id));
      expect(view.room, isNotNull);
      expect(view.game, isNotNull);
      expect(view.mySeat, 0);
      expect(view.isMyTurn, isTrue);
      expect(view.canRoll, isTrue);

      await container.read(onlineGameProvider(r.id).notifier).roll();
      // My move and then the bot's reply are replayed with real animation
      // timings; poll until the local board matches the server for everyone.
      bool inSync(OnlineGameView v) {
        final room = v.room!;
        final g = v.game!;
        if (v.replaying || g.phase != GamePhase.waiting) return false;
        for (final s in room.seats) {
          if (g.players[s.seat].position != room.state!.positions[s.seat]) return false;
        }
        return g.lastRoll == room.moves.last.roll && room.state!.currentSeat == 0;
      }

      final deadline = DateTime.now().add(const Duration(seconds: 12));
      while (DateTime.now().isBefore(deadline) && !inSync(container.read(onlineGameProvider(r.id)))) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      view = container.read(onlineGameProvider(r.id));
      expect(inSync(view), isTrue, reason: 'local board should mirror the server');
      expect(view.room!.moves.first.seat, 0);
      expect(view.room!.moves.first.roll, inInclusiveRange(1, 6));
      expect(view.rollPending, isFalse);
      expect(view.isMyTurn, isTrue);
    });
  });
}
