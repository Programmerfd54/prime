import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../tokens/kit_surfaces.dart';
import '../tokens/kit_typography.dart';

/// Insight / coaching card with semantic accent rail.
class PrimeInsightCard extends StatelessWidget {
  const PrimeInsightCard({
    super.key,
    required this.title,
    required this.message,
    this.accent = KitAccent.blue,
    this.icon,
  });

  final String title;
  final String message;
  final KitAccent accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final color = accent.resolve(context);
    return Container(
      decoration: kitSurfaceDecoration(context, PrimeSurfaceLevel.solid),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(AppRadius.lg),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 18, color: color),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            style: KitTypography.cardTitle.copyWith(color: p.ink),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      message,
                      style: KitTypography.bodySecondary.copyWith(color: p.inkSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
