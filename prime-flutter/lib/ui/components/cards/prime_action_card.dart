import 'package:flutter/material.dart';

import 'package:prime/design/shapes/prime_squircle.dart';
import 'package:prime/design/tokens.dart';
import 'package:prime/design/typography.dart';
import 'package:prime/ui/components/app_primary_button.dart';

/// Tinted hero CTA card with serif headline and primary action.
class PrimeActionCard extends StatelessWidget {
  const PrimeActionCard({
    super.key,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    this.illustration,
    this.backgroundColor,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget? illustration;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.primaryContainer;

    return PrimeSquircleClip(
      radius: AppRadius.xl,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              bg,
              Color.alphaBlend(
                AppColors.mint.withValues(alpha: 0.08),
                bg,
              ),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppTypography.accentText(
                      title,
                      style: AppTypography.titleSerif.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      body,
                      style: AppTypography.bodySecondary.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.88),
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppPrimaryButton(
                      label: actionLabel,
                      onPressed: onAction,
                    ),
                  ],
                ),
              ),
              if (illustration != null) ...[
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 88,
                  height: 88,
                  child: illustration,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
