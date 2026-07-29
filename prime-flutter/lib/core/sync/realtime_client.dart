import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../data/api_client.dart';
import '../../models/notification.dart';
import '../errors/failure_mapper.dart';

/// Live notifications via SSE with polling fallback.
class RealtimeClient extends ChangeNotifier {
  RealtimeClient(this._api);

  final ApiClient _api;
  http.Client? _httpClient;
  StreamSubscription<List<int>>? _sseSubscription;
  Timer? _pollTimer;
  bool _disposed = false;
  bool _useSse = true;
  String _sseBuffer = '';
  final Set<String> _seenMatchGroupIds = {};

  List<PrimeNotification> items = [];
  int unreadCount = 0;
  String? error;

  void Function(String groupId)? onMatch;

  void start() {
    stop();
    _useSse = true;
    unawaited(_connectSse());
    unawaited(refresh());
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_useSse) unawaited(refresh());
    });
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    unawaited(_sseSubscription?.cancel());
    _sseSubscription = null;
    _httpClient?.close();
    _httpClient = null;
    _sseBuffer = '';
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

  Future<void> markRead(String notificationId) async {
    await _api.markNotificationRead(notificationId);
    await refresh();
  }

  Future<void> markAllRead() async {
    await _api.markAllNotificationsRead();
    await refresh();
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
          unawaited(refresh());
        },
        onDone: () {
          _useSse = false;
        },
        cancelOnError: true,
      );
    } catch (_) {
      _useSse = false;
      client.close();
      _httpClient = null;
    }
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
      unawaited(refresh());
      return;
    }

    if (eventName == 'notification' || eventName == null) {
      unawaited(refresh());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
