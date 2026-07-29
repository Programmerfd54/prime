import 'package:flutter/material.dart';

import '../../../core/engines/consistency_engine.dart';
import '../../../core/engines/momentum_engine.dart';
import '../../../core/engines/recovery_engine.dart';
import '../../../core/media/media_urls.dart';
import '../../../core/metrics/calendar_metrics.dart';
import '../../../design/tokens.dart';
import '../../../design/visuals/gauges/gauges.dart';
import '../../../models/achievement.dart';
import '../../../models/report.dart';
import '../../components/app_primary_button.dart';
import '../components/prime_glass_overlay.dart';
import '../tokens/kit_layout.dart';
import 'profile_editorial_widgets.dart';
import 'profile_typography.dart';

/// «Сейчас в работе» — one expressive card (TZ §8).
class ProfileCurrentCycleSection extends StatelessWidget {
  const ProfileCurrentCycleSection({
    super.key,
    required this.successfulDays,
    required this.currentStreak,
    required this.primePoints,
    this.bestStreak = 0,
    this.cyclePacePercent,
    this.calendar,
    this.streakShields = 0,
    this.shieldPending = false,
    this.habitName,
    this.memberPhotoUrls = const [],
    this.reportedToday = false,
    this.onChooseHabit,
    this.onCheckIn,
    this.onBuyShield,
    this.onUseShield,
  });

  final int successfulDays;
  final int currentStreak;
  final int primePoints;
  final int bestStreak;
  final int? cyclePacePercent;
  final CalendarOut? calendar;
  final int streakShields;
  final bool shieldPending;
  final String? habitName;
  final List<String> memberPhotoUrls;
  final bool reportedToday;
  final VoidCallback? onChooseHabit;
  final VoidCallback? onCheckIn;
  final VoidCallback? onBuyShield;
  final VoidCallback? onUseShield;

  @override
  Widget build(BuildContext context) {
    final insufficient = successfulDays == 0 && currentStreak == 0;
    if (insufficient) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Сейчас в работе', style: _sectionTitle()),
          const SizedBox(height: AppSpacing.sm),
          _ProfileSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Начните первый цикл',
                  style: ProfileTypography.cardTitle.copyWith(
                    color: ProfilePalette.offWhite,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Выберите привычку и отправьте первый отчёт — '
                  'здесь появятся метрики прогресса.',
                  style: ProfileTypography.secondary.copyWith(
                    color: ProfilePalette.coolGrey.withValues(alpha: 0.85),
                  ),
                ),
                if (onChooseHabit != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppPrimaryButton(
                    label: 'Выбрать привычку',
                    onPressed: onChooseHabit,
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    final cycleDay = successfulDays == 0 ? 0 : successfulDays % 30;
    final pace = calendar == null
        ? (successfulDays == 0 ? 0.0 : cycleDay / 30)
        : CalendarMetrics.paceRatio(calendar!);
    final paceDisplay = cyclePacePercent != null
        ? '$cyclePacePercent%'
        : '${(pace * 100).round()}%';
    final streakRatio = _streakProgress(currentStreak, bestStreak);
    final primesRatio =
        primePoints <= 0 ? 0.0 : (primePoints / 50).clamp(0.0, 1.0);
    final showShield =
        shieldPending || streakShields > 0 || onBuyShield != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Сейчас в работе', style: _sectionTitle()),
        const SizedBox(height: AppSpacing.sm),
        _ProfileSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (habitName?.isNotEmpty == true) ...[
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: ProfilePalette.brand.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.bolt_rounded,
                        color: ProfilePalette.brandSoft,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            habitName!,
                            style: ProfileTypography.cardTitle.copyWith(
                              color: ProfilePalette.offWhite,
                            ),
                          ),
                          Text(
                            'День $cycleDay из 30',
                            style: ProfileTypography.secondary.copyWith(
                              color: ProfilePalette.coolGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 340;
                  final arc = PrimeSegmentedArc(
                    progress: pace,
                    valueLabel: '$cycleDay',
                    caption: 'день цикла',
                    size: narrow ? 108 : 128,
                  );
                  final rings = PrimeRingTrio.metrics(
                    streak: streakRatio,
                    streakDisplay: '$currentStreak',
                    primes: primesRatio,
                    primesDisplay: '$primePoints',
                    pace: pace,
                    paceDisplay: paceDisplay,
                    size: narrow ? 60 : 68,
                  );
                  if (narrow) {
                    return Column(
                      children: [
                        Center(child: arc),
                        const SizedBox(height: AppSpacing.md),
                        rings,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      arc,
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: rings),
                    ],
                  );
                },
              ),
              if (memberPhotoUrls.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _TeamAvatarRow(urls: memberPhotoUrls),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(
                    reportedToday
                        ? Icons.check_circle_outline
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: reportedToday
                        ? ProfilePalette.mint
                        : ProfilePalette.coolGrey,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      reportedToday
                          ? 'Сегодня отмечено'
                          : 'Сегодня ещё не отмечено',
                      style: ProfileTypography.secondary.copyWith(
                        color: ProfilePalette.coolGrey,
                      ),
                    ),
                  ),
                  if (!reportedToday && onCheckIn != null)
                    TextButton(
                      onPressed: onCheckIn,
                      child: Text(
                        'Отметить',
                        style: ProfileTypography.cta.copyWith(
                          color: ProfilePalette.brandSoft,
                        ),
                      ),
                    ),
                ],
              ),
              if (showShield) ...[
                const SizedBox(height: AppSpacing.md),
                Divider(color: ProfilePalette.coolGrey.withValues(alpha: 0.15)),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 20,
                      color: shieldPending
                          ? ProfilePalette.brandSoft
                          : ProfilePalette.coolGrey,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        shieldPending
                            ? 'Щит активен — пропуск не сбросит серию'
                            : 'Щитов: $streakShields',
                        style: ProfileTypography.secondary.copyWith(
                          color: ProfilePalette.coolGrey,
                        ),
                      ),
                    ),
                    if (onUseShield != null &&
                        streakShields > 0 &&
                        !shieldPending)
                      TextButton(
                        onPressed: onUseShield,
                        child: Text(
                          'Исп.',
                          style: ProfileTypography.cta.copyWith(
                            color: ProfilePalette.brandSoft,
                          ),
                        ),
                      ),
                    if (onBuyShield != null && !shieldPending)
                      TextButton(
                        onPressed: onBuyShield,
                        child: Text(
                          'Купить',
                          style: ProfileTypography.cta.copyWith(
                            color: ProfilePalette.brandSoft,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static double _streakProgress(int current, int best) {
    if (current <= 0) return 0;
    final target = best > current ? best : (current >= 30 ? current : 30);
    return (current / target).clamp(0.0, 1.0);
  }
}

/// Consolidated analytics — no zero wall (TZ §9).
class ProfileAnalyticsSection extends StatefulWidget {
  const ProfileAnalyticsSection({
    super.key,
    this.calendar,
    this.insights = const [],
    this.onInsightOpened,
    this.onCheckIn,
  });

  final CalendarOut? calendar;
  final List<ProfileInsightModel> insights;
  final ValueChanged<ProfileInsightModel>? onInsightOpened;
  final VoidCallback? onCheckIn;

  @override
  State<ProfileAnalyticsSection> createState() =>
      _ProfileAnalyticsSectionState();
}

class _ProfileAnalyticsSectionState extends State<ProfileAnalyticsSection> {
  var _windowDays = 7;

  @override
  Widget build(BuildContext context) {
    final calendar = widget.calendar;
    if (calendar == null ||
        (calendar.successfulDays == 0 && calendar.currentStreak == 0)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Аналитика', style: _sectionTitle()),
          const SizedBox(height: AppSpacing.sm),
          _ProfileSurface(
            child: Column(
              children: [
                Icon(
                  Icons.bar_chart_rounded,
                  size: 40,
                  color: ProfilePalette.brandSoft.withValues(alpha: 0.5),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Аналитика появится после нескольких отметок',
                  style: ProfileTypography.cardTitle.copyWith(
                    color: ProfilePalette.offWhite,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Сделайте первый check-in — здесь появятся momentum, '
                  'стабильность и recovery.',
                  style: ProfileTypography.secondary.copyWith(
                    color: ProfilePalette.coolGrey.withValues(alpha: 0.85),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                _PreviewMetrics(),
                if (widget.onCheckIn != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppPrimaryButton(
                    label: 'Сделать первый check-in',
                    onPressed: widget.onCheckIn,
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

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
    final consistency =
        _windowDays == 7 ? consistency7 : consistency30;
    final metFlags = calendar.days.map((d) => d.reported).toList();
    final misses = RecoveryEngine.consecutiveMissesFromTail(metFlags);
    final recovery = RecoveryEngine.suggest(consecutiveMisses: misses);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.insights.isNotEmpty) ...[
          Text('Insights', style: _sectionTitle()),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.insights.length.clamp(0, 3),
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) {
                final insight = widget.insights[i];
                return SizedBox(
                  width: 220,
                  child: ProfileInsightCard(
                    title: insight.title,
                    message: insight.message,
                    onTap: widget.onInsightOpened == null
                        ? null
                        : () => widget.onInsightOpened!(insight),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Row(
          children: [
            Expanded(child: Text('Аналитика', style: _sectionTitle())),
            _PeriodToggle(
              windowDays: _windowDays,
              onChanged: (days) => setState(() => _windowDays = days),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _ProfileSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CompactMetric(
                label: 'Моментум',
                value: '${momentum.score}',
                hint: momentum.trendDelta >= 0 ? 'Ритм держится' : 'Ритм слабеет',
                accent: ProfilePalette.brandSoft,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _CompactMetric(
                      label: 'Стаб. $_windowDays',
                      value: '${consistency.percent}%',
                      hint:
                          '${consistency.metCount}/${consistency.windowSize}',
                      accent: ProfilePalette.mint,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _CompactMetric(
                      label: 'Recovery',
                      value: misses == 0 ? 'OK' : '$misses',
                      hint: _recoveryHint(recovery.action),
                      accent: misses == 0
                          ? ProfilePalette.mint
                          : ProfilePalette.coral,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _WeeklyHeatmap(days: calendar.days),
            ],
          ),
        ),
      ],
    );
  }

  static String _recoveryHint(RecoveryAction action) {
    return switch (action) {
      RecoveryAction.none => 'В ритме',
      RecoveryAction.comeBackTomorrow => '1 пропуск',
      RecoveryAction.tryShortVersion => 'Короткая версия',
      RecoveryAction.askTeamForSupport => 'Нужна команда',
    };
  }
}

class ProfileInsightCard extends StatelessWidget {
  const ProfileInsightCard({
    super.key,
    required this.title,
    required this.message,
    this.onTap,
  });

  final String title;
  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _ProfileSurface(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome,
            size: 16,
            color: ProfilePalette.brandSoft,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ProfileTypography.cardTitle.copyWith(
              color: ProfilePalette.offWhite,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: ProfileTypography.secondary.copyWith(
                color: ProfilePalette.coolGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.windowDays, required this.onChanged});

  final int windowDays;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ProfilePalette.charcoal,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PeriodChip(
            label: '7д',
            selected: windowDays == 7,
            onTap: () => onChanged(7),
          ),
          _PeriodChip(
            label: '30д',
            selected: windowDays == 30,
            onTap: () => onChanged(30),
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? ProfilePalette.brandSoft.withValues(alpha: 0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: ProfileTypography.metricLabel.copyWith(
            color: selected
                ? ProfilePalette.offWhite
                : ProfilePalette.coolGrey.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

class _WeeklyHeatmap extends StatelessWidget {
  const _WeeklyHeatmap({required this.days});

  final List<CalendarDay> days;

  @override
  Widget build(BuildContext context) {
    final recent = days.length <= 7 ? days : days.sublist(days.length - 7);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Неделя',
          style: ProfileTypography.metricLabel.copyWith(
            color: ProfilePalette.coolGrey.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            for (final day in recent)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: day.reported
                            ? ProfilePalette.mint.withValues(alpha: 0.75)
                            : day.completed
                                ? ProfilePalette.brandSoft
                                    .withValues(alpha: 0.35)
                                : ProfilePalette.coolGrey
                                    .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TeamAvatarRow extends StatelessWidget {
  const _TeamAvatarRow({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final slots = urls.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Команда · ${slots.length}/6',
          style: ProfileTypography.metricLabel.copyWith(
            color: ProfilePalette.coolGrey.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            for (var i = 0; i < 6; i++)
              Padding(
                padding: EdgeInsets.only(right: i < 5 ? 6 : 0),
                child: _MemberAvatar(
                  url: i < slots.length ? absolutePhotoUrl(slots[i]) : null,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ProfilePalette.coolGrey.withValues(alpha: 0.15),
        border: Border.all(
          color: ProfilePalette.coolGrey.withValues(alpha: 0.25),
        ),
        image: url != null && url!.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(url!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: url == null || url!.isEmpty
          ? Icon(
              Icons.person_outline,
              size: 16,
              color: ProfilePalette.coolGrey.withValues(alpha: 0.7),
            )
          : null,
    );
  }
}

class _PreviewMetrics extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CompactMetric(
            label: 'Моментум',
            value: '—',
            hint: 'скоро',
            accent: ProfilePalette.brandSoft.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _CompactMetric(
            label: 'Стаб. 7д',
            value: '—',
            hint: 'скоро',
            accent: ProfilePalette.mint.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _CompactMetric(
            label: 'Стаб. 30д',
            value: '—',
            hint: 'скоро',
            accent: ProfilePalette.coolGrey.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.label,
    required this.value,
    required this.hint,
    required this.accent,
  });

  final String label;
  final String value;
  final String hint;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ProfileTypography.metricLabel.copyWith(
            color: ProfilePalette.coolGrey.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: ProfileTypography.displayName.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w500,
            color: accent,
          ),
        ),
        Text(
          hint,
          style: ProfileTypography.metricLabel.copyWith(
            color: ProfilePalette.coolGrey.withValues(alpha: 0.65),
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ProfileSurface extends StatelessWidget {
  const _ProfileSurface({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surface = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ProfilePalette.charcoal,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ProfilePalette.coolGrey.withValues(alpha: 0.08),
        ),
      ),
      child: child,
    );
    if (onTap == null) return surface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: surface,
      ),
    );
  }
}

TextStyle _sectionTitle() {
  return ProfileTypography.sectionTitle.copyWith(
    color: ProfilePalette.offWhite,
  );
}

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

/// Horizontal achievements carousel (TZ §10).
class ProfileAchievementsSection extends StatelessWidget {
  const ProfileAchievementsSection({
    super.key,
    required this.achievements,
    required this.successfulDays,
  });

  final List<AchievementModel> achievements;
  final int successfulDays;

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Достижения', style: _sectionTitle()),
          const SizedBox(height: AppSpacing.sm),
          _ProfileSurface(
            child: Column(
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 40,
                  color: ProfilePalette.warmYellow.withValues(alpha: 0.85),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Коллекция ждёт первый шаг',
                  style: ProfileTypography.cardTitle.copyWith(
                    color: ProfilePalette.offWhite,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Выберите привычку — здесь появятся этапы и milestones.',
                  style: ProfileTypography.secondary.copyWith(
                    color: ProfilePalette.coolGrey.withValues(alpha: 0.85),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    final sorted = [...achievements]
      ..sort((a, b) => a.requiredDays.compareTo(b.requiredDays));
    AchievementModel? next;
    for (final a in sorted) {
      if (!a.unlocked) {
        next = a;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Достижения', style: _sectionTitle()),
        const SizedBox(height: AppSpacing.sm),
        if (next != null) ...[
          _ProfileAchievementHeroCard(
            achievement: next,
            successfulDays: successfulDays,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        SizedBox(
          height: 156,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) {
              final a = sorted[i];
              return SizedBox(
                width: 196,
                child: _ProfileAchievementCarouselCard(
                  achievement: a,
                  successfulDays: successfulDays,
                  isNext: a == next,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProfileAchievementHeroCard extends StatelessWidget {
  const _ProfileAchievementHeroCard({
    required this.achievement,
    required this.successfulDays,
  });

  final AchievementModel achievement;
  final int successfulDays;

  @override
  Widget build(BuildContext context) {
    final progress = achievement.requiredDays == 0
        ? 0.0
        : (successfulDays / achievement.requiredDays).clamp(0.0, 1.0);

    return _ProfileSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ближайшая цель',
            style: ProfileTypography.metricLabel.copyWith(
              color: ProfilePalette.coolGrey,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            achievement.name,
            style: ProfileTypography.cardTitle.copyWith(
              color: ProfilePalette.offWhite,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: ProfilePalette.coolGrey.withValues(alpha: 0.15),
              color: ProfilePalette.warmYellow,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '$successfulDays / ${achievement.requiredDays} дней',
            style: ProfileTypography.secondary.copyWith(
              color: ProfilePalette.coolGrey,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAchievementCarouselCard extends StatelessWidget {
  const _ProfileAchievementCarouselCard({
    required this.achievement,
    required this.successfulDays,
    required this.isNext,
  });

  final AchievementModel achievement;
  final int successfulDays;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    final accent = unlocked
        ? ProfilePalette.mint
        : isNext
            ? ProfilePalette.warmYellow
            : ProfilePalette.coolGrey;

    return _ProfileSurface(
      child: SizedBox(
        height: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(Icons.military_tech_outlined, color: accent, size: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ProfileTypography.cardTitle.copyWith(
                    color: ProfilePalette.offWhite,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  unlocked
                      ? 'Получено'
                      : '${achievement.requiredDays} дн.',
                  style: ProfileTypography.metricLabel.copyWith(color: accent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared habits/groups — hidden when empty (TZ §11).
class ProfileSharedContextSection extends StatelessWidget {
  const ProfileSharedContextSection({
    super.key,
    this.sharedHabits = const [],
    this.sharedGroups = const [],
  });

  final List<String> sharedHabits;
  final List<String> sharedGroups;

  @override
  Widget build(BuildContext context) {
    if (sharedHabits.isEmpty && sharedGroups.isEmpty) {
      return const SizedBox.shrink();
    }

    final tags = profileHabitTagsFromNames(sharedHabits);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Общее с вами', style: _sectionTitle()),
        const SizedBox(height: AppSpacing.sm),
        _ProfileSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tags.isNotEmpty) ...[
                Text(
                  'Привычки',
                  style: ProfileTypography.metricLabel.copyWith(
                    color: ProfilePalette.coolGrey,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                ProfileHabitTagsRow(tags: tags),
              ],
              if (sharedGroups.isNotEmpty) ...[
                if (tags.isNotEmpty) const SizedBox(height: AppSpacing.sm),
                Text(
                  'Группы',
                  style: ProfileTypography.metricLabel.copyWith(
                    color: ProfilePalette.coolGrey,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final g in sharedGroups)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: ProfilePalette.coolGrey.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          g,
                          style: ProfileTypography.tag.copyWith(
                            color: ProfilePalette.offWhite.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Centers profile sections on tablet/desktop (TZ §16).
class ProfileContentWidth extends StatelessWidget {
  const ProfileContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: ProfileHeroCard.maxContentWidth,
        ),
        child: child,
      ),
    );
  }
}

/// Compact metadata row for AboutSection (TZ §12).
class ProfileAboutRow {
  const ProfileAboutRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

/// About block — compact rows, not a large text card (TZ §12).
class ProfileAboutSection extends StatelessWidget {
  const ProfileAboutSection({super.key, required this.rows});

  final List<ProfileAboutRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('О себе', style: _sectionTitle()),
        const SizedBox(height: AppSpacing.sm),
        _ProfileSurface(
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Divider(
                    height: 1,
                    color: ProfilePalette.coolGrey.withValues(alpha: 0.12),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                _AboutRow(row: rows[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.row});

  final ProfileAboutRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(row.icon, size: 18, color: ProfilePalette.coolGrey),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.label,
                style: ProfileTypography.metricLabel.copyWith(
                  color: ProfilePalette.coolGrey.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                row.value,
                style: ProfileTypography.secondary.copyWith(
                  color: ProfilePalette.offWhite.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Glass contextual bar for public profiles (TZ §13).
class ProfileActionBar extends StatelessWidget {
  const ProfileActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryLoading = false,
    this.secondaryLabel,
    this.onSecondary,
    this.onMore,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryLoading;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final VoidCallback? onMore;

  static double heightFor(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return KitLayout.contextualBarMin + bottom + AppSpacing.md;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          0,
        ),
        child: PrimeGlassOverlay(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm + bottom * 0.25,
          ),
          child: Row(
            children: [
              if (secondaryLabel != null && onSecondary != null) ...[
                OutlinedButton(
                  onPressed: onSecondary,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ProfilePalette.offWhite,
                    side: BorderSide(
                      color: ProfilePalette.coolGrey.withValues(alpha: 0.35),
                    ),
                    minimumSize: const Size(0, AppControlHeights.buttonCompact),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  ),
                  child: Text(
                    secondaryLabel!,
                    style: ProfileTypography.cta.copyWith(fontSize: 14),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: primaryLoading ? null : onPrimary,
                  style: FilledButton.styleFrom(
                    backgroundColor: ProfilePalette.warmYellow,
                    foregroundColor: ProfilePalette.charcoal,
                    minimumSize:
                        const Size.fromHeight(AppControlHeights.buttonCompact),
                  ),
                  child: primaryLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          primaryLabel,
                          style: ProfileTypography.cta.copyWith(
                            color: ProfilePalette.charcoal,
                          ),
                        ),
                ),
              ),
              if (onMore != null)
                IconButton(
                  onPressed: onMore,
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: ProfilePalette.offWhite.withValues(alpha: 0.85),
                  ),
                  tooltip: 'Ещё',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formats member-since date for profile About rows.
String profileMemberSinceLabel(DateTime date) {
  const months = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];
  final month = months[date.month - 1];
  return '${date.day} $month ${date.year}';
}
