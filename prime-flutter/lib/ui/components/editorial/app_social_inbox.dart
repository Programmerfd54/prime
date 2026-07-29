import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../design/haptics.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';

/// Premium chat inbox row — not a bordered list item.
class AppSocialInboxRow extends StatelessWidget {
  const AppSocialInboxRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.initial,
    this.avatarUrl,
    this.time,
    this.unread = 0,
    this.onTap,
    this.accentColor,
    this.onMarkRead,
  });

  final String title;
  final String subtitle;
  final String initial;
  final String? avatarUrl;
  final String? time;
  final int unread;
  final VoidCallback? onTap;
  final Color? accentColor;
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.primary;

    final row = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              _Avatar(
                initial: initial,
                avatarUrl: avatarUrl,
                accent: accent,
                unread: unread > 0,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.title2.copyWith(
                              fontWeight:
                                  unread > 0 ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (time != null)
                          Text(time!, style: AppTypography.caption),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySecondary.copyWith(
                        color: unread > 0
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread > 0) ...[
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: AppGlow.violet(opacity: 0.28),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (onMarkRead == null && unread <= 0) return row;

    return SoftSlidable(
      onMarkRead: onMarkRead ?? () {},
      enabled: onMarkRead != null || unread > 0,
      child: row,
    );
  }
}

class SoftSlidable extends StatelessWidget {
  const SoftSlidable({
    super.key,
    required this.child,
    required this.onMarkRead,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onMarkRead;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Slidable(
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.26,
        children: [
          CustomSlidableAction(
            onPressed: (_) {
              AppHaptics.selection();
              onMarkRead();
            },
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.done_all_rounded, color: AppColors.primarySoft),
                const SizedBox(height: 4),
                Text(
                  'Прочитано',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primarySoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initial,
    required this.accent,
    this.avatarUrl,
    this.unread = false,
  });

  final String initial;
  final String? avatarUrl;
  final Color accent;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          // Keyed by avatarUrl (same pattern as AppAvatar) so a changed URL
          // always rebuilds the image instead of reusing a stale element.
          key: ValueKey(avatarUrl ?? 'empty'),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.35),
                AppColors.elevatedSurface,
              ],
            ),
            border: Border.all(
              color: unread ? accent : AppColors.borderStrong,
              width: unread ? 2 : 1,
            ),
            image: avatarUrl == null
                ? null
                : DecorationImage(
                    image: NetworkImage(avatarUrl!),
                    fit: BoxFit.cover,
                  ),
          ),
          child: avatarUrl == null
              ? Center(
                  child: Text(
                    initial,
                    style: AppTypography.title2.copyWith(color: accent),
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

/// Section header for chat inbox.
class AppSocialSectionHeader extends StatelessWidget {
  const AppSocialSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Text(title, style: AppTypography.title2),
          const Spacer(),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
