import 'package:flutter/material.dart';

import '../../../core/media/media_urls.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';

/// Avatar with cache eviction via [photoUrl] key — updates without app restart.
/// Supports network [photoUrl] or local [assetPath] (shadcn-style image + fallback).
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.photoUrl,
    this.assetPath,
    this.radius = 24,
    this.name,
    this.onTap,
    this.showEditBadge = false,
  });

  final String? photoUrl;
  final String? assetPath;
  final double radius;
  final String? name;
  final VoidCallback? onTap;
  final bool showEditBadge;

  @override
  Widget build(BuildContext context) {
    final url = absolutePhotoUrl(photoUrl);
    final initial = _initial(name);
    final hasAsset = assetPath != null && assetPath!.isNotEmpty;
    final hasNetwork = url != null;

    Widget avatar = Container(
      key: ValueKey(assetPath ?? photoUrl ?? 'empty'),
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceSoft,
        border: Border.all(color: AppColors.borderStrong),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasAsset
          ? Image.asset(assetPath!, fit: BoxFit.cover)
          : hasNetwork
              ? Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(
                      initial,
                      style: AppTypography.title2.copyWith(
                        fontSize: radius * 0.72,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    initial,
                    style: AppTypography.title2.copyWith(
                      fontSize: radius * 0.72,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
    );

    if (showEditBadge) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.72,
              height: radius * 0.72,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 2),
              ),
              child: Icon(
                Icons.photo_camera_outlined,
                size: radius * 0.36,
                color: AppColors.primarySoft,
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: avatar,
        ),
      );
    }
    return avatar;
  }

  String _initial(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return '?';
    final withoutAt = trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
    return withoutAt[0].toUpperCase();
  }

  /// Evicts cached network image for previous URL after avatar update.
  static Future<void> evictCache(String? photoUrl) async {
    final url = absolutePhotoUrl(photoUrl);
    if (url != null) {
      await NetworkImage(url).evict();
    }
  }
}
