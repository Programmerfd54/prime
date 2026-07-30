import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../data/api_client.dart';
import '../../models/notification.dart';
import '../errors/failure_mapper.dart';

typedef DirectMessageListener = void Function(DirectMessagePush push);
typedef DirectChatReadListener = void Function(DirectChatReadPush push);
typedef GroupUpdateListener = void Function(GroupUpdatePush push);
typedef GroupChatUpdateListener = void Function(GroupChatUpdatePush push);

class DirectMessagePush {
  const DirectMessagePush({required this.friendId, this.message});

  final String friendId;
  final Map<String, dynamic>? message;
}

class DirectChatReadPush {
  const DirectChatReadPush({required this.friendId, required this.readAt});

  final String friendId;
  final DateTime readAt;
}

class GroupUpdatePush {
  const GroupUpdatePush({required this.groupId});

  final String groupId;
}

class GroupChatUpdatePush {
  const GroupChatUpdatePush({required this.groupId});

  final String groupId;
}

/// Live notifications via SSE with polling fallback.
class RealtimeClient extends ChangeNotifier {
  RealtimeClient(this._api);

  final ApiClient _api;
  http.Client? _httpClient;
  StreamSubscription<List<int>>? _sseSubscription;
  Timer? _pollTimer;
  Timer? _refreshDebounce;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _useSse = true;
  String _sseBuffer = '';
  final Set<String> _seenMatchGroupIds = {};
  final List<DirectMessageListener> _directMessageListeners = [];
  final List<DirectChatReadListener> _directChatReadListeners = [];
  final List<GroupUpdateListener> _groupUpdateListeners = [];
  final List<GroupChatUpdateListener> _groupChatUpdateListeners = [];

  List<PrimeNotification> items = [];
  int unreadCount = 0;
  String? error;

  void Function(String groupId)? onMatch;
  void Function(String groupId)? onGroupUpdate;
  VoidCallback? onNotificationPush;
  VoidCallback? onWaitingRoomUpdate;

  void addDirectMessageListener(DirectMessageListener listener) {
    if (!_directMessageListeners.contains(listener)) {
      _directMessageListeners.add(listener);
    }
  }

  void removeDirectMessageListener(DirectMessageListener listener) {
    _directMessageListeners.remove(listener);
  }

  void addDirectChatReadListener(DirectChatReadListener listener) {
    if (!_directChatReadListeners.contains(listener)) {
      _directChatReadListeners.add(listener);
    }
  }

  void removeDirectChatReadListener(DirectChatReadListener listener) {
    _directChatReadListeners.remove(listener);
  }

  void addGroupUpdateListener(GroupUpdateListener listener) {
    if (!_groupUpdateListeners.contains(listener)) {
      _groupUpdateListeners.add(listener);
    }
  }

  void removeGroupUpdateListener(GroupUpdateListener listener) {
    _groupUpdateListeners.remove(listener);
  }

  void addGroupChatUpdateListener(GroupChatUpdateListener listener) {
    if (!_groupChatUpdateListeners.contains(listener)) {
      _groupChatUpdateListeners.add(listener);
    }
  }

  void removeGroupChatUpdateListener(GroupChatUpdateListener listener) {
    _groupChatUpdateListeners.remove(listener);
  }

  void _emitDirectMessage(DirectMessagePush push) {
    for (final listener in List<DirectMessageListener>.from(_directMessageListeners)) {
      listener(push);
    }
  }

  void _emitDirectChatRead(DirectChatReadPush push) {
    for (final listener in List<DirectChatReadListener>.from(_directChatReadListeners)) {
      listener(push);
    }
  }

  void _emitGroupUpdate(GroupUpdatePush push) {
    for (final listener in List<GroupUpdateListener>.from(_groupUpdateListeners)) {
      listener(push);
    }
  }

  void _emitGroupChatUpdate(GroupChatUpdatePush push) {
    for (final listener
        in List<GroupChatUpdateListener>.from(_groupChatUpdateListeners)) {
      listener(push);
    }
  }

  void start() {
    stop();
    _useSse = true;
    unawaited(_connectSse());
    unawaited(refresh());
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_useSse) unawaited(refresh());
    });
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _refreshDebounce?.cancel();
    _refreshDebounce = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    unawaited(_sseSubscription?.cancel());
    _sseSubscription = null;
    _httpClient?.close();
    _httpClient = null;
    _sseBuffer = '';
  }

  void _applyNotificationPush(PrimeNotification notification) {
    if (notification.id.isEmpty) return;
    if (items.any((item) => item.id == notification.id)) return;
    items = [notification, ...items];
    if (!notification.read) unreadCount++;
    notifyListeners();
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    if (_disposed) return;
    try {
      final data = await _api.listNotifications();
      final parsed = NotificationListResponse.fromJson(data);
      items = parsed.items;
      unreadCount = parsed.unreadCount;
      error = null;
    } catch (e) {
      error = FailureMapper.from(e).message;
    }
    if (!_disposed) notifyListeners();
  }

  void _markReadLocally(String notificationId) {
    final index = items.indexWhere((item) => item.id == notificationId);
    if (index == -1) return;
    final current = items[index];
    if (current.read) return;
    items = [
      ...items.sublist(0, index),
      PrimeNotification(
        id: current.id,
        type: current.type,
        title: current.title,
        body: current.body,
        read: true,
        createdAt: current.createdAt,
        payload: current.payload,
      ),
      ...items.sublist(index + 1),
    ];
    unreadCount = unreadCount > 0 ? unreadCount - 1 : 0;
    notifyListeners();
  }

  void removeNotificationLocally(String notificationId) {
    final index = items.indexWhere((item) => item.id == notificationId);
    if (index == -1) return;
    final wasUnread = !items[index].read;
    items = [
      ...items.sublist(0, index),
      ...items.sublist(index + 1),
    ];
    if (wasUnread && unreadCount > 0) unreadCount--;
    notifyListeners();
  }

  Future<void> markRead(String notificationId) async {
    _markReadLocally(notificationId);
    try {
      await _api.markNotificationRead(notificationId);
    } catch (_) {
      unawaited(refresh());
    }
  }

  Future<void> markAllRead() async {
    items = [
      for (final item in items)
        PrimeNotification(
          id: item.id,
          type: item.type,
          title: item.title,
          body: item.body,
          read: true,
          createdAt: item.createdAt,
          payload: item.payload,
        ),
    ];
    unreadCount = 0;
    notifyListeners();
    try {
      await _api.markAllNotificationsRead();
    } catch (_) {
      unawaited(refresh());
    }
  }

  Future<void> _connectSse() async {
    final token = _api.authToken;
    if (token == null || token.isEmpty) {
      _useSse = false;
      return;
    }

    final client = http.Client();
    _httpClient = client;
    final request = http.Request('GET', Uri.parse(_api.eventsStreamUrl));
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Cache-Control'] = 'no-cache';

    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        _useSse = false;
        client.close();
        _httpClient = null;
        return;
      }

      _sseSubscription = response.stream.listen(
        _onSseBytes,
        onError: (_) {
          _useSse = false;
          _scheduleRefresh();
          _scheduleSseReconnect();
        },
        onDone: () {
          _useSse = false;
          _scheduleSseReconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _useSse = false;
      client.close();
      _httpClient = null;
      _scheduleSseReconnect();
    }
  }

  void _scheduleSseReconnect() {
    if (_disposed || _reconnectTimer != null) return;
    _reconnectTimer = Timer(const Duration(seconds: 1), () {
      _reconnectTimer = null;
      if (_disposed) return;
      _useSse = true;
      unawaited(_connectSse());
    });
  }

  void _onSseBytes(List<int> bytes) {
    _sseBuffer += utf8.decode(bytes, allowMalformed: true);
    while (true) {
      final boundary = _sseBuffer.indexOf('\n\n');
      if (boundary == -1) break;

      final block = _sseBuffer.substring(0, boundary);
      _sseBuffer = _sseBuffer.substring(boundary + 2);
      _handleSseBlock(block);
    }
  }

  void _handleSseBlock(String block) {
    if (block.startsWith(':')) return;

    String? eventName;
    final dataLines = <String>[];
    for (final rawLine in block.split('\n')) {
      final line = rawLine.trimRight();
      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }
    if (dataLines.isEmpty) return;

    final rawData = dataLines.join('\n');
    if (eventName == 'match') {
      try {
        final payload = jsonDecode(rawData) as Map<String, dynamic>;
        final groupId = payload['group_id'] as String? ?? '';
        if (groupId.isNotEmpty && _seenMatchGroupIds.add(groupId)) {
          onMatch?.call(groupId);
        }
      } catch (_) {}
      _scheduleRefresh();
      return;
    }

    if (eventName == 'direct_message') {
      try {
        final payload = jsonDecode(rawData) as Map<String, dynamic>;
        final friendId = payload['friend_id'] as String? ?? '';
        if (friendId.isNotEmpty) {
          Map<String, dynamic>? message;
          final rawMessage = payload['message'];
          if (rawMessage is Map) {
            message = Map<String, dynamic>.from(rawMessage);
          }
          _emitDirectMessage(DirectMessagePush(
            friendId: friendId,
            message: message,
          ));
          final msgtype = message?['msgtype'] as String? ?? '';
          if (msgtype == 'prime.pair_invite') {
            onWaitingRoomUpdate?.call();
          }
        }
      } catch (_) {}
      return;
    }

    if (eventName == 'waiting_room_update') {
      onWaitingRoomUpdate?.call();
      return;
    }

    if (eventName == 'group_update') {
      try {
        final payload = jsonDecode(rawData) as Map<String, dynamic>;
        final groupId = payload['group_id'] as String? ?? '';
        if (groupId.isNotEmpty) {
          _emitGroupUpdate(GroupUpdatePush(groupId: groupId));
          onGroupUpdate?.call(groupId);
        }
      } catch (_) {}
      return;
    }

    if (eventName == 'group_chat_update') {
      try {
        final payload = jsonDecode(rawData) as Map<String, dynamic>;
        final groupId = payload['group_id'] as String? ?? '';
        if (groupId.isNotEmpty) {
          _emitGroupChatUpdate(GroupChatUpdatePush(groupId: groupId));
        }
      } catch (_) {}
      return;
    }

    if (eventName == 'direct_chat_read') {
      try {
        final payload = jsonDecode(rawData) as Map<String, dynamic>;
        final friendId = payload['friend_id'] as String? ?? '';
        final readAtRaw = payload['read_at'] as String? ?? '';
        final readAt = DateTime.tryParse(readAtRaw);
        if (friendId.isNotEmpty && readAt != null) {
          _emitDirectChatRead(DirectChatReadPush(
            friendId: friendId,
            readAt: readAt,
          ));
        }
      } catch (_) {}
      return;
    }

    if (eventName == 'notification' || eventName == null) {
      try {
        final payload = jsonDecode(rawData) as Map<String, dynamic>;
        _applyNotificationPush(PrimeNotification.fromJson(payload));
        if (payload['type'] == 'match') {
          final matchPayload = payload['payload'];
          if (matchPayload is Map) {
            final groupId = matchPayload['group_id'] as String? ?? '';
            if (groupId.isNotEmpty && _seenMatchGroupIds.add(groupId)) {
              onMatch?.call(groupId);
            }
          }
        }
      } catch (_) {}
      onNotificationPush?.call();
      return;
    }
  }

  @visibleForTesting
  void ingestSseBlockForTest(String block) => _handleSseBlock(block);

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
