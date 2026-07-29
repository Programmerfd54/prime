import 'package:flutter/material.dart';

import '../../design/glass.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../models/report.dart';
import '../../design/visuals/habit_art.dart';
import 'dashboard_helpers.dart';

class ActiveChallengeCard extends StatelessWidget {
  final String skillId;
  final String skillName;
  final CalendarOut? calendar;
  final VoidCallback onOpen;

  const ActiveChallengeCard({
    super.key,
    required this.skillId,
    required this.skillName,
    required this.calendar,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final completed = (calendar?.days.where((day) => day.completed).length ?? 0)
        .clamp(0, dashboardChallengeDays);
    const total = dashboardChallengeDays;
    final progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    final accentKey = skillId.isNotEmpty ? skillId : skillName;
    final kind = habitArtKindFor(accentKey);
    final accent = habitArtAccent(kind);
    return GlassContainer(
      onTap: onOpen,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: BorderRadius.circular(AppRadius.bentoOuter),
      fillOpacity: 0.05,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'АКТИВНАЯ ПРИВЫЧКА',
            style: AppTypography.caption.copyWith(
              fontSize: 10,
              letterSpacing: 0.4,
              color: accent,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              HabitArtObject(kind: kind, size: 48),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(skillName, style: AppTypography.title2),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'День $completed из $total',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.elevatedSurface,
              color: accent,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(progress * 100).round()}%',
              style: AppTypography.caption,
            ),
          ),
        ],
      ),
    );
  }
}
