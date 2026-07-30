import 'package:flutter/material.dart';

import '../../../core/media/media_urls.dart';
import '../../../design/haptics.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../design/visuals/ambient_and_progress.dart';
import '../../kit/components/prime_content_card.dart';
import '../../kit/tokens/kit_surfaces.dart';
import '../../kit/tokens/kit_typography.dart';
import '../app_dialog.dart';
import '../app_header.dart';
import '../app_scaffold.dart';

/// Shared settings page shell — back bar, ambient bg, scroll padding.
class SettingsPageScaffold extends StatelessWidget {
  const SettingsPageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: buildAppBackBar(context, title: title),
      body: AmbientCanvas(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            if (subtitle != null) ...[
              SettingsPageIntro(subtitle: subtitle!),
              const SizedBox(height: AppSpacing.lg),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Short explainer under the nav bar on detail screens.
class SettingsPageIntro extends StatelessWidget {
  const SettingsPageIntro({super.key, required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Text(
      subtitle,
      style: KitTypography.bodySecondary.copyWith(color: context.prime.inkSecondary),
    );
  }
}

/// Hub hero — page title + hint.
class SettingsHubHeader extends StatelessWidget {
  const SettingsHubHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Настройки',
          style: AppTypography.pageTitle.copyWith(color: p.ink, fontSize: 32),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Аккаунт, приватность и приложение',
          style: KitTypography.bodySecondary.copyWith(color: p.inkSecondary),
        ),
      ],
    );
  }
}

/// Hub navigation row — icon, title, summary, chevron.
class SettingsHubCard extends StatelessWidget {
  const SettingsHubCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = KitAccent.brand,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final KitAccent accent;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final iconColor = destructive ? p.coral : accent.resolve(context);
    final titleColor = destructive ? p.coral : p.ink;

    return PrimeContentCard(
      padding: EdgeInsets.zero,
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: destructive
                    ? p.coral.withValues(alpha: 0.12)
                    : iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: destructive
                      ? p.coral.withValues(alpha: 0.22)
                      : iconColor.withValues(alpha: 0.20),
                ),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: KitTypography.cardTitle.copyWith(color: titleColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: KitTypography.caption.copyWith(color: p.inkMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.inkMuted, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Compact user strip on the settings hub.
class SettingsUserStrip extends StatelessWidget {
  const SettingsUserStrip({
    super.key,
    required this.name,
    this.email,
    this.photoUrl,
  });

  final String name;
  final String? email;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final display = name.trim().isEmpty ? 'Профиль' : name.trim();
    final initial = display.isNotEmpty ? display[0].toUpperCase() : '?';

    return PrimeContentCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: p.brandContainer,
            backgroundImage: () {
              final url = absolutePhotoUrl(photoUrl);
              return url != null ? NetworkImage(url) : null;
            }(),
            child: photoUrl == null || photoUrl!.isEmpty
                ? Text(
                    initial,
                    style: KitTypography.cardTitle.copyWith(color: p.brand),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(display, style: KitTypography.cardTitle.copyWith(color: p.ink)),
                if (email != null && email!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email!,
                    style: KitTypography.caption.copyWith(color: p.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Generic segmented control for settings (theme, privacy presets, etc.).
class SettingsSegmentedControl<T extends Object> extends StatelessWidget {
  const SettingsSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
    this.enabled = true,
  });

  final List<T> options;
  final T? selected;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: p.hairline),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: _SegmentSlot<T>(
                label: labelBuilder(options[i]),
                selected: selected != null && options[i] == selected,
                enabled: enabled,
                isFirst: i == 0,
                isLast: i == options.length - 1,
                onTap: () {
                  if (!enabled || options[i] == selected) return;
                  AppHaptics.selection();
                  onSelected(options[i]);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentSlot<T> extends StatelessWidget {
  const _SegmentSlot({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final radius = BorderRadius.horizontal(
      left: isFirst ? const Radius.circular(AppRadius.md) : Radius.zero,
      right: isLast ? const Radius.circular(AppRadius.md) : Radius.zero,
    );

    return Material(
      color: selected ? p.brandContainer : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: KitTypography.caption.copyWith(
              color: selected ? p.brand : p.inkSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom disclosure panel — not Material ExpansionTile.
class SettingsDisclosure extends StatelessWidget {
  const SettingsDisclosure({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return PrimeContentCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () {
              AppHaptics.selection();
              onToggle();
            },
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: KitTypography.cardTitle.copyWith(color: p.ink),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: KitTypography.caption.copyWith(color: p.inkMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Icon(Icons.expand_more_rounded, color: p.inkMuted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeOutCubic,
            sizeCurve: Curves.easeOutCubic,
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                Divider(height: 1, color: p.hairline),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Solid bottom sheet for picking one option (V6 §7.6).
Future<T?> showSettingsPickerSheet<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required List<SettingsPickerOption<T>> options,
}) {
  return showAppBottomSheet<T>(
    context: context,
    child: _SettingsPickerBody<T>(
      title: title,
      subtitle: subtitle,
      options: options,
    ),
  );
}

class SettingsPickerOption<T> {
  const SettingsPickerOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
  });

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
}

class _SettingsPickerBody<T> extends StatelessWidget {
  const _SettingsPickerBody({
    required this.title,
    this.subtitle,
    required this.options,
  });

  final String title;
  final String? subtitle;
  final List<SettingsPickerOption<T>> options;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTypography.title1.copyWith(color: p.ink)),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              subtitle!,
              style: KitTypography.caption.copyWith(color: p.inkMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.xs),
            _PickerRow(option: options[i]),
          ],
        ],
      ),
    );
  }
}

class _PickerRow<T> extends StatelessWidget {
  const _PickerRow({required this.option});

  final SettingsPickerOption<T> option;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AppHaptics.selection();
          Navigator.pop(context, option.value);
        },
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              if (option.icon != null) ...[
                Icon(option.icon, color: p.brandSoft, size: 20),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: KitTypography.cardTitle.copyWith(color: p.ink, fontSize: 16),
                    ),
                    if (option.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        option.subtitle!,
                        style: KitTypography.caption.copyWith(color: p.inkMuted),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.inkMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selectable chips for ritual / time windows.
class SettingsChoiceChips extends StatelessWidget {
  const SettingsChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final option in options)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled
                  ? () {
                      AppHaptics.selection();
                      onSelected(option);
                    }
                  : null,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: selected == option ? p.brandContainer : p.surfaceSoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: selected == option
                        ? p.brand.withValues(alpha: 0.35)
                        : p.hairline,
                  ),
                ),
                child: Text(
                  option,
                  style: KitTypography.chip.copyWith(
                    color: selected == option ? p.brand : p.inkSecondary,
                    fontWeight:
                        selected == option ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Inline info callout under a section.
class SettingsInfoBanner extends StatelessWidget {
  const SettingsInfoBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.brandContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: p.brand.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: p.brandSoft, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: KitTypography.caption.copyWith(color: p.inkSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
