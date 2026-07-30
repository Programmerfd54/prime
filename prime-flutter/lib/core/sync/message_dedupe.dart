/// Merge helpers for chat polling (group + DM).
abstract final class MessageDedupe {
  static String? idOf(Map<String, dynamic> message) {
    final eventId = message['event_id']?.toString();
    if (eventId != null && eventId.isNotEmpty) return eventId;
    final id = message['id']?.toString();
    if (id != null && id.isNotEmpty) return id;
    final clientId = message['client_id']?.toString();
    if (clientId != null && clientId.isNotEmpty) return clientId;
    return null;
  }

  /// Merges [incoming] into [existing], updating duplicates by id.
  /// Returns true if any new message was added.
  static bool mergeInto(
    List<Map<String, dynamic>> existing,
    Iterable<Map<String, dynamic>> incoming, {
    String Function(Map<String, dynamic>)? sortKey,
  }) {
    var added = false;
    final indexById = <String, int>{};
    final indexByClientId = <String, int>{};
    for (var i = 0; i < existing.length; i++) {
      final id = idOf(existing[i]);
      if (id != null) indexById[id] = i;
      final clientId = existing[i]['client_id']?.toString();
      if (clientId != null && clientId.isNotEmpty) {
        indexByClientId[clientId] = i;
      }
    }

    for (final msg in incoming) {
      final id = idOf(msg);
      final clientId = msg['client_id']?.toString();
      final existingIndex = (id != null && indexById.containsKey(id))
          ? indexById[id]
          : (clientId != null && indexByClientId.containsKey(clientId))
              ? indexByClientId[clientId]
              : null;
      if (existingIndex != null) {
        existing[existingIndex] = _mergePreferLocalStatus(
          existing[existingIndex],
          msg,
        );
        continue;
      }
      existing.add(msg);
      if (id != null) indexById[id] = existing.length - 1;
      if (clientId != null && clientId.isNotEmpty) {
        indexByClientId[clientId] = existing.length - 1;
      }
      added = true;
    }

    final key = sortKey ?? _defaultSortKey;
    existing.sort((a, b) => key(a).compareTo(key(b)));
    return added;
  }

  static Map<String, dynamic> _mergePreferLocalStatus(
    Map<String, dynamic> local,
    Map<String, dynamic> incoming,
  ) {
    final localStatus = local['_status'] as String?;
    if (localStatus == OutboundMessageStatus.failed.name) {
      return {
        ...incoming,
        '_status': localStatus,
        if (local['_error'] != null) '_error': local['_error'],
      };
    }
    if (localStatus == OutboundMessageStatus.sending.name &&
        incoming['id'] == null) {
      return local;
    }
    return incoming;
  }

  static Comparable _defaultSortKey(Map<String, dynamic> m) {
    final ts = m['timestamp'];
    if (ts is num) return ts;
    final created = m['created_at']?.toString();
    if (created != null) return created;
    return idOf(m) ?? '';
  }
}

enum OutboundMessageStatus { sending, sent, failed }

class OutboundMessage {
  OutboundMessage({
    required this.clientId,
    required this.body,
    required this.status,
    this.msgtype = 'm.text',
    this.url,
    this.filename,
    this.contentType,
    this.sizeBytes,
    this.localPreviewBytes,
    this.serverMessage,
    this.error,
    this.replyToId,
    this.replyPreview,
  });

  final String clientId;
  final String body;
  OutboundMessageStatus status;
  final String msgtype;
  final String? url;
  final String? filename;
  final String? contentType;
  final int? sizeBytes;
  final List<int>? localPreviewBytes;
  Map<String, dynamic>? serverMessage;
  String? error;
  final String? replyToId;
  final String? replyPreview;

  Map<String, dynamic> asLocalBubble({required String senderUserId}) {
    return {
      'client_id': clientId,
      'body': body,
      'msgtype': msgtype,
      if (url != null) 'url': url,
      if (filename != null) 'filename': filename,
      if (contentType != null) 'content_type': contentType,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (localPreviewBytes != null) '_local_preview': localPreviewBytes,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (replyPreview != null) 'reply_preview': replyPreview,
      'sender_user_id': senderUserId,
      'created_at': DateTime.now().toIso8601String(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      '_status': status.name,
    };
  }
}
