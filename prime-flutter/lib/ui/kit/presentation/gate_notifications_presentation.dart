import 'package:flutter/material.dart';

import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../models/notification.dart';
import '../../components/app_compact_button.dart';
import '../components/prime_content_card.dart';
import '../components/prime_empty_state.dart';
import '../tokens/kit_typography.dart';

/// Relative time label for notification rows.
String formatNotificationTime(DateTime at) {
  final local = at.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  if (diff == 0) return '$hh:$mm';
  if (diff == 1) return 'Вчера';
  final dd = local.day.toString().padLeft(2, '0');
  final mo = local.month.toString().padLeft(2, '0');
  return '$dd.$mo';
}

/// V6 notification center sheet — solid surfaces, actionable rows.
class GateNotificationCenterSheet extends StatelessWidget {
  const GateNotificationCenterSheet({
    super.key,
    required this.items,
    required this.unreadCount,
    this.loading = false,
    this.onRefresh,
    this.onMarkAllRead,
    this.onItemTap,
    this.onAcceptFriend,
    this.onDeclineFriend,
    this.respondingId,
    this.respondingAccept,
  });

  final List<PrimeNotification> items;
  final int unreadCount;
  final bool loading;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onMarkAllRead;
  final ValueChanged<PrimeNotification>? onItemTap;
  final ValueChanged<PrimeNotification>? onAcceptFriend;
  final ValueChanged<PrimeNotification>? onDeclineFriend;
  final String? respondingId;
  final bool? respondingAccept;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              decoration: BoxDecoration(
                color: p.hairlineStrong,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Уведомления',
                  style: AppTypography.title1.copyWith(color: p.ink),
                ),
              ),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: p.brandContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '$unreadCount',
                    style: KitTypography.caption.copyWith(
                      color: p.brand,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (loading)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: p.brand,
                    ),
                  ),
                )
              else if (onRefresh != null)
                IconButton(
                  tooltip: 'Обновить',
                  onPressed: onRefresh,
                  icon: Icon(Icons.refresh_rounded, color: p.inkMuted, size: 22),
                ),
              if (unreadCount > 0 && onMarkAllRead != null)
                TextButton(
                  onPressed: onMarkAllRead,
                  child: Text(
                    'Прочитать все',
                    style: KitTypography.caption.copyWith(color: p.brand),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: PrimeEmptyState(
                title: 'Новых уведомлений нет',
                body: 'Заявки в друзья, матчи команды и события появятся здесь.',
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final notification = items[index];
                  if (notification.type == PrimeNotificationType.friendRequest) {
                    final key = notification.requestId ?? notification.id;
                    final responding = respondingId == key;
                    return _FriendRequestRow(
                      notification: notification,
                      acceptLoading: responding && respondingAccept == true,
                      declineLoading: responding && respondingAccept == false,
                      disabled: respondingId != null,
                      onAccept: onAcceptFriend == null
                          ? null
                          : () => onAcceptFriend!(notification),
                      onDecline: onDeclineFriend == null
                          ? null
                          : () => onDeclineFriend!(notification),
                    );
                  }
                  return _NotificationRow(
                    notification: notification,
                    onTap: onItemTap == null
                        ? null
                        : () => onItemTap!(notification),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, this.onTap});

  final PrimeNotification notification;
  final VoidCallback? onTap;

  IconData get _icon => switch (notification.type) {
        PrimeNotificationType.match => Icons.groups_2_outlined,
        PrimeNotificationType.mention => Icons.alternate_email,
        PrimeNotificationType.support => Icons.favorite_outline,
        PrimeNotificationType.friendRequest => Icons.person_add_alt_1_outlined,
        PrimeNotificationType.system => Icons.info_outline,
      };

  String get _semanticsLabel {
    final time = formatNotificationTime(notification.createdAt);
    final read = notification.read ? '' : ', непрочитано';
    return '${notification.title}. ${notification.body}. $time$read';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final unread = !notification.read;
    return Semantics(
      button: onTap != null,
      label: _semanticsLabel,
      child: PrimeContentCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: p.surfaceSoft,
                borderRadius: BorderRadius.circular(AppRadius.button),
                border: Border.all(color: p.hairline),
              ),
              child: Icon(
                _icon,
                size: 20,
                color: unread ? p.achievementAmber : p.inkMuted,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: KitTypography.cardTitle.copyWith(
                            color: unread ? p.ink : p.inkSecondary,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        formatNotificationTime(notification.createdAt),
                        style: KitTypography.caption.copyWith(
                          color: p.inkMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: KitTypography.caption.copyWith(color: p.inkMuted),
                  ),
                ],
              ),
            ),
            if (unread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6, left: 4),
                decoration: BoxDecoration(
                  color: p.achievementAmber,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FriendRequestRow extends StatelessWidget {
  const _FriendRequestRow({
    required this.notification,
    this.onAccept,
    this.onDecline,
    this.acceptLoading = false,
    this.declineLoading = false,
    this.disabled = false,
  });

  final PrimeNotification notification;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final bool acceptLoading;
  final bool declineLoading;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return PrimeContentCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  notification.title,
                  style: KitTypography.cardTitle.copyWith(color: p.ink, fontSize: 15),
                ),
              ),
              Text(
                formatNotificationTime(notification.createdAt),
                style: KitTypography.caption.copyWith(color: p.inkMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            notification.body,
            style: KitTypography.caption.copyWith(color: p.inkMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppCompactButton(
                  label: 'Принять',
                  loading: acceptLoading,
                  onPressed: disabled && !acceptLoading ? null : onAccept,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: AppCompactButton(
                  label: 'Отклонить',
                  primary: false,
                  loading: declineLoading,
                  onPressed: disabled && !declineLoading ? null : onDecline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Demo notifications for gate tests.
List<PrimeNotification> gateDemoNotifications() => [
      PrimeNotification(
        id: 'n1',
        type: PrimeNotificationType.match,
        title: 'Команда собрана',
        body: 'Подтвердите участие в «Утренний фокус»',
        read: false,
        createdAt: DateTime(2026, 7, 29, 10, 30),
        payload: const {},
      ),
      PrimeNotification(
        id: 'n2',
        type: PrimeNotificationType.friendRequest,
        title: 'Ivan',
        body: 'Хочет добавить вас в друзья',
        read: true,
        createdAt: DateTime(2026, 7, 28, 18, 0),
        payload: const {'requester_nickname': 'ivan', 'request_id': 'req-1'},
      ),
    ];
