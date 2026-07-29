import 'package:shared_preferences/shared_preferences.dart';

/// Demo «ознакомительный день» — локально, не влияет на серию.
class HabitPreviewDay {
  static String _key(String skillId) => 'prime_habit_preview_$skillId';

  static Future<bool> isCompleted(String skillId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(skillId)) ?? false;
  }

  static Future<void> markCompleted(String skillId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(skillId), true);
  }

  static Future<void> reset(String skillId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(skillId));
  }
}
