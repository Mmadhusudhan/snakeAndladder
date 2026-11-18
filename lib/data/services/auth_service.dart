import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_user.dart';

/// Thrown when sign-in fails for a reason worth showing to the player.
class AuthException implements Exception {
  const AuthException(this.message, {this.cancelled = false});

  final String message;

  /// True when the player closed the sign-in dialog themselves.
  final bool cancelled;

  @override
  String toString() => message;
}

/// Identity provider boundary. Two implementations: Firebase, and a local
/// offline guest used when Firebase is not configured (and in tests).
abstract class AuthService {
  Stream<AppUser?> get authStateChanges;
  AppUser? get currentUser;
  bool get supportsGoogle;

  Future<AppUser> signInAsGuest();
  Future<AppUser> signInWithGoogle();
  Future<void> signOut();

  /// A bearer token for the backend, or null for offline users.
  Future<String?> idToken();
}

/// Offline guest: one local user, no network. Keeps the whole app usable
/// before Firebase is configured.
class LocalAuthService implements AuthService {
  LocalAuthService({AppUser? initialUser, String? uid})
      : _uid = uid ?? 'local-${Random().nextInt(1 << 30).toRadixString(36)}' {
    _user = initialUser;
  }

  final String _uid;
  AppUser? _user;
  final _controller = StreamController<AppUser?>.broadcast();

  @override
  Stream<AppUser?> get authStateChanges {
    // Deliver the current user first, then every change. Subscribing to the
    // change stream synchronously on listen means nothing is missed.
    late final StreamController<AppUser?> out;
    StreamSubscription<AppUser?>? sub;
    out = StreamController<AppUser?>(
      onListen: () {
        out.add(_user);
        sub = _controller.stream.listen(out.add, onDone: out.close);
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  @override
  AppUser? get currentUser => _user;

  @override
  bool get supportsGoogle => false;

  @override
  Future<AppUser> signInAsGuest() async {
    _user = AppUser(uid: _uid, isGuest: true, isOffline: true, displayName: 'Guest');
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<AppUser> signInWithGoogle() =>
      throw const AuthException('Google sign-in needs Firebase to be configured.');

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  @override
  Future<String?> idToken() async => null;

  void dispose() => _controller.close();
}

/// Firebase Auth: anonymous guests and Google accounts.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({fb.FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? fb.FirebaseAuth.instance,
        _google = googleSignIn ?? GoogleSignIn.instance;

  final fb.FirebaseAuth _auth;
  final GoogleSignIn _google;
  bool _googleReady = false;

  static AppUser? _map(fb.User? u) {
    if (u == null) return null;
    return AppUser(
      uid: u.uid,
      isGuest: u.isAnonymous,
      displayName: u.displayName,
      email: u.email,
      photoUrl: u.photoURL,
    );
  }

  @override
  Stream<AppUser?> get authStateChanges => _auth.authStateChanges().map(_map);

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  bool get supportsGoogle => true;

  @override
  Future<AppUser> signInAsGuest() async {
    try {
      final cred = await _auth.signInAnonymously();
      return _map(cred.user)!;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_describe(e));
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      final current = _auth.currentUser;
      fb.UserCredential cred;
      if (kIsWeb) {
        final provider = fb.GoogleAuthProvider()..addScope('email');
        // Upgrade an anonymous guest in place so their stats survive.
        cred = current != null && current.isAnonymous
            ? await current.linkWithPopup(provider)
            : await _auth.signInWithPopup(provider);
      } else {
        if (!_googleReady) {
          await _google.initialize();
          _googleReady = true;
        }
        final account = await _google.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) throw const AuthException('Google did not return a token.');
        final credential = fb.GoogleAuthProvider.credential(idToken: idToken);
        cred = current != null && current.isAnonymous
            ? await current.linkWithCredential(credential)
            : await _auth.signInWithCredential(credential);
      }
      return _map(cred.user)!;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthException('Sign-in cancelled.', cancelled: true);
      }
      throw AuthException('Google sign-in failed: ${e.description ?? e.code.name}');
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use' || e.code == 'provider-already-linked') {
        // The Google account already has a profile: switch to it.
        final cred = await _auth.signInWithCredential(e.credential!);
        return _map(cred.user)!;
      }
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        throw const AuthException('Sign-in cancelled.', cancelled: true);
      }
      throw AuthException(_describe(e));
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb && _googleReady) {
      try {
        await _google.signOut();
      } catch (_) {}
    }
  }

  @override
  Future<String?> idToken() => _auth.currentUser?.getIdToken() ?? Future.value(null);

  static String _describe(fb.FirebaseAuthException e) => switch (e.code) {
        'network-request-failed' => 'No internet connection.',
        'operation-not-allowed' => 'This sign-in method is not enabled in Firebase.',
        'too-many-requests' => 'Too many attempts, please try again later.',
        _ => e.message ?? 'Sign-in failed (${e.code}).',
      };
}
