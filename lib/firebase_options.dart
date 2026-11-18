// Firebase configuration for project `car-game-e403f`.
//
// This file is a TEMPLATE. Replace it by running:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=car-game-e403f
//
// which fills in the real API keys and app ids for every platform. Until
// then `isConfigured` is false and the app runs in offline mode (local
// guest, no cloud profile). The file is git-ignored so real keys never land
// in the repository.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const String projectId = 'car-game-e403f';
  static const String messagingSenderId = '214273362799';

  static const String _placeholder = 'REPLACE_ME';

  /// False while the placeholders above are still in place.
  static bool get isConfigured => !currentPlatform.apiKey.startsWith(_placeholder);

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC0qBWN99XxCzdC_QZHkCJOGGwxyn0OJDk',
    appId: '1:214273362799:web:d6b9e5d9f9486c8a0df69a',
    messagingSenderId: '214273362799',
    projectId: 'car-game-e403f',
    authDomain: 'car-game-e403f.firebaseapp.com',
    storageBucket: 'car-game-e403f.firebasestorage.app',
    measurementId: 'G-F4HWZXPRWK',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCMJyb25Q9M_WeW11brJqHN5fFMZPqIics',
    appId: '1:214273362799:android:6445f7a5c36b22cb0df69a',
    messagingSenderId: '214273362799',
    projectId: 'car-game-e403f',
    storageBucket: 'car-game-e403f.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCQe3l4RMC6zT4DhynQlYYfSPvbmqPfVM4',
    appId: '1:214273362799:ios:4413b84c4c7f2c690df69a',
    messagingSenderId: '214273362799',
    projectId: 'car-game-e403f',
    storageBucket: 'car-game-e403f.firebasestorage.app',
    iosBundleId: 'in.nextaqua.snakesLadders',
  );
  static const FirebaseOptions macos = ios;
}
