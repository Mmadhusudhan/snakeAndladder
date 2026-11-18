import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/audio_service.dart';
import '../core/services/haptics_service.dart';
import '../data/models/app_settings.dart';
import '../data/services/settings_store.dart';

final settingsStoreProvider = Provider<SettingsStore>((ref) => PrefsSettingsStore());

final audioServiceProvider = Provider<AudioService>((ref) {
  final audio = AudioPlayersService();
  ref.onDispose(audio.dispose);
  return audio;
});

final hapticsProvider = Provider<HapticsService>((ref) => HapticsService());

/// Loads settings on start, persists every change, and keeps the audio and
/// haptics services in line with the toggles.
class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final store = ref.watch(settingsStoreProvider);
    Future.microtask(() async {
      try {
        final loaded = await store.load();
        state = loaded;
      } catch (_) {
        state = state.copyWith(loaded: true);
      }
      _apply();
    });
    return const AppSettings();
  }

  void _apply() {
    final audio = ref.read(audioServiceProvider);
    audio.soundEnabled = state.sound;
    audio.musicEnabled = state.music;
    ref.read(hapticsProvider).enabled = state.haptics;
  }

  Future<void> _update(AppSettings next) async {
    state = next;
    _apply();
    try {
      await ref.read(settingsStoreProvider).save(next);
    } catch (_) {
      // Storage failures must not break the game; the value stays in memory.
    }
  }

  Future<void> setSound(bool v) => _update(state.copyWith(sound: v));
  Future<void> setMusic(bool v) => _update(state.copyWith(music: v));
  Future<void> setHaptics(bool v) => _update(state.copyWith(haptics: v));
  Future<void> setThemeMode(ThemeMode m) => _update(state.copyWith(themeMode: m));
  Future<void> completeOnboarding() => _update(state.copyWith(onboardingDone: true));
  Future<void> resetOnboarding() => _update(state.copyWith(onboardingDone: false));
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
