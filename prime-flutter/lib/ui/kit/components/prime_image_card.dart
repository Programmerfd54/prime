import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../tokens/kit_typography.dart';

/// Photography-led card with bottom metadata overlay.
class PrimeImageCard extends StatelessWidget {
  const PrimeImageCard({
    super.key,
    required this.image,
    required this.title,
    this.subtitle,
    this.trailing,
    this.aspectRatio = 4 / 5,
    this.onTap,
    this.metadata = const [],
  });

  final ImageProvider image;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final double aspectRatio;
  final VoidCallback? onTap;
  final List<Widget> metadata;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                Image(image: image, fit: BoxFit.cover),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.12),
                        Colors.black.withValues(alpha: 0.82),
                      ],
                      stops: const [0.28, 0.58, 1.0],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (trailing != null)
                        Align(alignment: Alignment.topRight, child: trailing),
                      const Spacer(),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          color: Colors.black.withValues(alpha: 0.42),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: KitTypography.cardTitle
                                    .copyWith(color: p.inkOnBrand),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  subtitle!,
                                  style: KitTypography.caption.copyWith(
                                    color: p.inkOnBrand.withValues(alpha: 0.85),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (metadata.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Wrap(
                                  spacing: AppSpacing.xs,
                                  runSpacing: AppSpacing.xxs,
                                  children: metadata,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
