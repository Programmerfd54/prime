import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/sync/realtime_client.dart';
import '../data/api_client.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../models/notification.dart';
import '../ui/components/app_compact_button.dart';

class NotificationBellButton extends StatefulWidget {
  final bool hasUnread;
  final double iconSize;
  final VoidCallback? onOpenGroups;

  const NotificationBellButton({
    super.key,
    this.hasUnread = false,
    this.iconSize = 34,
    this.onOpenGroups,
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

  Future<void> _respondFriendRequest(
    PrimeNotification notification,
    bool accept,
  ) async {
    final requestId = notification.requestId;
    if (requestId == null || requestId.isEmpty) return;
    final api = context.read<ApiClient>();
    final realtime = context.read<RealtimeClient>();
    await api.respondFriendRequest(requestId, accept);
    await realtime.markRead(notification.id);
    if (mounted) {
      Navigator.of(context).pop();
      await _showNotifications();
    }
  }

  Future<void> _onNotificationTap(PrimeNotification notification) async {
    final realtime = context.read<RealtimeClient>();
    if (!notification.read) {
      await realtime.markRead(notification.id);
    }
    if (!mounted) return;

    if (notification.type == PrimeNotificationType.match) {
      Navigator.of(context).pop();
      widget.onOpenGroups?.call();
      return;
    }

    if (notification.type == PrimeNotificationType.friendRequest) {
      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _showNotifications() async {
    final realtime = context.read<RealtimeClient>();
    await realtime.refresh();
    if (!mounted) return;

    final items = realtime.items;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Уведомления', style: AppTypography.title1),
                    ),
                    if (realtime.unreadCount > 0)
                      TextButton(
                        onPressed: () async {
                          await realtime.markAllRead();
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                        child: Text(
                          'Прочитать все',
                          style: AppTypography.button.copyWith(
                            color: AppColors.gold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Text(
                      'Новых уведомлений нет',
                      style: AppTypography.bodySecondary,
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: AppColors.border,
                      ),
                      itemBuilder: (context, index) {
                        final notification = items[index];
                        if (notification.type == PrimeNotificationType.friendRequest) {
                          return _FriendRequestNotificationTile(
                            notification: notification,
                            onAccept: () =>
                                _respondFriendRequest(notification, true),
                            onDecline: () =>
                                _respondFriendRequest(notification, false),
                          );
                        }
                        return _NotificationTile(
                          notification: notification,
                          onTap: () => _onNotificationTap(notification),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final PrimeNotification notification;
  final VoidCallback onTap;

  IconData _iconForType() {
    return switch (notification.type) {
      PrimeNotificationType.match => Icons.groups_2_outlined,
      PrimeNotificationType.mention => Icons.alternate_email,
      PrimeNotificationType.support => Icons.favorite_outline,
      PrimeNotificationType.system => Icons.info_outline,
      PrimeNotificationType.friendRequest => Icons.person_add_alt_1_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          _iconForType(),
          color: notification.read ? AppColors.textSecondary : AppColors.gold,
        ),
        title: Text(
          notification.title,
          style: AppTypography.title2.copyWith(
            fontSize: 15,
            color: notification.read
                ? AppColors.textSecondary
                : AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          notification.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySecondary,
        ),
        trailing: notification.read
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.goldHighlight,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: onTap,
      ),
    );
  }
}

class _FriendRequestNotificationTile extends StatelessWidget {
  const _FriendRequestNotificationTile({
    required this.notification,
    required this.onAccept,
    required this.onDecline,
  });

  final PrimeNotification notification;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  String? _avatarUrl() {
    final nickname = notification.payload['requester_nickname'] as String?;
    if (nickname == null || nickname.isEmpty) return null;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final name = notification.title.isEmpty ? 'Пользователь' : notification.title;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.elevatedSurface,
            foregroundColor: AppColors.textPrimary,
            backgroundImage: _avatarUrl() == null
                ? null
                : NetworkImage(_avatarUrl()!),
            child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$name добавляется в друзья',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.title2.copyWith(fontSize: 15),
            ),
          ),
          AppCompactButton(label: 'Принять', onPressed: onAccept),
          const SizedBox(width: AppSpacing.xs),
          AppCompactButton(
            label: 'Отклонить',
            primary: false,
            onPressed: onDecline,
          ),
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
