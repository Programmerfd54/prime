import 'package:shared_preferences/shared_preferences.dart';

/// Pending team search after auth — set during onboarding pre-auth flow.
class PendingSearch {
  static const _key = 'prime_pending_search_skill_id';

  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> save(String skillId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, skillId);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
