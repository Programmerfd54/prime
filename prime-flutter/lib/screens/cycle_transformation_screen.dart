import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../models/group.dart';
import '../ui/components/app_primary_button.dart';
import '../ui/components/app_secondary_button.dart';
import '../ui/components/editorial/app_group_recap.dart';
import '../ui/kit/components/prime_content_card.dart';

/// End-of-cycle transformation summary before continuation vote.
class CycleTransformationScreen extends StatelessWidget {
  const CycleTransformationScreen({
    super.key,
    required this.group,
    required this.onContinueTogether,
    required this.onNewSkill,
    required this.onHarder,
    required this.onRecovery,
  });

  final GroupModel group;
  final VoidCallback onContinueTogether;
  final VoidCallback onNewSkill;
  final VoidCallback onHarder;
  final VoidCallback onRecovery;

  @override
  Widget build(BuildContext context) {
    final personal = group.personalResult;
    final recap = group.teamRecap;
    return Scaffold(
      appBar: AppBar(title: const Text('30 дней вместе')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          PrimeContentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '30 дней назад',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppSpacing.xxs),
                const Text(
                  'Нестабильный ритм в одиночку',
                  style: AppTypography.title2,
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Сегодня', style: AppTypography.caption),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  personal?.message ??
                      recap?.message ??
                      'Вы прошли первый цикл вместе — это результат команды.',
                  style: AppTypography.bodySecondary,
                ),
              ],
            ),
          ),
          if (personal != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppPersonalImpactPanel(result: personal),
          ],
          if (recap != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppGroupRecapPanel(recap: recap),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppPrimaryButton(
            label: 'Продолжить с командой',
            onPressed: onContinueTogether,
          ),
          const SizedBox(height: AppSpacing.xs),
          AppSecondaryButton(
            label: 'Новая привычка',
            onPressed: onNewSkill,
          ),
          const SizedBox(height: AppSpacing.xs),
          AppSecondaryButton(
            label: 'Сделать цикл сложнее',
            onPressed: onHarder,
          ),
          const SizedBox(height: AppSpacing.xs),
          AppSecondaryButton(
            label: 'Неделя восстановления',
            onPressed: onRecovery,
          ),
        ],
      ),
    );
  }
}
