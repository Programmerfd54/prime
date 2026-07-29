import 'package:flutter/material.dart';

import '../../design/haptics.dart';
import '../../design/pressable.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';

/// Minimal text / tertiary action — never competes with Primary.
class AppTertiaryButton extends StatelessWidget {
  const AppTertiaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return PrimePressable(
      enabled: enabled,
      haptic: false,
      onTap: enabled
          ? () {
              AppHaptics.selection();
              onPressed!();
            }
          : null,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 48,
          minHeight: AppControlHeights.buttonCompact,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: AppIconSizes.sm,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xxs),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.button.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
