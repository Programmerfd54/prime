import 'package:flutter/material.dart';

import 'package:prime/design/shapes/prime_squircle.dart';
import 'package:prime/design/tokens.dart';
import 'package:prime/design/typography.dart';
import 'package:prime/ui/kit/tokens/kit_surfaces.dart';

/// Photo card with favorite affordance and meta tag chips.
class PrimeMediaCard extends StatelessWidget {
  const PrimeMediaCard({
    super.key,
    this.image,
    required this.title,
    this.meta,
    this.tags = const [],
    this.favorited = false,
    this.onFavorite,
    this.onTap,
    this.height = 200,
  });

  /// [ImageProvider] or asset path [String].
  final Object? image;
  final String title;
  final String? meta;
  final List<String> tags;
  final bool favorited;
  final VoidCallback? onFavorite;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final provider = _resolveImageProvider(image);

    Widget card = SizedBox(
      height: height,
      child: PrimeSquircleClip(
        radius: AppRadius.xl,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _MediaPhoto(image: provider),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x33000000),
                    Color(0x00000000),
                    Color(0x99000000),
                    Color(0xE6000000),
                  ],
                  stops: [0.0, 0.35, 0.72, 1.0],
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: _FavoriteButton(
                favorited: favorited,
                onFavorite: onFavorite,
              ),
            ),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tags.isNotEmpty) ...[
                    Wrap(
                      spacing: AppSpacing.xxs,
                      runSpacing: AppSpacing.xxs,
                      children: [
                        for (final tag in tags.take(4))
                          _MetaChip(label: tag),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  Text(
                    title,
                    style: AppTypography.titleSerif.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (meta != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      meta!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.82),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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

class _MediaPhoto extends StatelessWidget {
  const _MediaPhoto({required this.image});

  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    if (image != null) {
      return Image(
        image: image!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _MediaPhotoFallback(),
      );
    }
    return const _MediaPhotoFallback();
  }
}

class _MediaPhotoFallback extends StatelessWidget {
  const _MediaPhotoFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.premiumDarkViolet,
            AppColors.deepSurface,
          ],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({
    required this.favorited,
    this.onFavorite,
  });

  final bool favorited;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onFavorite,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: kitSurfaceDecoration(
          context,
          PrimeSurfaceLevel.solid,
          radius: AppRadius.pill,
        ).copyWith(
          color: AppColors.elevatedSurface.withValues(alpha: 0.92),
        ),
        child: Icon(
          favorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: AppIconSizes.sm,
          color: favorited ? AppColors.coral : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
