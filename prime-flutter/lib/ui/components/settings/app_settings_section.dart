import 'package:flutter/material.dart';

import '../../../design/theme/prime_theme_context.dart';
import '../../../design/haptics.dart';
import '../../../design/pressable.dart';
import '../../../design/tokens.dart';
import '../../kit/tokens/kit_typography.dart';
import '../../kit/components/prime_content_card.dart';

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
    final p = context.prime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xxs),
          child: Text(
            title,
            style: KitTypography.sectionTitle.copyWith(
              color: p.ink,
              fontSize: 20,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        PrimeContentCard(
          padding: EdgeInsets.zero,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, indent: 56, color: p.hairline),
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
    final p = context.prime;
    final color = destructive
        ? p.coral
        : enabled
            ? p.brandSoft
            : p.inkMuted;

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
          color: p.surfaceSoft,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: p.hairline),
        ),
        child: Icon(icon, color: color, size: AppIconSizes.sm),
      ),
      title: Text(
        title,
        style: KitTypography.cardTitle.copyWith(
          color: destructive ? p.coral : p.ink,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: KitTypography.caption.copyWith(color: p.inkMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: trailing ??
          (onTap != null && enabled
              ? Icon(Icons.chevron_right_rounded, color: p.inkMuted, size: 22)
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
    final p = context.prime;
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
            color: p.surfaceSoft,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: p.hairline),
          ),
          child: Icon(
            icon,
            color: p.brandSoft,
            size: AppIconSizes.sm,
          ),
        ),
        title: Text(
          title,
          style: KitTypography.cardTitle.copyWith(color: p.ink),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: KitTypography.caption.copyWith(color: p.inkMuted),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
        trailing: Switch.adaptive(
          value: value,
          onChanged: (v) {
            AppHaptics.selection();
            onChanged(v);
          },
          activeThumbColor: p.brand,
          activeTrackColor: p.brand.withValues(alpha: 0.28),
        ),
      ),
    );
  }
}
