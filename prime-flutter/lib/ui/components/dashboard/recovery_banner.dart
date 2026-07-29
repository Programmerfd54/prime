import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../design/visuals/scene_art.dart';

/// Shown when streak broke but user has history — gentle recovery nudge.
class RecoveryBanner extends StatelessWidget {
  const RecoveryBanner({super.key, this.onAction});

  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          colors: [
            AppColors.coral.withValues(alpha: 0.18),
            AppColors.surface,
          ],
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SceneArt(kind: SceneKind.recovery, size: 64),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Можно вернуться в ритм', style: AppTypography.title2),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Серия прервалась, но опыт остался. Один отчёт сегодня — '
                  'и вы снова в игре.',
                  style: AppTypography.bodySecondary,
                ),
                if (onAction != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: onAction,
                    child: const Text('Отправить отчёт'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
