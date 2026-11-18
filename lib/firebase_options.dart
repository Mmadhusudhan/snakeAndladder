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
    apiKey: '${_placeholder}_WEB_API_KEY',
    appId: '1:$messagingSenderId:web:REPLACE_ME',
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: '$projectId.firebaseapp.com',
    storageBucket: '$projectId.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '${_placeholder}_ANDROID_API_KEY',
    appId: '1:$messagingSenderId:android:REPLACE_ME',
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    storageBucket: '$projectId.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: '${_placeholder}_IOS_API_KEY',
    appId: '1:$messagingSenderId:ios:REPLACE_ME',
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    storageBucket: '$projectId.appspot.com',
    iosBundleId: 'in.nextaqua.snakesLadders',
  );

  static const FirebaseOptions macos = ios;
}
