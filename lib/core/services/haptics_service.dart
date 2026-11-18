import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Vibration feedback, switchable from settings.
class HapticsService {
  HapticsService({this.enabled = true});

  bool enabled;

  /// Dice tap, button press.
  Future<void> light() => _run(HapticFeedback.lightImpact);

  /// Landing on a cell.
  Future<void> selection() => _run(HapticFeedback.selectionClick);

  /// Ladder.
  Future<void> medium() => _run(HapticFeedback.mediumImpact);

  /// Snake bite, win.
  Future<void> heavy() => _run(HapticFeedback.heavyImpact);

  Future<void> _run(Future<void> Function() f) async {
    if (!enabled || kIsWeb) return;
    try {
      await f();
    } catch (_) {
      // No haptics on this device: ignore.
    }
  }
}
