import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// Where [AppSettings] are kept.
abstract class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

/// Device storage via `shared_preferences`.
class PrefsSettingsStore implements SettingsStore {
  static const _prefix = 'settings.';

  @override
  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, Object?>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_prefix)) map[key.substring(_prefix.length)] = prefs.get(key);
    }
    return AppSettings.fromMap(map);
  }

  @override
  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    for (final e in settings.toMap().entries) {
      final v = e.value;
      if (v is bool) {
        await prefs.setBool('$_prefix${e.key}', v);
      } else {
        await prefs.setString('$_prefix${e.key}', '$v');
      }
    }
  }
}

/// Tests and previews.
class InMemorySettingsStore implements SettingsStore {
  InMemorySettingsStore([AppSettings? initial]) : _settings = initial;

  AppSettings? _settings;
  int saves = 0;

  AppSettings? get current => _settings;

  @override
  Future<AppSettings> load() async => (_settings ?? const AppSettings()).copyWith(loaded: true);

  @override
  Future<void> save(AppSettings settings) async {
    _settings = settings;
    saves++;
  }
}
