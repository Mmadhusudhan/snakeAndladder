import 'package:firebase_database/firebase_database.dart';

import '../../features/game/models/game_rules_config.dart';
import '../models/online_room.dart';
import 'api_client.dart';

/// Online room boundary. Actions go to the backend (which owns the dice and
/// validates turns); room state is observed live from Realtime Database.
abstract class RoomService {
  Future<OnlineRoom> createRoom({int maxPlayers = 2, GameRulesConfig? rules});
  Future<OnlineRoom> joinByCode(String code);
  Future<OnlineRoom> startRoom(String roomId);

  /// Asks the server to roll for the current seat (yours, or an idle
  /// player's once their deadline passed). The move arrives via [watchRoom].
  Future<void> roll(String roomId);
  Future<void> leaveRoom(String roomId);
  Future<QuickMatchResult> joinQueue({int maxPlayers = 2});
  Future<void> leaveQueue();
  Future<String?> currentRoomId();
  Stream<OnlineRoom?> watchRoom(String roomId);

  /// The room the user is currently seated in (set by the server), so a
  /// queued player learns about their match and reconnects find their game.
  Stream<String?> watchMyRoomId(String uid);

  /// Best-effort presence flag; offline implementations may ignore it.
  Future<void> setPresence(String roomId, String uid, bool online) async {}

  /// Human-readable note shown in the lobby (e.g. "offline simulation").
  String? get modeNote => null;
}

Map<String, dynamic> rulesToJson(GameRulesConfig r) => {
      'exactRollToWin': r.exactRollToWin,
      'extraTurnOnSix': r.extraTurnOnSix,
      'needSixToStart': r.needSixToStart,
      'maxConsecutiveSixes': r.maxConsecutiveSixes,
    };

/// Production implementation: REST for actions, RTDB for live state.
class ApiRoomService implements RoomService {
  ApiRoomService({required this.api, FirebaseDatabase? database})
      : _db = database ?? FirebaseDatabase.instance;

  final ApiClient api;
  final FirebaseDatabase _db;

  @override
  String? get modeNote => null;

  @override
  Future<OnlineRoom> createRoom({int maxPlayers = 2, GameRulesConfig? rules}) async {
    final res = await api.postJson('/rooms', {
      'maxPlayers': maxPlayers,
      if (rules != null) 'rules': rulesToJson(rules),
    });
    return OnlineRoom.fromMap(res['id'] as String, res);
  }

  @override
  Future<OnlineRoom> joinByCode(String code) async {
    final res = await api.postJson('/rooms/${code.trim().toUpperCase()}/join');
    return OnlineRoom.fromMap(res['id'] as String, res);
  }

  @override
  Future<OnlineRoom> startRoom(String roomId) async {
    final res = await api.postJson('/rooms/$roomId/start');
    return OnlineRoom.fromMap(res['id'] as String, res);
  }

  @override
  Future<void> roll(String roomId) => api.postJson('/rooms/$roomId/roll');

  @override
  Future<void> leaveRoom(String roomId) => api.postJson('/rooms/$roomId/leave');

  @override
  Future<QuickMatchResult> joinQueue({int maxPlayers = 2}) async {
    final res = await api.postJson('/matchmaking/join', {'maxPlayers': maxPlayers});
    return QuickMatchResult(status: '${res['status']}', roomId: res['roomId'] as String?);
  }

  @override
  Future<void> leaveQueue() => api.deleteJson('/matchmaking/join');

  @override
  Future<String?> currentRoomId() async => (await api.getJson('/rooms/current'))['roomId'] as String?;

  @override
  Stream<OnlineRoom?> watchRoom(String roomId) => _db
      .ref('rooms/$roomId')
      .onValue
      .map((e) => e.snapshot.exists ? OnlineRoom.fromMap(roomId, e.snapshot.value) : null);

  @override
  Stream<String?> watchMyRoomId(String uid) =>
      _db.ref('users_rooms/$uid').onValue.map((e) => e.snapshot.value as String?);

  @override
  Future<void> setPresence(String roomId, String uid, bool online) async {
    final ref = _db.ref('rooms/$roomId/presence/$uid');
    if (online) {
      await ref.onDisconnect().set(false);
      await ref.set(true);
    } else {
      await ref.set(false);
    }
  }
}
