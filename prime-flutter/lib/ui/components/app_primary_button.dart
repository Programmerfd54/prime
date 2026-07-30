import 'package:flutter/material.dart';

import '../../design/haptics.dart';
import '../../design/pressable.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.success = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final bg = success
        ? AppColors.success
        : enabled
            ? AppColors.primary
            : AppColors.disabled.withValues(alpha: 0.35);
    final fg = enabled || success
        ? AppColors.textOnPrimary
        : AppColors.textMuted;
    final shadow = enabled && !success
        ? AppElevation.lifted
        : success
            ? AppGlow.mint(opacity: 0.22)
            : AppElevation.none;

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
        width: double.infinity,
        height: AppControlHeights.button,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.button),
          boxShadow: shadow,
        ),
        child: Center(
          child: loading
              ? SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fg,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (success) ...[
                      Icon(
                        Icons.check_rounded,
                        size: AppIconSizes.sm,
                        color: fg,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ] else if (icon != null) ...[
                      Icon(icon, size: AppIconSizes.sm, color: fg),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.button.copyWith(color: fg),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
