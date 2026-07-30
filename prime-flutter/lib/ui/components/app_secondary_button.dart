import 'package:flutter/material.dart';

import '../../design/haptics.dart';
import '../../design/pressable.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final fg = enabled ? AppColors.textPrimary : AppColors.textMuted;

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
          color: AppColors.elevatedSurface,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: AppColors.borderStrong),
          boxShadow: enabled ? AppElevation.lifted : AppElevation.none,
        ),
        child: Center(
          child: loading
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
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
