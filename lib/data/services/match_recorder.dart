import 'package:flutter/foundation.dart';

import '../../features/game/models/game_state.dart';
import '../../providers/game_providers.dart';
import '../models/app_user.dart';
import '../models/match_record.dart';
import '../repositories/profile_repository.dart';
import 'api_client.dart';

/// Saves finished games: history + casual stats locally / in Firestore,
/// and, when the backend is configured, submits the match for validation
/// so the server can update the leaderboard.
class MatchRecorder {
  MatchRecorder({required this.repository, required this.api});

  final ProfileRepository repository;
  final ApiClient api;

  /// Seat of the signed-in user: seat 0 against the computer, none for
  /// pass-and-play where any human could be them.
  static int? seatFor(GameSetup setup) =>
      setup.mode == GameMode.localMultiplayer ? null : 0;

  Future<MatchRecord?> record(AppUser? user, GameState state, GameSetup setup) async {
    if (user == null || !state.isCompleted) return null;
    final match = MatchRecord.fromGame(state, setup, myIndex: seatFor(setup));
    await repository.recordMatch(user.uid, match);
    if (api.isEnabled && !user.isOffline) {
      try {
        await api.submitMatch(match);
      } catch (e) {
        // The game is already in local history; the leaderboard will catch
        // up when the server is reachable. Never block the player on this.
        debugPrint('Match submission failed: $e');
      }
    }
    return match;
  }
}
