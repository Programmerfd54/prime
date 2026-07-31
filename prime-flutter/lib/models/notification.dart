enum PrimeNotificationType {
  match,
  mention,
  friendRequest,
  support,
  system,
}

PrimeNotificationType parseNotificationType(String raw) {
  switch (raw) {
    case 'match':
      return PrimeNotificationType.match;
    case 'mention':
      return PrimeNotificationType.mention;
    case 'friend_request':
      return PrimeNotificationType.friendRequest;
    case 'support':
      return PrimeNotificationType.support;
    default:
      return PrimeNotificationType.system;
  }
}

class PrimeNotification {
  const PrimeNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.payload,
    required this.read,
    required this.createdAt,
    this.rawType = 'system',
  });

  final String id;
  final PrimeNotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> payload;
  final bool read;
  final DateTime createdAt;
  final String rawType;

  String? get requestId {
    final raw = payload['request_id'];
    if (raw is String && raw.isNotEmpty) return raw;
    if (raw != null) return raw.toString();
    return null;
  }

  String? get requesterId {
    final raw = payload['requester_id'];
    if (raw is String && raw.isNotEmpty) return raw;
    if (raw != null) return raw.toString();
    return null;
  }

  String? get requesterNickname {
    final raw = payload['requester_nickname'];
    if (raw is String && raw.isNotEmpty) return raw;
    if (raw != null) return raw.toString();
    return null;
  }
  String? get groupId => payload['group_id'] as String?;

  factory PrimeNotification.fromJson(Map<String, dynamic> json) {
    return PrimeNotification(
      id: json['id'] as String? ?? '',
      type: parseNotificationType(json['type'] as String? ?? ''),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      rawType: json['type'] as String? ?? 'system',
    );
  }
}

class NotificationListResponse {
  const NotificationListResponse({
    required this.items,
    required this.unreadCount,
  });

  final List<PrimeNotification> items;
  final int unreadCount;

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) {
    return NotificationListResponse(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) =>
              PrimeNotification.fromJson(item as Map<String, dynamic>))
          .toList(),
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}
