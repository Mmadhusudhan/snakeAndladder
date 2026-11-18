import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Whether Firebase could be started, and why not if it could not.
class FirebaseStatus {
  const FirebaseStatus._(this.available, this.reason);

  final bool available;
  final String? reason;

  static const FirebaseStatus ready = FirebaseStatus._(true, null);
  const FirebaseStatus.unavailable(String reason) : this._(false, reason);

  @override
  String toString() => available ? 'Firebase ready' : 'Firebase unavailable: $reason';
}

/// Starts Firebase once. Never throws: an unconfigured or failing Firebase
/// puts the app in offline mode instead of crashing it.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static FirebaseStatus? _status;

  static FirebaseStatus? get status => _status;

  static Future<FirebaseStatus> initialize() async {
    final existing = _status;
    if (existing != null) return existing;
    if (!DefaultFirebaseOptions.isConfigured) {
      return _status = const FirebaseStatus.unavailable(
        'Firebase is not configured. Run `flutterfire configure` (see README).',
      );
    }
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      return _status = FirebaseStatus.ready;
    } catch (e, st) {
      debugPrint('Firebase init failed: $e\n$st');
      return _status = FirebaseStatus.unavailable('$e');
    }
  }

  /// For tests.
  @visibleForTesting
  static void reset([FirebaseStatus? status]) => _status = status;
}
