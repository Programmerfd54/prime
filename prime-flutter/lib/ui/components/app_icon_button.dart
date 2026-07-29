import 'package:flutter/material.dart';

import '../../design/haptics.dart';
import '../../design/pressable.dart';
import '../../design/tokens.dart';

/// Icon-only control with ≥48dp tap target and optional filled variant.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.filled = false,
    this.backgroundColor,
    this.foregroundColor,
    this.iconSize = AppIconSizes.md,
    this.loading = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool filled;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double iconSize;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final fg = foregroundColor ?? AppColors.textPrimary;
    final bg = backgroundColor ??
        (filled ? AppColors.primary : AppColors.elevatedSurface);

    final button = PrimePressable(
      enabled: enabled,
      haptic: false,
      onTap: enabled
          ? () {
              AppHaptics.selection();
              onPressed!();
            }
          : null,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        width: AppControlHeights.iconButton,
        height: AppControlHeights.iconButton,
        decoration: BoxDecoration(
          color: filled || backgroundColor != null ? bg : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: filled ? null : Border.all(color: AppColors.border),
        ),
        child: Center(
          child: loading
              ? SizedBox.square(
                  dimension: iconSize * 0.85,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fg,
                  ),
                )
              : Icon(icon, size: iconSize, color: enabled ? fg : AppColors.textMuted),
        ),
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) return button;
    return Tooltip(
      message: tooltip!,
      child: Semantics(
        button: true,
        label: tooltip,
        child: button,
      ),
    );
  }
}
