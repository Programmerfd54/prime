import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../profile/app_avatar.dart';

/// Compact home header — avatar, emotional greeting, date.
class AppHomeGreeting extends StatelessWidget {
  const AppHomeGreeting({
    super.key,
    required this.name,
    required this.dateLabel,
    this.photoUrl,
    this.subtitle,
    this.onAvatarTap,
  });

  final String name;
  final String dateLabel;
  final String? photoUrl;
  final String? subtitle;
  final VoidCallback? onAvatarTap;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'Спокойной ночи';
    if (hour < 12) return 'Доброе утро';
    if (hour < 18) return 'Добрый день';
    return 'Добрый вечер';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppAvatar(
          photoUrl: photoUrl,
          radius: 26,
          name: name,
          onTap: onAvatarTap,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (name.trim().isEmpty)
                Text(
                  _greeting,
                  style: AppTypography.titleSerif.copyWith(fontSize: 24),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              else
                AppTypography.accentText(
                  '$_greeting, *${name.trim()}*',
                  style: AppTypography.titleSerif.copyWith(fontSize: 24),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                dateLabel,
                style: AppTypography.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle!,
                  style: AppTypography.bodySecondary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
