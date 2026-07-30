import 'package:flutter/material.dart';

import '../../../core/media/media_urls.dart';
import '../../../design/tokens.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../tokens/kit_typography.dart';

/// Team pulse / avatar cluster for social context.
class PrimeSocialCard extends StatelessWidget {
  const PrimeSocialCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.avatars,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final List<PrimeSocialAvatar> avatars;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Material(
      color: p.surfaceElevated,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: KitTypography.cardTitle.copyWith(color: p.ink)),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle!,
                        style: KitTypography.caption.copyWith(color: p.inkMuted),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 36,
                      child: Stack(
                        children: [
                          for (var i = 0; i < avatars.length && i < 6; i++)
                            Positioned(
                              left: i * 22.0,
                              child: _AvatarBubble(item: avatars[i]),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class PrimeSocialAvatar {
  const PrimeSocialAvatar({this.photoUrl, required this.name, this.ready = false});

  final String? photoUrl;
  final String name;
  final bool ready;
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({required this.item});

  final PrimeSocialAvatar item;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: item.ready ? p.mint : p.surfaceElevated,
          width: 2,
        ),
      ),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: p.surface,
        backgroundImage: absolutePhotoUrl(item.photoUrl) != null
            ? NetworkImage(absolutePhotoUrl(item.photoUrl)!)
            : null,
        child: item.photoUrl == null
            ? Text(
                item.name.isNotEmpty ? item.name[0] : '?',
                style: KitTypography.caption,
              )
            : null,
      ),
    );
  }
}
