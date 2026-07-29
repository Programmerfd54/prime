import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../l10n/copy.dart';
import '../../../models/group.dart';

/// Weekly team challenge card — uses teamRecap / teamDay when available.
class AppWeeklyTeamChallengeCard extends StatelessWidget {
  const AppWeeklyTeamChallengeCard({
    super.key,
    required this.group,
  });

  final GroupModel group;

  @override
  Widget build(BuildContext context) {
    final recap = group.teamRecap;
    final pulse = group.teamPulse;
    final teamDay = group.teamDay;
    const targetDays = 5;
    const totalDays = 7;
    final todayComplete =
        teamDay?.isComplete == true || pulse?.isTeamDayComplete == true;

    int completedDays;
    if (recap != null) {
      completedDays =
          (recap.pacePercent / 100 * totalDays).round().clamp(0, totalDays);
      if (completedDays == 0 && todayComplete) {
        completedDays = 1;
      }
    } else if (todayComplete) {
      completedDays = 1;
    } else {
      completedDays = 0;
    }
    final progress = completedDays / targetDays;
    final subtitle = recap != null && recap.message.isNotEmpty
        ? recap.message
        : todayComplete
            ? 'Сегодня день закрыт — держите темп недели'
            : AppCopy.dayClosesTogether;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Недельный челлендж: $targetDays из $totalDays дней все сдают',
            style: AppTypography.title2,
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.primaryContainer,
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$completedDays из $targetDays дней выполнено',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            style: AppTypography.bodySecondary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
