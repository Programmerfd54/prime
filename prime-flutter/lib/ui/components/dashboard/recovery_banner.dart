import 'package:flutter/material.dart';

import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../design/visuals/scene_art.dart';
import '../app_compact_button.dart';
import '../../kit/components/prime_content_card.dart';

/// Shown when streak broke but user has history — gentle recovery nudge (V6 §4).
class RecoveryBanner extends StatelessWidget {
  const RecoveryBanner({super.key, this.onAction});

  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return PrimeContentCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SceneArt(kind: SceneKind.recovery, size: 56),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Можно вернуться в ритм',
                  style: AppTypography.title2.copyWith(color: p.ink),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Серия прервалась, но опыт остался. Один отчёт сегодня — '
                  'и вы снова в практике.',
                  style: AppTypography.bodySecondary.copyWith(
                    color: p.inkSecondary,
                  ),
                ),
                if (onAction != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppCompactButton(
                    label: 'Отправить отчёт',
                    onPressed: onAction,
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
