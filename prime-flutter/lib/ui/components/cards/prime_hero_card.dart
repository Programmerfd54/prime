import 'package:flutter/material.dart';

import 'package:prime/design/shapes/prime_squircle.dart';
import 'package:prime/design/tokens.dart';
import 'package:prime/design/typography.dart';

/// Photo hero card with gradient veil and editorial serif title overlay.
class PrimeHeroCard extends StatelessWidget {
  const PrimeHeroCard({
    super.key,
    this.image,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.aspectRatio = 16 / 9,
    this.child,
  });

  /// [ImageProvider] or asset path [String].
  final Object? image;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final double aspectRatio;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final provider = _resolveImageProvider(image);

    Widget card = AspectRatio(
      aspectRatio: aspectRatio,
      child: PrimeSquircleClip(
        radius: AppRadius.xl,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _HeroPhoto(image: provider),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0x66000000),
                    Color(0xCC000000),
                  ],
                  stops: [0.35, 0.72, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (trailing != null)
                    Align(alignment: Alignment.topRight, child: trailing!),
                  const Spacer(),
                  AppTypography.accentText(
                    title,
                    style: AppTypography.titleSerif.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle!,
                      style: AppTypography.bodySecondary.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.88),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (child != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    child!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      card = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}

ImageProvider? _resolveImageProvider(Object? image) {
  if (image == null) return null;
  if (image is ImageProvider) return image;
  if (image is String) return AssetImage(image);
  return null;
}

class _HeroPhoto extends StatelessWidget {
  const _HeroPhoto({required this.image});

  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    if (image != null) {
      return Image(
        image: image!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _HeroPhotoFallback(),
      );
    }
    return const _HeroPhotoFallback();
  }
}

class _HeroPhotoFallback extends StatelessWidget {
  const _HeroPhotoFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.heroSurfaceStart,
            AppColors.heroSurfaceEnd,
          ],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}
