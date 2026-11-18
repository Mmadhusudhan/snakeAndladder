/// The signed-in identity (from Firebase Auth or the offline fallback).
class AppUser {
  const AppUser({
    required this.uid,
    required this.isGuest,
    this.displayName,
    this.email,
    this.photoUrl,
    this.isOffline = false,
  });

  final String uid;
  final bool isGuest;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  /// True for the local guest used when Firebase is not configured.
  final bool isOffline;

  /// A friendly name to show when the profile has none yet.
  String get fallbackName {
    final n = displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return isGuest ? 'Guest ${uid.substring(0, uid.length.clamp(0, 4)).toUpperCase()}' : 'Player';
  }

  @override
  bool operator ==(Object other) =>
      other is AppUser && other.uid == uid && other.isGuest == isGuest && other.isOffline == isOffline;

  @override
  int get hashCode => Object.hash(uid, isGuest, isOffline);
}
