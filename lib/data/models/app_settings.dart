import 'package:material_ui/material_ui.dart' show ThemeMode;

/// User preferences persisted on the device.
class AppSettings {
  const AppSettings({
    this.sound = true,
    this.music = true,
    this.haptics = true,
    this.themeMode = ThemeMode.dark,
    this.onboardingDone = false,
    this.loaded = false,
  });

  final bool sound;
  final bool music;
  final bool haptics;
  final ThemeMode themeMode;
  final bool onboardingDone;

  /// False until the stored values have been read.
  final bool loaded;

  AppSettings copyWith({
    bool? sound,
    bool? music,
    bool? haptics,
    ThemeMode? themeMode,
    bool? onboardingDone,
    bool? loaded,
  }) {
    return AppSettings(
      sound: sound ?? this.sound,
      music: music ?? this.music,
      haptics: haptics ?? this.haptics,
      themeMode: themeMode ?? this.themeMode,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      loaded: loaded ?? this.loaded,
    );
  }

  Map<String, Object> toMap() => {
        'sound': sound,
        'music': music,
        'haptics': haptics,
        'themeMode': themeMode.name,
        'onboardingDone': onboardingDone,
      };

  factory AppSettings.fromMap(Map<String, Object?> m) => AppSettings(
        sound: (m['sound'] as bool?) ?? true,
        music: (m['music'] as bool?) ?? true,
        haptics: (m['haptics'] as bool?) ?? true,
        themeMode: ThemeMode.values.firstWhere(
          (t) => t.name == m['themeMode'],
          orElse: () => ThemeMode.dark,
        ),
        onboardingDone: (m['onboardingDone'] as bool?) ?? false,
        loaded: true,
      );
}
