import 'package:flutter/material.dart';

import 'package:prime/design/liquid/liquid_glass.dart';
import 'package:prime/design/tokens.dart';
import 'package:prime/design/typography.dart';

/// Card with corner expand affordance and expandable body content.
class PrimeExpandCard extends StatelessWidget {
  const PrimeExpandCard({
    super.key,
    required this.title,
    required this.child,
    required this.onExpand,
    this.trailing,
  });

  final String title;
  final Widget child;
  final VoidCallback onExpand;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      forceTier: LiquidTier.lite,
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.md),
      clip: true,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.title2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    trailing!,
                  ],
                  const SizedBox(width: 36),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              child,
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: _ExpandAffordance(onExpand: onExpand),
          ),
        ],
      ),
    );
  }
}

class _ExpandAffordance extends StatelessWidget {
  const _ExpandAffordance({required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onExpand,
      child: Semantics(
        button: true,
        label: 'Expand',
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            '⤢',
            style: AppTypography.caption.copyWith(
              color: AppColors.primarySoft,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
