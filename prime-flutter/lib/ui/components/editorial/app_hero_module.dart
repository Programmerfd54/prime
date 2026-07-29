import 'package:flutter/material.dart';

import '../../../core/metrics/calendar_metrics.dart';
import '../../../design/glass.dart';
import '../../../design/motion.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../design/visuals/charts/charts.dart';
import '../../../design/visuals/gauges/gauges.dart';
import '../../../design/visuals/habit_art.dart';
import '../../../design/visuals/scene_art.dart';
import '../app_hero_button.dart';
import '../app_secondary_button.dart';
import 'editorial_title_text.dart';

/// Full-width hero module — a purple editorial glass surface with an
/// intentional action and a small progress signal.
class AppHeroModule extends StatelessWidget {
  const AppHeroModule({
    super.key,
    required this.title,
    required this.body,
    required this.artKind,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.progress,
    this.progressLabel,
    this.badge,
  });

  final String title;
  final String body;
  final HabitArtKind artKind;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final double? progress;
  final String? progressLabel;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final accent = habitArtAccent(artKind);
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;

    const onHero = Colors.white;
    const onHeroMuted = Color(0xCCFFFFFF);

    Widget content({
      required HabitArtKind kind,
      required double artSize,
      required bool vertical,
    }) {
      final textColumn = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                badge!,
                style: AppTypography.caption.copyWith(
                  color: onHero,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          EditorialTitleText(
            text: title,
            color: onHero,
            style: AppTypography.titleSerif.copyWith(fontSize: 24),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: AppTypography.bodySecondary.copyWith(color: onHeroMuted),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppHeroButton(
              label: actionLabel!,
              onPressed: onAction,
            ),
          ],
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: AppSpacing.xs),
            AppSecondaryButton(
              label: secondaryLabel!,
              onPressed: onSecondary,
            ),
          ],
        ],
      );

      if (vertical) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (progress != null)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: PrimeRadialProgress(
                      progress: progress!,
                      valueLabel: progressLabel ?? '',
                      size: 72,
                      stroke: 7,
                      color: Colors.white,
                      trackColor: Colors.white.withValues(alpha: 0.2),
                      animate: true,
                    ),
                  ),
                SceneArt(kind: sceneFromHabit(kind), size: artSize),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            textColumn,
          ],
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: textColumn),
          const SizedBox(width: AppSpacing.sm),
          Column(
            children: [
              if (progress != null)
                PrimeRadialProgress(
                  progress: progress!,
                  valueLabel: progressLabel ?? '',
                  size: 88,
                  stroke: 8,
                  color: Colors.white,
                  trackColor: Colors.white.withValues(alpha: 0.2),
                  animate: true,
                ),
              const SizedBox(height: AppSpacing.xs),
              SceneArt(kind: sceneFromHabit(kind), size: artSize),
            ],
          ),
        ],
      );
    }

    final heroStart = Color.lerp(AppColors.premiumDarkViolet, accent, 0.24)!;
    final heroMid = Color.lerp(AppColors.primaryDeep, accent, 0.16)!;
    final heroEnd = Color.lerp(AppColors.deepSurface, accent, 0.12)!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [heroStart, heroMid, heroEnd],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: GlassContainer(
          width: double.infinity,
          allowBlurOnWeb: true,
          sigma: 24,
          fillOpacity: 0.10,
          glow: AppGlow.violet(opacity: 0.20),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Row + 96px art overflows when the hero is squeezed (narrow
              // chrome / split view). Prefer stacked layout below ~280dp.
              final vertical = largeText || constraints.maxWidth < 280;
              final artSize = vertical
                  ? (constraints.maxWidth < 200 ? 56.0 : 72.0)
                  : (constraints.maxWidth < 360 ? 72.0 : 96.0);
              return content(
                kind: artKind,
                artSize: artSize,
                vertical: vertical,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// New-user journey: habit → team → day closes together.
class AppJourneyStrip extends StatelessWidget {
  const AppJourneyStrip({
    super.key,
    this.habitDone = false,
    this.teamDone = false,
    this.firstDayDone = false,
  });

  final bool habitDone;
  final bool teamDone;
  final bool firstDayDone;

  @override
  Widget build(BuildContext context) {
    final steps = <JourneyStep>[
      JourneyStep(
        label: 'Выберите привычку',
        icon: Icons.menu_book_outlined,
        status: habitDone ? JourneyStepStatus.done : JourneyStepStatus.current,
      ),
      JourneyStep(
        label: 'Соберите команду из 6',
        icon: Icons.groups_outlined,
        status: teamDone
            ? JourneyStepStatus.done
            : (habitDone
                ? JourneyStepStatus.current
                : JourneyStepStatus.upcoming),
      ),
      JourneyStep(
        label: 'День закрывается вместе',
        icon: Icons.done_all_rounded,
        status: firstDayDone
            ? JourneyStepStatus.done
            : (teamDone
                ? JourneyStepStatus.current
                : JourneyStepStatus.upcoming),
      ),
    ];

    return PrimeJourneyStepper(steps: steps);
  }
}

/// Bento metrics — light island with cycle day, primes, week chart.
class AppBentoMetrics extends StatelessWidget {
  const AppBentoMetrics({
    super.key,
    required this.streak,
    required this.primes,
    required this.successDays,
    this.bestStreak = 0,
    this.cycleDay,
    this.onPrimesTap,
    this.weeklyBuckets = const [],
  });

  final int streak;
  final int primes;
  final int successDays;
  final int bestStreak;
  final int? cycleDay;
  final VoidCallback? onPrimesTap;
  final List<WeekDayBucket> weeklyBuckets;

  @override
  Widget build(BuildContext context) {
    final isEmpty = streak == 0 && primes == 0 && successDays == 0;
    final dayInCycle =
        cycleDay ?? (successDays == 0 ? 0 : ((successDays - 1) % 30) + 1);
    final pace = isEmpty ? 0.0 : (dayInCycle / 30.0).clamp(0.0, 1.0);
    final completedThisWeek =
        weeklyBuckets.where((b) => b.completed || b.reported).length;
    final bestDayLabel = weeklyBuckets
        .where((b) => b.completed)
        .map((b) => b.label)
        .cast<String?>()
        .followedBy([null]).first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassContainer(
          width: double.infinity,
          glow: AppGlow.violet(opacity: 0.14),
          child: Column(
            children: [
              Text(
                isEmpty ? 'Сегодняшний темп' : 'Ваш темп',
                style: AppTypography.titleSerif,
              ),
              const SizedBox(height: AppSpacing.md),
              PrimeSegmentedArc(
                progress: isEmpty ? 0.04 : pace.clamp(0.04, 1.0),
                valueLabel: isEmpty ? '0' : '$dayInCycle',
                caption: 'темп цикла',
                size: 140,
              ),
              const SizedBox(height: AppSpacing.md),
              if (isEmpty)
                Text(
                  'После первого отчёта здесь появятся день цикла, серия и Праймы',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySecondary,
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked =
                        MediaQuery.textScalerOf(context).scale(1) >= 1.5 ||
                            constraints.maxWidth < 320;
                    final stats = [
                      _GlassStat(
                        value: streak,
                        label: 'серия',
                        hint: bestStreak > streak ? 'рекорд $bestStreak' : null,
                      ),
                      _GlassStat(
                        value: primes,
                        label: 'Праймы',
                        hint: 'до следующего +1',
                        onTap: onPrimesTap,
                      ),
                      _GlassStat(
                        value: successDays,
                        label: 'полных дней команды',
                      ),
                    ];
                    if (stacked) {
                      return Column(
                        children: [
                          for (var i = 0; i < stats.length; i++) ...[
                            if (i > 0) const SizedBox(height: AppSpacing.sm),
                            SizedBox(width: double.infinity, child: stats[i]),
                          ],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        for (var i = 0; i < stats.length; i++) ...[
                          if (i > 0) const SizedBox(width: AppSpacing.sm),
                          Expanded(child: stats[i]),
                        ],
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Неделя',
                      style: AppTypography.titleSerif.copyWith(fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      isEmpty
                          ? 'ещё нет отметок'
                          : '$completedThisWeek из 7 дней',
                      textAlign: TextAlign.end,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primarySoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (bestDayLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Лучший день: $bestDayLabel',
                  style: AppTypography.caption,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              PrimeWeeklyBars(
                buckets: weeklyBuckets,
                height: 88,
                showLegend: MediaQuery.textScalerOf(context).scale(1) < 1.5,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassStat extends StatelessWidget {
  const _GlassStat({
    required this.value,
    required this.label,
    this.hint,
    this.onTap,
  });

  final int value;
  final String label;
  final String? hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.elevatedSurface.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(AppRadius.bentoInner),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.bentoInner),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PrimeAnimatedNumber(
                value: value,
                style: AppTypography.numericSm,
              ),
              Text(label, style: AppTypography.caption),
              if (hint != null)
                Text(
                  hint!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(fontSize: 10),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
