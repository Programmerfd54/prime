import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../models/direct_chat.dart';

/// Shared inbox state — dedupes [listDirectChats] across MainShell, ChatsScreen,
/// and Dashboard.
class ChatsInboxProvider extends ChangeNotifier {
  ChatsInboxProvider(this._api);

  final ApiClient _api;

  List<DirectChatSummary> chats = const [];
  int unreadCount = 0;
  DateTime? _lastFetched;
  bool loading = false;
  bool _refreshInFlight = false;

  static const staleAfter = Duration(seconds: 45);

  bool get isStale =>
      _lastFetched == null ||
      DateTime.now().difference(_lastFetched!) > staleAfter;

  Future<void> ensureLoaded({bool force = false}) async {
    if (_refreshInFlight) return;
    if (!force && !isStale && _lastFetched != null) return;

    _refreshInFlight = true;
    try {
      final rows = await _api.listDirectChats(forceRefresh: force);
      chats = rows
          .map((item) =>
              DirectChatSummary.fromJson(item as Map<String, dynamic>))
          .toList();
      unreadCount =
          chats.fold<int>(0, (sum, chat) => sum + chat.unreadCount);
      _lastFetched = DateTime.now();
      unawaited(
        _api.prefetchDirectMessageCaches(
          chats
              .where((chat) => chat.lastMessageBody != null)
              .map((chat) => chat.friend.id)
              .take(6),
        ),
      );
    } catch (_) {
      // Keep stale data if refresh fails.
    } finally {
      _refreshInFlight = false;
      loading = false;
      notifyListeners();
    }
  }

  /// Call after sending/reading in a thread without full inbox reload.
  void patchUnread(String friendId, {int unread = 0}) {
    final idx = chats.indexWhere((c) => c.friend.id == friendId);
    if (idx == -1) return;
    final old = chats[idx];
    if (old.unreadCount == unread) return;
    chats = [
      ...chats.sublist(0, idx),
      DirectChatSummary(
        friend: old.friend,
        lastMessageBody: old.lastMessageBody,
        lastMessageAt: old.lastMessageAt,
        unreadCount: unread,
      ),
      ...chats.sublist(idx + 1),
    ];
    unreadCount =
        chats.fold<int>(0, (sum, chat) => sum + chat.unreadCount);
    notifyListeners();
  }

  void invalidate() {
    _lastFetched = null;
  }
}
