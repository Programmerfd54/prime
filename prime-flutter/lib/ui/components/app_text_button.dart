import 'package:flutter/material.dart';

import '../../design/haptics.dart';
import '../../design/pressable.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';

/// Lightweight text action (auth toggles, inline secondary CTAs).
class AppTextButton extends StatelessWidget {
  const AppTextButton({
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
          minHeight: AppControlHeights.iconButton,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: icon == null
              ? Text(
                  label,
                  style: AppTypography.button.copyWith(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: AppIconSizes.sm, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.xxs),
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.button.copyWith(
                          color: AppColors.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
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
