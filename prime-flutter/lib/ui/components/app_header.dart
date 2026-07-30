import 'package:flutter/material.dart';

import '../../design/routes.dart';
import '../../design/theme/prime_theme_context.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../kit/tokens/kit_typography.dart';
import '../../screens/account_settings_screen.dart';
import '../../widgets/notification_bell_button.dart';
import 'app_icon_button.dart';

/// Root tab header — large title left, 1–2 actions right.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showSettingsAction = false,
    this.hasUnreadNotification = false,
    this.onOpenGroups,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final bool showSettingsAction;
  final bool hasUnreadNotification;
  final VoidCallback? onOpenGroups;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.largeTitle.copyWith(fontSize: 28),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    style: AppTypography.bodySecondary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          trailing ??
              (showSettingsAction
                  ? AppIconButton(
                      tooltip: 'Настройки',
                      icon: Icons.settings_outlined,
                      backgroundColor: AppColors.elevatedSurface,
                      onPressed: () {
                        Navigator.of(context).push(
                          PrimeRoute.sharedAxis(
                            builder: (_) => const AccountSettingsScreen(),
                          ),
                        );
                      },
                    )
                  : NotificationBellButton(
                      hasUnread: hasUnreadNotification,
                      onOpenGroups: onOpenGroups,
                    )),
        ],
      ),
    );
  }
}

/// Consistent back app bar for push routes.
PreferredSizeWidget buildAppBackBar(
  BuildContext context, {
  required String title,
  List<Widget>? actions,
  VoidCallback? onBack,
  TextStyle? titleStyle,
}) {
  return AppBar(
    leading: IconButton(
      tooltip: 'Назад',
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: AppIconSizes.sm),
      onPressed: onBack ?? () => Navigator.of(context).maybePop(),
    ),
    title: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: titleStyle ?? AppTypography.title2.copyWith(fontSize: 18),
    ),
    actions: actions,
  );
}

/// Chat-style app bar with avatar + name.
class AppChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppChatAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.avatar,
    this.onTitleTap,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final Widget? avatar;
  final VoidCallback? onTitleTap;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return AppBar(
      backgroundColor: p.surface.withValues(alpha: 0.96),
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: Border(bottom: BorderSide(color: p.hairline)),
      leading: IconButton(
        tooltip: 'Назад',
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: AppIconSizes.sm, color: p.ink),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      titleSpacing: 0,
      title: InkWell(
        onTap: onTitleTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Row(
          children: [
            if (avatar != null) ...[
              avatar!,
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KitTypography.title2.copyWith(fontSize: 18, color: p.ink),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(color: p.inkMuted),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: actions,
    );
  }
}
