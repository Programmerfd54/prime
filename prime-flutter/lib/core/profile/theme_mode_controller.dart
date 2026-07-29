import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted theme preference (system / light / dark).
class ThemeModeController extends ChangeNotifier {
  ThemeModeController() {
    _load();
  }

  static const _prefsKey = 'prime_theme_mode';

  ThemeMode _mode = ThemeMode.dark;
  bool _loaded = false;

  ThemeMode get mode => _mode;
  bool get loaded => _loaded;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      _mode = switch (raw) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('ThemeMode load: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
        ThemeMode.dark => 'dark',
      };
      await prefs.setString(_prefsKey, raw);
    } catch (e) {
      if (kDebugMode) debugPrint('ThemeMode save: $e');
    }
  }

  void cycle() {
    final next = switch (_mode) {
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.light => ThemeMode.system,
      ThemeMode.system => ThemeMode.dark,
    };
    setMode(next);
  }
}
