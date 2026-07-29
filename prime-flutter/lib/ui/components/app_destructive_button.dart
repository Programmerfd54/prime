import 'package:flutter/material.dart';

import '../../design/haptics.dart';
import '../../design/pressable.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';

/// Destructive action — red only for dangerous actions; prefer tertiary placement.
class AppDestructiveButton extends StatelessWidget {
  const AppDestructiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final bg = filled
        ? (enabled
            ? AppColors.error
            : AppColors.disabled.withValues(alpha: 0.35))
        : Colors.transparent;
    final fg = filled
        ? AppColors.textOnPrimary
        : (enabled ? AppColors.error : AppColors.textMuted);

    return PrimePressable(
      enabled: enabled,
      haptic: false,
      onTap: enabled
          ? () {
              AppHaptics.medium();
              onPressed!();
            }
          : null,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        width: double.infinity,
        height: AppControlHeights.button,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
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
              : Text(
                  label,
                  style: AppTypography.button.copyWith(color: fg),
                ),
        ),
      ),
    );
  }
}
