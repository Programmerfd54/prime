import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/errors/app_failure.dart';
import '../core/errors/failure_mapper.dart';
import '../core/groups/group_navigation.dart';
import '../core/sync/realtime_client.dart';
import '../data/api_client.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import '../models/notification.dart';
import '../providers/chats_inbox_provider.dart';
import 'notification_center_sheet.dart';

class NotificationBellButton extends StatefulWidget {
  final bool hasUnread;
  final double iconSize;
  final VoidCallback? onOpenGroups;
  final NotificationNavigateCallback? onNavigate;

  const NotificationBellButton({
    super.key,
    this.hasUnread = false,
    this.iconSize = 34,
    this.onOpenGroups,
    this.onNavigate,
  });

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shake;
  late final Animation<double> _glow;
  bool _hasUnread = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -0.18), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.18, end: 0.16), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.16, end: -0.12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.12, end: 0.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _glow = Tween<double>(begin: 0.10, end: 0.28).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _hasUnread = widget.hasUnread;
    if (_hasUnread) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant NotificationBellButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final unread = context.read<RealtimeClient>().unreadCount;
    _setUnread(widget.hasUnread || unread > 0);
  }

  void _setUnread(bool value) {
    if (_hasUnread == value) return;
    setState(() => _hasUnread = value);
    final reduceMotion = mounted && AppMotion.reduce(context);
    if (value && !reduceMotion) {
      _controller
        ..reset()
        ..repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..reset();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final unread = context.watch<RealtimeClient>().unreadCount;
    _setUnread(widget.hasUnread || unread > 0);
    if (AppMotion.reduce(context) && _controller.isAnimating) {
      _controller
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String?> _resolveFriendRequestId(PrimeNotification notification) async {
    final direct = notification.requestId;
    if (direct != null && direct.isNotEmpty) return direct;

    final api = context.read<ApiClient>();
    final raw = await api.listFriendRequests();
    if (!mounted) return null;
    final requests = raw['requests'] as List<dynamic>? ?? const [];
    final requesterId = notification.requesterId;
    final nickname = notification.requesterNickname ?? notification.title;

    for (final item in requests) {
      if (item is! Map) continue;
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) continue;
      if (requesterId != null &&
          item['requester'] is Map &&
          item['requester']['id']?.toString() == requesterId) {
        return id;
      }
      if (item['requester'] is Map &&
          item['requester']['nickname']?.toString() == nickname) {
        return id;
      }
    }
    return null;
  }

  Future<void> _respondFriendRequest(
    PrimeNotification notification,
    bool accept,
  ) async {
    final api = context.read<ApiClient>();
    final realtime = context.read<RealtimeClient>();
    final requestId = await _resolveFriendRequestId(notification);
    if (!mounted) return;
    if (requestId == null || requestId.isEmpty) {
      throw const NotFoundFailure(
        message: 'Заявка уже обработана или недоступна',
      );
    }
    try {
      await api.respondFriendRequest(requestId, accept);
    } catch (e) {
      final failure = FailureMapper.from(e);
      if (failure is NotFoundFailure) {
        unawaited(realtime.refresh());
        throw const NotFoundFailure(
          message: 'Заявка уже обработана или недоступна',
        );
      }
      rethrow;
    }
    if (!mounted) return;
    if (accept) {
      final inbox = context.read<ChatsInboxProvider>();
      inbox.invalidate();
      unawaited(inbox.ensureLoaded(force: true));
    }
    unawaited(realtime.markRead(notification.id));
    if (accept && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _navigateFromNotification(PrimeNotification notification) {
    final payload = {
      ...notification.payload,
      'group_id': notification.groupId ?? notification.payload['group_id'],
      'type': notification.rawType,
    };
    final intent = parsePushPayload(payload);
    if (widget.onNavigate != null) {
      widget.onNavigate!(
        groupId: intent.groupId,
        skillId: intent.skillId,
        preferSearchTab: intent.preferSearchTab,
      );
      return;
    }
    widget.onOpenGroups?.call();
  }

  Future<void> _onNotificationTap(PrimeNotification notification) async {
    final realtime = context.read<RealtimeClient>();
    if (!notification.read) {
      await realtime.markRead(notification.id);
    }
    if (!mounted) return;

    if (notification.type == PrimeNotificationType.friendRequest) {
      return;
    }

    Navigator.of(context).pop();
    _navigateFromNotification(notification);
  }

  Future<void> _showNotifications() async {
    await showNotificationCenterSheet(
      context: context,
      onOpenGroups: widget.onOpenGroups,
      onItemTap: _onNotificationTap,
      onRespondFriend: _respondFriendRequest,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _hasUnread ? AppColors.gold : AppColors.textPrimary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glow = _hasUnread ? _glow.value : 0.0;
        return Transform.rotate(
          angle: _hasUnread ? _shake.value * 0.55 : 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                if (_hasUnread)
                  BoxShadow(
                    color: AppColors.goldGlow.withValues(alpha: glow),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            tooltip: 'Уведомления',
            iconSize: widget.iconSize,
            onPressed: _showNotifications,
            icon: Icon(Icons.notifications_outlined, color: color),
          ),
          if (_hasUnread) ...[
            const Positioned(
              right: 11,
              top: 10,
              child: _NotificationDot(),
            ),
            Positioned(
              left: 11,
              top: 12,
              child: Transform.rotate(
                angle: -math.pi / 5,
                child: Container(
                  width: 10,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationDot extends StatelessWidget {
  const _NotificationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: AppColors.goldHighlight,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.textPrimary, width: 1.3),
      ),
    );
  }
}
