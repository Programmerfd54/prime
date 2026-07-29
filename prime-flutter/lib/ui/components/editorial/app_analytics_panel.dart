import 'package:flutter/material.dart';

import '../../../core/metrics/analytics_metrics.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../models/report.dart';
import '../../kit/components/prime_empty_state.dart';
import '../../kit/presentation/profile_editorial_widgets.dart';
import '../../kit/tokens/kit_typography.dart';

TextStyle _analyticsSectionTitle(BuildContext context) {
  return AppTypography.titleSerif.copyWith(
    fontSize: 20,
    color: context.prime.ink,
  );
}

/// Lightweight analytics summary from calendar (+ optional prime events).
class AppAnalyticsPanel extends StatelessWidget {
  const AppAnalyticsPanel({
    super.key,
    required this.calendar,
    this.primeEvents,
  });

  final CalendarOut calendar;
  final List<dynamic>? primeEvents;

  @override
  Widget build(BuildContext context) {
    if (calendar.successfulDays == 0 && calendar.currentStreak == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Аналитика', style: _analyticsSectionTitle(context)),
          const SizedBox(height: AppSpacing.sm),
          const PrimeEmptyState(
            title: 'Пока мало данных',
            body: 'Аналитика появится после нескольких успешных дней активности.',
            illustrationAsset: 'assets/illustrations/growth.svg',
          ),
        ],
      );
    }

    final gapDays = reportTeamGapDays(calendar);
    final consistency7 = _consistencyPercent(calendar, window: 7);
    final bySkill = completionBySkill(calendar);
    final topSkills = bySkill.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = topSkills.take(3).toList();
    final maxCompleted =
        top.isEmpty ? 1 : top.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Аналитика', style: _analyticsSectionTitle(context)),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: ProfileEditorialPalette.cardSurface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileMetricPillsRow(
                metrics: [
                  ProfileMetricPill(
                    label: 'Серия',
                    value: '${calendar.currentStreak} дн.',
                    variant: ProfileMetricPillVariant.gold,
                  ),
                  ProfileMetricPill(
                    label: 'Прогресс',
                    value: '${calendar.successfulDays} дн.',
                    variant: ProfileMetricPillVariant.hatched,
                  ),
                  ProfileMetricPill(
                    label: 'Стаб. 7д',
                    value: '$consistency7%',
                    variant: ProfileMetricPillVariant.glass,
                  ),
                  ProfileMetricPill(
                    label: 'Разрывы',
                    value: '$gapDays',
                    variant: ProfileMetricPillVariant.charcoal,
                  ),
                ],
              ),
              if (top.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Топ навыки', style: KitTypography.caption),
                const SizedBox(height: AppSpacing.sm),
                for (final entry in top) ...[
                  _EditorialSkillBar(
                    filled: entry.value.toDouble(),
                    total: maxCompleted.toDouble(),
                    label: entry.key,
                  ),
                  if (entry != top.last) const SizedBox(height: AppSpacing.sm),
                ],
              ],
              if (primeEvents != null && primeEvents!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Builder(
                  builder: (context) {
                    final primeBySkill =
                        primesBySkill(primeEvents!).entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value));
                    final topPrime = primeBySkill.take(3).toList();
                    if (topPrime.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Праймы по программам',
                          style: KitTypography.caption,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final entry in topPrime)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: Text(
                              '${entry.key}: ${entry.value}',
                              style: KitTypography.bodySecondary,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EditorialSkillBar extends StatelessWidget {
  const _EditorialSkillBar({
    required this.filled,
    required this.total,
    required this.label,
  });

  final double filled;
  final double total;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: KitTypography.caption),
        const SizedBox(height: AppSpacing.xxs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: total <= 0 ? 0 : (filled / total).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.primarySoft.withValues(alpha: 0.18),
            color: ProfileEditorialPalette.chartGold,
          ),
        ),
      ],
    );
  }
}

int _consistencyPercent(CalendarOut calendar, {required int window}) {
  final recent = calendar.days.length <= window
      ? calendar.days
      : calendar.days.sublist(calendar.days.length - window);
  if (recent.isEmpty) return 0;
  final met = recent.where((day) => day.reported).length;
  return ((met / recent.length) * 100).round();
}
