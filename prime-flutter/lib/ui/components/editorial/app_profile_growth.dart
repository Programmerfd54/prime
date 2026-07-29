import 'package:flutter/material.dart';

import '../../../core/engines/consistency_engine.dart';
import '../../../core/engines/momentum_engine.dart';
import '../../../core/metrics/calendar_metrics.dart';
import '../../../design/motion.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../design/visuals/gauges/gauges.dart';
import '../../../design/visuals/scene_art.dart';
import '../../../models/report.dart';
import '../../kit/presentation/profile_editorial_widgets.dart';
import '../mood/mood_completion_chart.dart';
import 'app_analytics_panel.dart';

/// «Ваш темп» — layered tones + real visualizations, never bare dashes.
class AppProfileGrowthSection extends StatelessWidget {
  const AppProfileGrowthSection({
    super.key,
    required this.currentStreak,
    required this.successfulDays,
    required this.primePoints,
    this.bestStreak = 0,
    this.cyclePacePercent,
    this.insights = const [],
    this.calendar,
    this.streakShields = 0,
    this.shieldPending = false,
    this.onBuyShield,
    this.onUseShield,
    this.onInsightOpened,
  });

  final int currentStreak;
  final int successfulDays;
  final int primePoints;
  final int bestStreak;
  final int? cyclePacePercent;
  final List<ProfileInsightModel> insights;
  final CalendarOut? calendar;
  final int streakShields;
  final bool shieldPending;
  final VoidCallback? onBuyShield;
  final VoidCallback? onUseShield;
  final ValueChanged<ProfileInsightModel>? onInsightOpened;

  @override
  Widget build(BuildContext context) {
    final cycleDay = successfulDays == 0 ? 0 : successfulDays % 30;
    final buckets = calendar == null
        ? const <WeekDayBucket>[]
        : CalendarMetrics.weeklyBuckets(calendar!);
    final cells = calendar == null
        ? const <HeatmapCell>[]
        : CalendarMetrics.heatmapCells(calendar!);
    final pace = calendar == null
        ? (successfulDays == 0 ? 0.0 : cycleDay / 30)
        : CalendarMetrics.paceRatio(calendar!);
    final dotPlotValues = _dotPlotFromCells(cells);
    final streakRatio = _streakProgress(currentStreak, bestStreak);
    final primesRatio = primePoints <= 0 ? 0.0 : (primePoints / 50).clamp(0.0, 1.0);
    final paceDisplay = cyclePacePercent != null
        ? '$cyclePacePercent%'
        : '${(pace * 100).round()}%';

    final insufficientData = successfulDays == 0 && currentStreak == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Сейчас в работе', style: _profileSectionTitle(context)),
        const SizedBox(height: AppSpacing.sm),
        if (insufficientData)
          _EditorialDarkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Начните первый цикл', style: AppTypography.title2),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Выберите привычку, найдите команду и отправьте первый отчёт — '
                  'здесь появятся метрики прогресса.',
                  style: AppTypography.bodySecondary,
                ),
              ],
            ),
          )
        else
          _EditorialDarkCard(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = MediaQuery.textScalerOf(context).scale(1) >= 1.5 ||
                    constraints.maxWidth < 340;
                final arc = PrimeSegmentedArc(
                  progress: pace,
                  valueLabel: '$cycleDay',
                  caption: 'день цикла',
                  size: stacked ? 120 : 140,
                );
                final rings = PrimeRingTrio.metrics(
                  streak: streakRatio,
                  streakDisplay: '$currentStreak',
                  primes: primesRatio,
                  primesDisplay: '$primePoints',
                  pace: pace,
                  paceDisplay: paceDisplay,
                  size: stacked ? 64 : 72,
                );
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: arc),
                      const SizedBox(height: AppSpacing.md),
                      rings,
                      if (bestStreak > currentStreak) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Рекорд серии: $bestStreak',
                          style: AppTypography.caption,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    arc,
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          rings,
                          if (bestStreak > currentStreak) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Рекорд серии: $bestStreak',
                              style: AppTypography.caption,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        _EditorialDarkCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.shield_outlined,
                color: shieldPending
                    ? AppColors.primarySoft
                    : AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Щит серии', style: AppTypography.title2),
                    Text(
                      shieldPending
                          ? 'Активен — следующий пропуск не сбросит серию'
                          : 'Щитов: $streakShields · покупка за 5 Праймов',
                      style: AppTypography.bodySecondary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((onUseShield != null &&
                            streakShields > 0 &&
                            !shieldPending) ||
                        onBuyShield != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Wrap(
                          spacing: AppSpacing.xs,
                          children: [
                            if (onUseShield != null &&
                                streakShields > 0 &&
                                !shieldPending)
                              TextButton(
                                onPressed: onUseShield,
                                child: const Text('Исп.'),
                              ),
                            if (onBuyShield != null)
                              TextButton(
                                onPressed: onBuyShield,
                                child: const Text('Купить'),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (bestStreak > 0) ...[
          const SizedBox(height: AppSpacing.md),
          _EditorialDarkCard(
            child: Row(
              children: [
                const SceneArt(kind: SceneKind.achievement, size: 56),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Личный рекорд', style: AppTypography.title2),
                      Text(
                        '$bestStreak ${_daysWord(bestStreak)} подряд',
                        style: AppTypography.bodySecondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('Ваш темп', style: _profileSectionTitle(context)),
        const SizedBox(height: AppSpacing.sm),
        ProfileStatisticsCard(
          title: 'Статистика недели',
          buckets: buckets,
        ),
        const SizedBox(height: AppSpacing.sm),
        _EditorialDarkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _VizMetric(
                      label: 'Праймы',
                      value: primePoints,
                      hint: 'За готовые отчёты',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _VizMetric(
                      label: 'Серия',
                      value: currentStreak,
                      hint: 'Дни подряд',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Цикл 30 дней', style: AppTypography.caption),
              const SizedBox(height: AppSpacing.xs),
              PrimeDotPlot(values: dotPlotValues),
            ],
          ),
        ),
        if (calendar != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Моментум и стабильность', style: _profileSectionTitle(context)),
          const SizedBox(height: AppSpacing.sm),
          _MomentumConsistencyPanel(calendar: calendar!),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('Insights', style: _profileSectionTitle(context)),
        const SizedBox(height: AppSpacing.sm),
        if (insights.isEmpty)
          _EditorialDarkCard(
            child: Row(
              children: [
                const SceneArt(kind: SceneKind.growth, size: 56),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    successfulDays >= 3
                        ? 'Пока недостаточно данных для персональных выводов.'
                        : 'Здесь появятся персональные выводы после нескольких дней активности.',
                    style: AppTypography.bodySecondary,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: insights.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) {
                final insight = insights[i];
                return SizedBox(
                  width: 240,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      onTap: onInsightOpened == null
                          ? null
                          : () => onInsightOpened!(insight),
                      child: _EditorialDarkCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 18,
                              color: AppColors.primarySoft,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              insight.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.title2.copyWith(fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Text(
                                insight.message,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        if (calendar != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppAnalyticsPanel(calendar: calendar!),
          const SizedBox(height: AppSpacing.md),
          MoodCompletionChartLoader(calendar: calendar),
        ],
      ],
    );
  }

  String _daysWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'день';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'дня';
    return 'дней';
  }

  static double _streakProgress(int current, int best) {
    if (current <= 0) return 0;
    final target = best > current ? best : (current >= 30 ? current : 30);
    return (current / target).clamp(0.0, 1.0);
  }

  static List<double> _dotPlotFromCells(List<HeatmapCell> cells) {
    if (cells.isEmpty) return const [];
    return cells
        .map((c) {
          if (c.isEmpty) return 0.0;
          if (c.completed) return 1.0;
          if (c.reported) return 0.55;
          return 0.0;
        })
        .toList();
  }
}

TextStyle _profileSectionTitle(BuildContext context) {
  return AppTypography.titleSerif.copyWith(
    fontSize: 20,
    color: context.prime.ink,
  );
}

/// Converts calendar days into the pure engines' input shape.
///
/// Mapping notes (no distinct "attempted but rejected" field exists on
/// [CalendarDay] today, so this is a pragmatic best-effort translation):
///  - `metMinimum` = [CalendarDay.reported] — the individual's report was
///    accepted (`status == 'ready'`), independent of whether the whole
///    team's day closed.
///  - `attempted` = `reported` OR any non-empty content/attachment was
///    submitted that day, even if the report ultimately wasn't accepted.
List<DailyActivity> _dailyActivityFrom(CalendarOut calendar) {
  return calendar.days
      .map((day) => DailyActivity(
            date: day.date,
            attempted: day.reported ||
                day.contentText.trim().isNotEmpty ||
                day.reports.isNotEmpty,
            metMinimum: day.reported,
          ))
      .toList();
}

/// Surfaces `momentum_engine`/`consistency_engine` output with a short
/// plain-language explainer — additive to the existing streak/pace/prime
/// visuals above, never replacing them.
class _MomentumConsistencyPanel extends StatelessWidget {
  const _MomentumConsistencyPanel({required this.calendar});

  final CalendarOut calendar;

  @override
  Widget build(BuildContext context) {
    final activity = _dailyActivityFrom(calendar);
    final momentum = MomentumEngine.score(activity);
    final consistency7 = ConsistencyEngine.sevenDay(
      activity,
      trackingStartDate: calendar.trackingStartDate,
    );
    final consistency30 = ConsistencyEngine.thirtyDay(
      activity,
      trackingStartDate: calendar.trackingStartDate,
    );

    return _EditorialDarkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _VizMetric(
                  label: 'Моментум',
                  value: momentum.score,
                  hint: momentum.trendDelta >= 0
                      ? 'Ритм держится или растёт'
                      : 'Ритм слабеет — самое время вернуться',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _VizMetric(
                  label: 'Стабильность · 7д',
                  value: consistency7.percent,
                  hint: '${consistency7.metCount}/${consistency7.windowSize} дней',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _VizMetric(
                  label: 'Стабильность · 30д',
                  value: consistency30.percent,
                  hint:
                      '${consistency30.metCount}/${consistency30.windowSize} дней',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Моментум учитывает регулярность недели, динамику к прошлой неделе '
            'и возвращение после пропуска. Стабильность — доля дней с готовым '
            'отчётом, а не серия подряд.',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

class _EditorialDarkCard extends StatelessWidget {
  const _EditorialDarkCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ProfileEditorialPalette.cardSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }
}

class _VizMetric extends StatelessWidget {
  const _VizMetric({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final int value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(color: p.inkMuted, fontSize: 11),
        ),
        const SizedBox(height: AppSpacing.xxs),
        PrimeAnimatedNumber(
          value: value,
          style: AppTypography.numericSm,
        ),
        Text(
          hint,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(
            color: p.inkMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
