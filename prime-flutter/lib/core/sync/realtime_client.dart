import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../data/api_client.dart';
import '../../models/notification.dart';
import '../errors/app_failure.dart';
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
  const GroupUpdatePush({
    required this.groupId,
    this.revision = 0,
    this.phase = '',
    this.reason = 'updated',
    this.milestoneId,
  });

  final String groupId;
  final int revision;
  final String phase;
  final String reason;
  final String? milestoneId;
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
  bool _sseConnected = false;
  String _sseBuffer = '';
  final Set<String> _seenMatchGroupIds = {};
  final Map<String, int> _groupRevisions = {};
  final Map<String, int> _waitingRevisions = {};
  final List<DirectMessageListener> _directMessageListeners = [];
  final List<DirectChatReadListener> _directChatReadListeners = [];
  final List<GroupUpdateListener> _groupUpdateListeners = [];
  final List<GroupChatUpdateListener> _groupChatUpdateListeners = [];
  final Set<String> _locallyRemovedIds = {};
  int _refreshGeneration = 0;
  bool _clearAllPending = false;

  List<PrimeNotification> items = [];
  int unreadCount = 0;
  String? error;

  bool get isSseConnected => _sseConnected;

  void _setSseConnected(bool value) {
    if (_sseConnected == value) return;
    _sseConnected = value;
    if (!_disposed) notifyListeners();
  }

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
    for (final listener
        in List<DirectMessageListener>.from(_directMessageListeners)) {
      listener(push);
    }
  }

  void _emitDirectChatRead(DirectChatReadPush push) {
    for (final listener
        in List<DirectChatReadListener>.from(_directChatReadListeners)) {
      listener(push);
    }
  }

  void _emitGroupUpdate(GroupUpdatePush push) {
    for (final listener
        in List<GroupUpdateListener>.from(_groupUpdateListeners)) {
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
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
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
    _setSseConnected(false);
  }

  void _applyNotificationPush(PrimeNotification notification) {
    if (notification.id.isEmpty) return;
    if (_locallyRemovedIds.contains(notification.id)) return;
    if (_clearAllPending) return;
    if (items.any((item) => item.id == notification.id)) return;
    items = [notification, ...items];
    if (!notification.read) unreadCount++;
    notifyListeners();
  }

  List<PrimeNotification> _filterRemoved(List<PrimeNotification> source) {
    if (_clearAllPending) return const [];
    if (_locallyRemovedIds.isEmpty) return source;
    return source
        .where((item) => !_locallyRemovedIds.contains(item.id))
        .toList();
  }

  int _countUnread(Iterable<PrimeNotification> source) =>
      source.where((item) => !item.read).length;

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    if (_disposed) return;
    final generation = ++_refreshGeneration;
    try {
      final data = await _api.listNotifications();
      if (_disposed || generation != _refreshGeneration) return;
      final parsed = NotificationListResponse.fromJson(data);
      items = _filterRemoved(parsed.items);
      unreadCount = _countUnread(items);
      error = null;
    } catch (e) {
      if (_disposed || generation != _refreshGeneration) return;
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
        rawType: current.rawType,
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
          rawType: item.rawType,
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

  Future<void> dismissNotification(String notificationId) async {
    if (notificationId.isEmpty) return;
    _refreshGeneration++;
    _locallyRemovedIds.add(notificationId);
    removeNotificationLocally(notificationId);
    try {
      await _api.deleteNotification(notificationId);
      _locallyRemovedIds.remove(notificationId);
    } catch (e) {
      _locallyRemovedIds.remove(notificationId);
      final failure = FailureMapper.from(e);
      if (failure is NotFoundFailure) {
        return;
      }
      unawaited(refresh());
      rethrow;
    }
  }

  Future<void> clearAllNotifications() async {
    if (_clearAllPending) return;
    _refreshGeneration++;
    _clearAllPending = true;
    _locallyRemovedIds.addAll(items.map((item) => item.id));
    items = [];
    unreadCount = 0;
    notifyListeners();
    try {
      await _api.clearAllNotifications();
      _locallyRemovedIds.clear();
    } catch (e) {
      _clearAllPending = false;
      _locallyRemovedIds.clear();
      unawaited(refresh());
      rethrow;
    } finally {
      _clearAllPending = false;
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

    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        _useSse = false;
        client.close();
        _httpClient = null;
        return;
      }
      _setSseConnected(true);

      _sseSubscription = response.stream.listen(
        _onSseBytes,
        onError: (_) {
          _useSse = false;
          _setSseConnected(false);
          _scheduleRefresh();
          _scheduleSseReconnect();
        },
        onDone: () {
          _useSse = false;
          _setSseConnected(false);
          _scheduleSseReconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _useSse = false;
      _setSseConnected(false);
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
      try {
        final payload = jsonDecode(rawData) as Map<String, dynamic>;
        final skillId = payload['skill_id'] as String? ?? '';
        final revision = payload['revision'] as int? ?? 0;
        if (skillId.isNotEmpty && revision > 0) {
          final known = _waitingRevisions[skillId] ?? -1;
          if (revision <= known) return;
          _waitingRevisions[skillId] = revision;
        }
      } catch (_) {}
      onWaitingRoomUpdate?.call();
      return;
    }

    if (eventName == 'group_update') {
      try {
        final payload = jsonDecode(rawData) as Map<String, dynamic>;
        final groupId = payload['group_id'] as String? ?? '';
        if (groupId.isNotEmpty) {
          final revision = payload['revision'] as int? ?? 0;
          final reason = payload['reason'] as String? ?? 'updated';
          final knownRevision = _groupRevisions[groupId] ?? -1;
          if (revision > 0 &&
              revision <= knownRevision &&
              reason != 'cycle_started') {
            return;
          }
          if (revision > 0) _groupRevisions[groupId] = revision;
          _emitGroupUpdate(GroupUpdatePush(
            groupId: groupId,
            revision: revision,
            phase: payload['phase'] as String? ?? '',
            reason: reason,
            milestoneId: payload['milestone_id'] as String?,
          ));
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
        final notification = PrimeNotification.fromJson(payload);
        _applyNotificationPush(notification);
        if (notification.rawType == 'early_start_request') {
          onWaitingRoomUpdate?.call();
        }
        if (notification.rawType == 'group_phase') {
          final phase = notification.payload['phase'] as String? ?? '';
          final groupId = notification.groupId ?? '';
          if (groupId.isNotEmpty && phase == 'active') {
            _emitGroupUpdate(GroupUpdatePush(
              groupId: groupId,
              phase: phase,
              reason: 'cycle_started',
            ));
            onGroupUpdate?.call(groupId);
          }
        }
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
