import 'package:flutter/material.dart';

import 'package:prime/design/tokens.dart';
import 'package:prime/design/typography.dart';
import 'package:prime/ui/kit/tokens/kit_surfaces.dart';

/// Compact insight card with icon, title, and message.
class PrimeInsightCard extends StatelessWidget {
  const PrimeInsightCard({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: kitSurfaceDecoration(context, PrimeSurfaceLevel.solid),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              icon,
              size: AppIconSizes.sm,
              color: AppColors.primarySoft,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.title2.copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  message,
                  style: AppTypography.bodySecondary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: body,
      ),
    );
  }
}
