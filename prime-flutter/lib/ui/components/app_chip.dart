import 'package:flutter/material.dart';

import '../../design/pressable.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';

/// Compact pill chip for facts, filters, and prompt suggestions.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.selectedSurface : AppColors.elevatedSurface;
    final fg = selected ? AppColors.primarySoft : AppColors.textSecondary;
    final border = selected
        ? AppColors.primary.withValues(alpha: 0.55)
        : AppColors.border;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bound = constraints.maxWidth;
        final maxChipWidth = bound.isFinite && bound > 0 ? bound : 320.0;

        final child = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxChipWidth),
          child: AnimatedContainer(
            duration: AppDurations.fast,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: border),
              boxShadow: selected ? AppGlow.violet(opacity: 0.18) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: AppIconSizes.xs, color: fg),
                  const SizedBox(width: AppSpacing.xxs),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        if (onTap == null) return child;
        return PrimePressable(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: child,
        );
      },
    );
  }
}
