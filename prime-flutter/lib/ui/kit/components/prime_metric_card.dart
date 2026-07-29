import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../tokens/kit_surfaces.dart';
import '../tokens/kit_typography.dart';

/// Compact numeric metric — distinct from legacy [PrimeStatCard].
class PrimeMetricCard extends StatelessWidget {
  const PrimeMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.suffix = '',
    this.accent = KitAccent.neutral,
    this.compact = true,
    this.onTap,
  });

  final String label;
  final String value;
  final String suffix;
  final KitAccent accent;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final color = accent.resolve(context);
    final body = Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: compact ? AppSpacing.sm : AppSpacing.md,
      ),
      decoration: kitSurfaceDecoration(context, PrimeSurfaceLevel.solid),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: KitTypography.caption.copyWith(color: p.inkMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: (compact ? KitTypography.metricMedium : KitTypography.metricLarge)
                      .copyWith(color: color == p.inkSecondary ? p.ink : color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (suffix.isNotEmpty)
                Text(
                  suffix,
                  style: KitTypography.bodySecondary.copyWith(color: p.inkSecondary),
                ),
            ],
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
