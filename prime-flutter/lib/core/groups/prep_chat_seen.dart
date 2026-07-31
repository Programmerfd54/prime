import 'package:shared_preferences/shared_preferences.dart';

/// Tracks last-seen prep-chat message per group for unread badge.
abstract final class PrepChatSeenStore {
  static String _key(String groupId) => 'prep_chat_seen_$groupId';

  static Future<int> lastSeenCount(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(groupId)) ?? 0;
  }

  static Future<void> markSeen(String groupId, int messageCount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(groupId), messageCount);
  }

  static int unreadCount(int totalMessages, int lastSeen) =>
      (totalMessages - lastSeen).clamp(0, 99);
}
