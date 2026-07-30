import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../../components/app_primary_button.dart';
import '../../components/app_skeleton.dart';
import 'profile_editorial_widgets.dart';
import 'profile_typography.dart';

/// Profile-specific UI states (TZ §14).
enum ProfileScreenState {
  normal,
  loading,
  offline,
  networkError,
  blocked,
  restricted,
}

/// Offline / cached-data banner for profile dashboards.
class ProfileOfflineBanner extends StatelessWidget {
  const ProfileOfflineBanner({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateBanner(
      icon: Icons.cloud_off_outlined,
      title: 'Офлайн — показаны сохранённые данные',
      subtitle: 'Подключитесь к сети, чтобы обновить профиль.',
      actionLabel: onRetry == null ? null : 'Обновить',
      onAction: onRetry,
    );
  }
}

/// Blocked / reported participant state.
class ProfileBlockedBanner extends StatelessWidget {
  const ProfileBlockedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return _StateBanner(
      icon: Icons.block_outlined,
      title: 'Профиль ограничен',
      subtitle: 'Доступ к части данных временно недоступен.',
      accent: ProfilePalette.coral,
    );
  }
}

class ProfileNetworkErrorState extends StatelessWidget {
  const ProfileNetworkErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: ProfilePalette.coolGrey.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Не удалось загрузить профиль',
              style: ProfileTypography.cardTitle.copyWith(
                color: ProfilePalette.offWhite,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: ProfileTypography.secondary.copyWith(
                color: ProfilePalette.coolGrey,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppPrimaryButton(label: 'Повторить', onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}

class _StateBanner extends StatelessWidget {
  const _StateBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final tone = accent ?? ProfilePalette.brandSoft;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ProfilePalette.charcoal,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ProfileTypography.cardTitle.copyWith(
                    color: ProfilePalette.offWhite,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: ProfileTypography.secondary.copyWith(
                    color: ProfilePalette.coolGrey,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Hover/focus wrapper for Web expanded layout (TZ §16).
class ProfileHoverable extends StatefulWidget {
  const ProfileHoverable({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.enabled = true,
  });

  final Widget child;
  final double borderRadius;
  final bool enabled;

  @override
  State<ProfileHoverable> createState() => _ProfileHoverableState();
}

class _ProfileHoverableState extends State<ProfileHoverable> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final active = _hovered || _focused;
    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: ProfilePalette.brandSoft.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Full-page profile loading placeholder.
class ProfileLoadingState extends StatelessWidget {
  const ProfileLoadingState({super.key});

  @override
  Widget build(BuildContext context) => const AppProfileSkeleton();
}
