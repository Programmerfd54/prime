import 'package:flutter/material.dart';

import '../../../design/glass.dart';
import '../../../design/haptics.dart';
import '../../../design/pressable.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';

/// Editorial settings group — glass surface, press feedback on tiles.
class AppSettingsSection extends StatelessWidget {
  const AppSettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.footer,
  });

  final String title;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xxs),
          child: Text(title, style: AppTypography.titleSerif),
        ),
        const SizedBox(height: AppSpacing.sm),
        GlassContainer(
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.border,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ),
        if (footer != null) ...[
          const SizedBox(height: AppSpacing.xs),
          footer!,
        ],
      ],
    );
  }
}

/// Settings row with consistent leading icon slot.
class AppSettingsTile extends StatelessWidget {
  const AppSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? AppColors.error
        : enabled
            ? AppColors.primarySoft
            : AppColors.textMuted;

    final tile = ListTile(
      enabled: enabled,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, color: color, size: AppIconSizes.sm),
      ),
      title: Text(
        title,
        style: AppTypography.title2.copyWith(
          color: destructive ? AppColors.error : AppColors.textPrimary,
          fontSize: 16,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: AppTypography.caption),
      trailing: trailing ??
          (onTap != null && enabled
              ? Icon(Icons.chevron_right, color: AppColors.textMuted)
              : null),
    );

    if (onTap == null || !enabled) {
      return Material(color: Colors.transparent, child: tile);
    }

    return PrimePressable(
      haptic: false,
      onTap: () {
        AppHaptics.selection();
        onTap!();
      },
      child: Material(color: Colors.transparent, child: tile),
    );
  }
}

/// Settings row with trailing switch — matches AppSettingsTile layout.
class AppSettingsSwitchTile extends StatelessWidget {
  const AppSettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(
            icon,
            color: AppColors.primarySoft,
            size: AppIconSizes.sm,
          ),
        ),
        title: Text(
          title,
          style: AppTypography.title2.copyWith(fontSize: 16),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: AppTypography.caption,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
        trailing: Switch.adaptive(
          value: value,
          onChanged: (v) {
            AppHaptics.selection();
            onChanged(v);
          },
          activeThumbColor: AppColors.primary,
          activeTrackColor: AppColors.primary.withValues(alpha: 0.28),
        ),
      ),
    );
  }
}
