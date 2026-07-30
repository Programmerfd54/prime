import 'package:flutter/material.dart';

import '../../design/haptics.dart';
import '../../design/pressable.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';

/// Compact inline CTA for dense lists (friend search, relation states).
class AppCompactButton extends StatelessWidget {
  const AppCompactButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final bg = primary
        ? (enabled
            ? AppColors.primary
            : AppColors.disabled.withValues(alpha: 0.35))
        : Colors.transparent;
    final fg = primary
        ? (enabled ? AppColors.textOnPrimary : AppColors.textMuted)
        : (enabled ? AppColors.textPrimary : AppColors.textMuted);

    return PrimePressable(
      enabled: enabled,
      haptic: false,
      onTap: enabled
          ? () {
              AppHaptics.light();
              onPressed!();
            }
          : null,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        height: AppControlHeights.buttonCompact,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: primary
              ? null
              : Border.all(color: AppColors.borderStrong),
          boxShadow: primary && enabled ? AppElevation.lifted : AppElevation.none,
        ),
        child: Center(
          child: loading
              ? SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fg,
                  ),
                )
              : Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
        ),
      ),
    );
  }
}
