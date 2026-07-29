import 'package:shared_preferences/shared_preferences.dart';

/// Saved habit programs — local cache with backend sync when authenticated.
class HabitFavorites {
  static const _key = 'prime_habit_favorites';

  static Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  static Future<void> replaceAll(Set<String> skillIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, skillIds.toList());
  }

  static Future<bool> toggle(String skillId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_key) ?? const []).toSet();
    final added = !current.contains(skillId);
    if (added) {
      current.add(skillId);
    } else {
      current.remove(skillId);
    }
    await prefs.setStringList(_key, current.toList());
    return added;
  }

  static Future<bool> isFavorite(String skillId) async {
    final all = await load();
    return all.contains(skillId);
  }
}
