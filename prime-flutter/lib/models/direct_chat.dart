import 'user.dart';

class DirectChatSummary {
  final UserPublic friend;
  final String? lastMessageBody;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const DirectChatSummary({
    required this.friend,
    this.lastMessageBody,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory DirectChatSummary.fromJson(Map<String, dynamic> json) {
    final friendJson = json['friend'] as Map<String, dynamic>? ?? const {};
    final last = json['last_message'] as Map<String, dynamic>?;
    DateTime? lastAt;
    final rawAt = last?['created_at'] as String?;
    if (rawAt != null) {
      lastAt = DateTime.tryParse(rawAt);
    }
    return DirectChatSummary(
      friend: UserPublic.fromJson(friendJson),
      lastMessageBody: _previewBody(last),
      lastMessageAt: lastAt,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }

  static String? _previewBody(Map<String, dynamic>? last) {
    if (last == null) return null;
    final msgtype = last['msgtype'] as String? ?? 'm.text';
    if (msgtype == 'm.image') return 'Изображение';
    if (msgtype == 'm.file') {
      final filename = last['filename'] as String?;
      return filename != null ? 'Файл · $filename' : 'Файл';
    }
    return last['body'] as String?;
  }
}
