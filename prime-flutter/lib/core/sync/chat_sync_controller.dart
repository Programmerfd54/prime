import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/api_client.dart';
import '../errors/failure_mapper.dart';
import 'message_dedupe.dart';

/// Avoid flashing "no connection" on a single slow poll when messages exist.
bool chatOfflineVisible({
  required bool networkError,
  required int consecutiveNetworkFailures,
  required bool hasMessages,
}) {
  if (!networkError) return false;
  if (!hasMessages) return true;
  return consecutiveNetworkFailures >= 2;
}

enum ChatChannelKind { direct, group }

/// HTTP polling sync for open chats. Pause in background; resume on foreground.
class ChatSyncController extends ChangeNotifier {
  ChatSyncController(this._api);

  final ApiClient _api;

  final List<Map<String, dynamic>> messages = [];
  bool loading = true;
  bool syncing = false;
  String? error;
  String? errorCorrelationId;
  bool hasMore = false;
  String? nextBefore;
  bool offline = false;
  DateTime? peerLastReadAt;

  ChatChannelKind? _kind;
  String? _channelId;
  Timer? _timer;
  bool _disposed = false;
  int _consecutiveNetworkFailures = 0;
  bool _needsFreshSync = true;
  bool _syncQueued = false;
  bool _queuedForceRefresh = false;
  Duration pollInterval = const Duration(seconds: 1);

  void start({
    required ChatChannelKind kind,
    required String channelId,
    Duration? interval,
    Map<String, dynamic>? cachedPayload,
  }) {
    _kind = kind;
    _channelId = channelId;
    if (interval != null) pollInterval = interval;
    messages.clear();
    error = null;
    errorCorrelationId = null;
    offline = false;
    _consecutiveNetworkFailures = 0;
    _needsFreshSync = true;

    if (cachedPayload != null) {
      _applyPayload(cachedPayload);
    }
    loading = false;

    _restartTimer(immediate: true);
  }

  /// Apply disk cache after first paint when memory had nothing.
  void warmCache(Map<String, dynamic> payload) {
    if (_disposed || messages.isNotEmpty) return;
    _applyPayload(payload);
    loading = false;
    notifyListeners();
  }

  void _applyPayload(Map<String, dynamic> result) {
    final incoming = (result['messages'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    hasMore = result['has_more'] as bool? ?? false;
    nextBefore = result['next_before'] as String?;
    final peerReadRaw = result['peer_last_read_at'] as String?;
    if (peerReadRaw != null) {
      final parsed = DateTime.tryParse(peerReadRaw)?.toLocal();
      if (parsed != null &&
          (peerLastReadAt == null || parsed.isAfter(peerLastReadAt!))) {
        peerLastReadAt = parsed;
      }
    }
    MessageDedupe.mergeInto(messages, incoming);
  }

  /// Apply a live push payload without waiting for HTTP sync.
  void applyIncomingMessage(Map<String, dynamic> message) {
    if (_disposed) return;
    MessageDedupe.mergeInto(messages, [message]);
    loading = false;
    error = null;
    errorCorrelationId = null;
    offline = false;
    notifyListeners();
  }

  /// Apply live read receipt without waiting for HTTP sync.
  void applyPeerReadAt(DateTime readAt) {
    if (_disposed) return;
    final local = readAt.toLocal();
    if (peerLastReadAt != null && !local.isAfter(peerLastReadAt!)) return;
    peerLastReadAt = local;
    notifyListeners();
  }

  void pause() => _timer?.cancel();

  void resume() {
    if (_channelId == null) return;
    _restartTimer(immediate: true);
  }

  void _restartTimer({bool immediate = false}) {
    _timer?.cancel();
    if (immediate) {
      unawaited(sync());
    }
    _timer = Timer.periodic(pollInterval, (_) => unawaited(sync()));
  }

  Future<void> sync({bool forceRefresh = false}) async {
    final kind = _kind;
    final channelId = _channelId;
    if (kind == null || channelId == null || _disposed) return;
    if (syncing) {
      _syncQueued = true;
      _queuedForceRefresh = _queuedForceRefresh || forceRefresh;
      return;
    }
    // Open direct threads poll every second — always bypass SWR cache so live
    // delivery works even when SSE carries only message_id (no payload).
    final refresh = forceRefresh ||
        _needsFreshSync ||
        _queuedForceRefresh ||
        kind == ChatChannelKind.direct;
    if (_needsFreshSync) _needsFreshSync = false;
    _queuedForceRefresh = false;
    syncing = true;
    try {
      final result = switch (kind) {
        ChatChannelKind.direct =>
          await _api.directMessages(channelId, forceRefresh: refresh),
        ChatChannelKind.group => await _api.chatSync(channelId),
      };
      _applyPayload(result);
      error = null;
      errorCorrelationId = null;
      _consecutiveNetworkFailures = 0;
      offline = false;
    } catch (e) {
      final networkError = ApiClient.isNetworkError(e);
      if (networkError) {
        _consecutiveNetworkFailures++;
      } else {
        _consecutiveNetworkFailures = 0;
      }
      offline = chatOfflineVisible(
        networkError: networkError,
        consecutiveNetworkFailures: _consecutiveNetworkFailures,
        hasMessages: messages.isNotEmpty,
      );
      if (messages.isEmpty) {
        final failure = FailureMapper.from(e);
        error = failure.message;
        errorCorrelationId = failure.correlationId;
      }
    } finally {
      syncing = false;
      loading = false;
      if (!_disposed) notifyListeners();
      if (_syncQueued && !_disposed) {
        _syncQueued = false;
        final queuedForce = _queuedForceRefresh;
        _queuedForceRefresh = false;
        unawaited(sync(forceRefresh: queuedForce));
      }
    }
  }

  Future<void> loadOlder() async {
    final kind = _kind;
    final channelId = _channelId;
    final before = nextBefore;
    if (kind == null || channelId == null || before == null) return;
    try {
      final result = switch (kind) {
        ChatChannelKind.direct =>
          await _api.directMessages(channelId, before: before),
        ChatChannelKind.group =>
          await _api.chatSync(channelId, before: before),
      };
      final older = (result['messages'] as List<dynamic>? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      MessageDedupe.mergeInto(messages, older);
      hasMore = result['has_more'] as bool? ?? false;
      nextBefore = result['next_before'] as String?;
      if (!_disposed) notifyListeners();
    } catch (_) {
      // Keep live sync alive even if history page fails.
    }
  }

  Future<Map<String, dynamic>> sendText(
    String body, {
    required String senderUserId,
    String? replyToId,
    String? replyPreview,
  }) async {
    final kind = _kind;
    final channelId = _channelId;
    if (kind == null || channelId == null) {
      throw StateError('Chat sync is not started');
    }
    final clientId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final local = OutboundMessage(
      clientId: clientId,
      body: body,
      status: OutboundMessageStatus.sent,
      replyToId: replyToId,
      replyPreview: replyPreview,
    ).asLocalBubble(senderUserId: senderUserId);
    messages.add(local);
    notifyListeners();

    unawaited(
      _deliverText(
        clientId: clientId,
        body: body,
        replyToId: replyToId,
      ),
    );
    return local;
  }

  Future<void> _deliverText({
    required String clientId,
    required String body,
    String? replyToId,
  }) async {
    final kind = _kind;
    final channelId = _channelId;
    if (kind == null || channelId == null || _disposed) return;

    try {
      final server = switch (kind) {
        ChatChannelKind.direct => await _api.sendDirectMessage(
            channelId,
            body,
            replyToId: replyToId,
            clientId: clientId,
          ),
        ChatChannelKind.group => await _api.chatSendMessage(
            channelId,
            body,
            clientId: clientId,
          ),
      };
      final idx = messages.indexWhere((m) => m['client_id'] == clientId);
      if (idx != -1) {
        messages[idx] = {
          ...server,
          '_status': OutboundMessageStatus.sent.name,
        };
      } else {
        MessageDedupe.mergeInto(messages, [server]);
      }
      offline = false;
      _consecutiveNetworkFailures = 0;
      notifyListeners();
      unawaited(sync(forceRefresh: true));
    } catch (e) {
      final idx = messages.indexWhere((m) => m['client_id'] == clientId);
      if (idx != -1) {
        messages[idx] = {
          ...messages[idx],
          '_status': OutboundMessageStatus.failed.name,
          '_error': FailureMapper.from(e).message,
        };
      }
      final networkError = ApiClient.isNetworkError(e);
      if (networkError) {
        _consecutiveNetworkFailures++;
      }
      offline = chatOfflineVisible(
        networkError: networkError,
        consecutiveNetworkFailures: _consecutiveNetworkFailures,
        hasMessages: messages.isNotEmpty,
      );
      notifyListeners();
    }
  }

  Future<void> retryFailed(String clientId, {required String senderUserId}) async {
    final idx = messages.indexWhere((m) => m['client_id'] == clientId);
    if (idx == -1) return;
    final failed = messages[idx];
    final msgtype = failed['msgtype'] as String? ?? 'm.text';
    messages.removeAt(idx);
    notifyListeners();
    if (msgtype == 'm.text') {
      await sendText(
        failed['body'] as String? ?? '',
        senderUserId: senderUserId,
        replyToId: failed['reply_to_id'] as String?,
        replyPreview: failed['reply_preview'] as String?,
      );
      return;
    }
    await sendMedia(
      senderUserId: senderUserId,
      msgtype: msgtype,
      body: failed['body'] as String? ?? '',
      upload: {
        'mxc_url': failed['url'],
        'filename': failed['filename'],
        'content_type': failed['content_type'],
        'size_bytes': failed['size_bytes'],
      },
      localPreviewBytes: failed['_local_preview'] as List<int>?,
    );
  }

  /// Sends already-uploaded media metadata as a chat message. Works for
  /// both direct and group channels (whichever [start] configured).
  Future<Map<String, dynamic>> sendMedia({
    required String senderUserId,
    required String msgtype,
    required String body,
    required Map<String, dynamic> upload,
    List<int>? localPreviewBytes,
    void Function(double progress)? onProgress,
  }) async {
    final kind = _kind;
    final channelId = _channelId;
    if (kind == null || channelId == null) {
      throw StateError('Chat sync is not started');
    }
    final clientId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final local = OutboundMessage(
      clientId: clientId,
      body: body,
      status: OutboundMessageStatus.sending,
      msgtype: msgtype,
      url: upload['url'] as String? ?? upload['mxc_url'] as String?,
      filename: upload['filename'] as String?,
      contentType: upload['content_type'] as String?,
      sizeBytes: upload['size_bytes'] as int?,
      localPreviewBytes: localPreviewBytes,
    ).asLocalBubble(senderUserId: senderUserId);
    messages.add(local);
    notifyListeners();

    try {
      final server = switch (kind) {
        ChatChannelKind.direct => await _api.sendDirectMessage(
            channelId,
            body,
            msgtype: msgtype,
            url: upload['mxc_url'] as String? ?? upload['url'] as String?,
            filename: upload['filename'] as String?,
            contentType: upload['content_type'] as String?,
            sizeBytes: upload['size_bytes'] as int?,
            clientId: clientId,
          ),
        ChatChannelKind.group => await _api.chatSendMedia(
            channelId,
            upload,
            msgtype: msgtype,
            body: body,
          ),
      };
      final idx = messages.indexWhere((m) => m['client_id'] == clientId);
      if (idx != -1) {
        messages[idx] = {
          ...server,
          '_status': OutboundMessageStatus.sent.name,
        };
      } else {
        MessageDedupe.mergeInto(messages, [server]);
      }
      offline = false;
      _consecutiveNetworkFailures = 0;
      notifyListeners();
      unawaited(sync());
      return server;
    } catch (e) {
      final idx = messages.indexWhere((m) => m['client_id'] == clientId);
      if (idx != -1) {
        messages[idx] = {
          ...messages[idx],
          '_status': OutboundMessageStatus.failed.name,
          '_error': FailureMapper.from(e).message,
        };
      }
      final networkError = ApiClient.isNetworkError(e);
      if (networkError) {
        _consecutiveNetworkFailures++;
      }
      offline = chatOfflineVisible(
        networkError: networkError,
        consecutiveNetworkFailures: _consecutiveNetworkFailures,
        hasMessages: messages.isNotEmpty,
      );
      notifyListeners();
      rethrow;
    }
  }

  /// Pull latest messages immediately (e.g. SSE push).
  Future<void> bumpSync() => sync(forceRefresh: true);

  /// Uploads bytes then sends the resulting media message. Works for both
  /// direct and group channels. Cancellation is a real Dio abort via
  /// [cancelToken] — not a post-hoc flag check.
  Future<Map<String, dynamic>> uploadAndSendMedia({
    required String senderUserId,
    required Uint8List bytes,
    required String filename,
    required String contentType,
    required bool isImage,
    String? caption,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final kind = _kind;
    final channelId = _channelId;
    if (kind == null || channelId == null) {
      throw StateError('Chat sync is not started');
    }
    void onSendProgress(int sent, int total) {
      if (total > 0) onProgress?.call(sent / total);
    }

    final upload = switch (kind) {
      ChatChannelKind.direct => await _api.directChatUpload(
          channelId,
          bytes: bytes,
          filename: filename,
          contentType: contentType,
          onSendProgress: onSendProgress,
          cancelToken: cancelToken,
        ),
      ChatChannelKind.group => await _api.chatUploadMediaBytes(
          channelId,
          bytes: bytes,
          filename: filename,
          contentType: contentType,
          onSendProgress: onSendProgress,
          cancelToken: cancelToken,
        ),
    };
    final msgtype = isImage ? 'm.image' : 'm.file';
    final body = (caption?.trim().isNotEmpty == true)
        ? caption!.trim()
        : (isImage ? 'Изображение' : filename);
    return sendMedia(
      senderUserId: senderUserId,
      msgtype: msgtype,
      body: body,
      upload: upload,
      localPreviewBytes: isImage ? bytes : null,
      onProgress: onProgress,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
