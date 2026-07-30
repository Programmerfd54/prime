/// Typed chat message for direct and group channels.
class ChatReactionModel {
  const ChatReactionModel({
    required this.emoji,
    required this.count,
    this.reactedByMe = false,
  });

  final String emoji;
  final int count;
  final bool reactedByMe;

  factory ChatReactionModel.fromJson(Map<String, dynamic> json) =>
      ChatReactionModel(
        emoji: json['emoji'] as String? ?? '',
        count: json['count'] as int? ?? 0,
        reactedByMe: json['reacted_by_me'] as bool? ?? false,
      );
}

enum ChatDeliveryStatus { sending, sent, read, failed }

class ChatMessageModel {
  const ChatMessageModel({
    this.id,
    this.clientId,
    this.senderUserId,
    this.recipientUserId,
    this.msgtype = 'm.text',
    this.body = '',
    this.url,
    this.filename,
    this.contentType,
    this.sizeBytes,
    this.createdAt,
    this.timestamp,
    this.replyToId,
    this.replyPreview,
    this.editedAt,
    this.deleted = false,
    this.reactions = const [],
    this.readByPeer = false,
    this.deliveryStatus,
    this.senderMatrixId,
    this.senderProfile,
    this.localPreviewBytes,
    this.localStatus,
    this.localError,
  });

  final String? id;
  final String? clientId;
  final String? senderUserId;
  final String? recipientUserId;
  final String msgtype;
  final String body;
  final String? url;
  final String? filename;
  final String? contentType;
  final int? sizeBytes;
  final DateTime? createdAt;
  final int? timestamp;
  final String? replyToId;
  final String? replyPreview;
  final DateTime? editedAt;
  final bool deleted;
  final List<ChatReactionModel> reactions;
  final bool readByPeer;
  final ChatDeliveryStatus? deliveryStatus;
  final String? senderMatrixId;
  final Map<String, dynamic>? senderProfile;
  final List<int>? localPreviewBytes;
  final String? localStatus;
  final String? localError;

  String get stableId => id ?? clientId ?? '';

  bool get isReportMessage =>
      msgtype == 'prime.report' ||
      body.startsWith('✅ Отчёт') ||
      body.startsWith('✏️ Отчёт');

  bool get isPairInvite => msgtype == 'prime.pair_invite';

  factory ChatMessageModel.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
    DateTime? peerLastReadAt,
  }) {
    final created =
        _parseDate(json['created_at']) ?? _fromTimestamp(json['timestamp']);
    final senderId = json['sender_user_id'] as String?;
    final localStatus = json['_status'] as String?;
    ChatDeliveryStatus? status;
    if (localStatus == 'sending') {
      status = ChatDeliveryStatus.sending;
    } else if (localStatus == 'failed') {
      status = ChatDeliveryStatus.failed;
    } else if (json['read_by_peer'] == true ||
        (peerLastReadAt != null &&
            created != null &&
            senderId == currentUserId &&
            currentUserId != null &&
            !created.isAfter(peerLastReadAt))) {
      status = ChatDeliveryStatus.read;
    } else if ((senderId == currentUserId &&
            currentUserId != null &&
            (localStatus == 'sent' || json['id'] != null)) ||
        (currentUserId == null && json['id'] != null)) {
      status = ChatDeliveryStatus.sent;
    }

    final reactionsRaw = json['reactions'] as List<dynamic>? ?? const [];
    final reactions = reactionsRaw
        .whereType<Map>()
        .map((item) =>
            ChatReactionModel.fromJson(Map<String, dynamic>.from(item)))
        .where((r) => r.emoji.isNotEmpty && r.count > 0)
        .toList();

    final senderProfileRaw = json['sender_profile'];
    Map<String, dynamic>? senderProfile;
    if (senderProfileRaw is Map) {
      senderProfile = Map<String, dynamic>.from(senderProfileRaw);
    }

    final previewRaw = json['_local_preview'];
    List<int>? localPreview;
    if (previewRaw is List) {
      localPreview = previewRaw.cast<int>();
    }

    return ChatMessageModel(
      id: json['id'] as String?,
      clientId: json['client_id'] as String?,
      senderUserId: senderId,
      recipientUserId: json['recipient_user_id'] as String?,
      msgtype: json['msgtype'] as String? ?? 'm.text',
      body: json['body'] as String? ?? '',
      url: json['url'] as String?,
      filename: json['filename'] as String?,
      contentType: json['content_type'] as String?,
      sizeBytes: json['size_bytes'] as int?,
      createdAt: created,
      timestamp: json['timestamp'] as int?,
      replyToId: json['reply_to_id'] as String?,
      replyPreview: json['reply_preview'] as String?,
      editedAt: _parseDate(json['edited_at']),
      deleted: json['deleted'] as bool? ?? false,
      reactions: reactions,
      readByPeer:
          json['read_by_peer'] as bool? ?? status == ChatDeliveryStatus.read,
      deliveryStatus: status,
      senderMatrixId: json['sender'] as String?,
      senderProfile: senderProfile,
      localPreviewBytes: localPreview,
      localStatus: localStatus,
      localError: json['_error'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        if (clientId != null) 'client_id': clientId,
        if (senderUserId != null) 'sender_user_id': senderUserId,
        if (recipientUserId != null) 'recipient_user_id': recipientUserId,
        'msgtype': msgtype,
        'body': body,
        if (url != null) 'url': url,
        if (filename != null) 'filename': filename,
        if (contentType != null) 'content_type': contentType,
        if (sizeBytes != null) 'size_bytes': sizeBytes,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (timestamp != null) 'timestamp': timestamp,
        if (replyToId != null) 'reply_to_id': replyToId,
        if (replyPreview != null) 'reply_preview': replyPreview,
        if (editedAt != null) 'edited_at': editedAt!.toIso8601String(),
        'deleted': deleted,
        'reactions': reactions
            .map(
              (r) => {
                'emoji': r.emoji,
                'count': r.count,
                'reacted_by_me': r.reactedByMe,
              },
            )
            .toList(),
        'read_by_peer': readByPeer,
        if (localStatus != null) '_status': localStatus,
        if (localError != null) '_error': localError,
        if (senderMatrixId != null) 'sender': senderMatrixId,
        if (senderProfile != null) 'sender_profile': senderProfile,
        if (localPreviewBytes != null) '_local_preview': localPreviewBytes,
      };

  ChatMessageModel copyWith({
    List<ChatReactionModel>? reactions,
    ChatDeliveryStatus? deliveryStatus,
    bool? readByPeer,
  }) =>
      ChatMessageModel(
        id: id,
        clientId: clientId,
        senderUserId: senderUserId,
        recipientUserId: recipientUserId,
        msgtype: msgtype,
        body: body,
        url: url,
        filename: filename,
        contentType: contentType,
        sizeBytes: sizeBytes,
        createdAt: createdAt,
        timestamp: timestamp,
        replyToId: replyToId,
        replyPreview: replyPreview,
        editedAt: editedAt,
        deleted: deleted,
        reactions: reactions ?? this.reactions,
        readByPeer: readByPeer ?? this.readByPeer,
        deliveryStatus: deliveryStatus ?? this.deliveryStatus,
        senderMatrixId: senderMatrixId,
        senderProfile: senderProfile,
        localPreviewBytes: localPreviewBytes,
        localStatus: localStatus,
        localError: localError,
      );

  static DateTime? _parseDate(Object? raw) {
    if (raw is String) return DateTime.tryParse(raw)?.toLocal();
    return null;
  }

  static DateTime? _fromTimestamp(Object? raw) {
    if (raw is int) {
      final ms = raw > 9999999999 ? raw : raw * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    }
    return null;
  }
}

/// Quick-reply chip labels for direct chat composer.
const directQuickReplies = [
  'Отчёт готов',
  'Поддерживаю',
  'Как прошло?',
];
