import 'package:flutter/material.dart';

import '../../../core/media/media_urls.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../l10n/copy.dart';
import '../../../design/visuals/charts/prime_radial_progress.dart';
import '../../../design/visuals/habit_art.dart';
import '../../../models/group.dart';
import '../../../models/report.dart';
import '../../../ui/components/app_compact_button.dart';
import '../components/prime_content_card.dart';
import '../components/prime_social_card.dart';
import '../tokens/kit_layout.dart';
import '../tokens/kit_surfaces.dart';
import '../tokens/kit_typography.dart';

/// Section header with serif title and optional trailing link.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: KitTypography.sectionTitle.copyWith(
              fontSize: 20,
              color: p.ink,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: KitTypography.caption.copyWith(color: p.inkMuted),
            ),
          ),
      ],
    );
  }
}

/// Two-level greeting with streak badge pill.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.greeting,
    required this.name,
    required this.dateLabel,
    required this.streak,
    this.onAvatarTap,
    this.photoUrl,
    this.trailing,
  });

  final String greeting;
  final String name;
  final String dateLabel;
  final int streak;
  final VoidCallback? onAvatarTap;
  final String? photoUrl;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
            onTap: onAvatarTap,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [p.brandBright, p.brandSoft],
                ),
              ),
              child: CircleAvatar(
                radius: KitLayout.headerAvatar / 2 - 2,
                backgroundColor: p.surfaceElevated,
                backgroundImage: () {
                  final url = absolutePhotoUrl(photoUrl);
                  return url != null ? NetworkImage(url) : null;
                }(),
                child: (photoUrl == null || photoUrl!.trim().isEmpty) &&
                        name.isNotEmpty
                    ? Text(
                        name[0].toUpperCase(),
                        style: KitTypography.cardTitle.copyWith(color: p.ink),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: KitTypography.caption.copyWith(color: p.inkMuted),
                ),
                Text(
                  name.isEmpty ? 'ПРАЙМ' : name,
                  style: KitTypography.cardTitle.copyWith(
                    fontSize: 18,
                    color: p.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  dateLabel,
                  style: KitTypography.caption.copyWith(
                    color: p.inkMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (streak > 0) ...[
            _StreakBadge(streak: streak),
            const SizedBox(width: AppSpacing.xs),
          ],
          if (trailing != null) trailing!,
      ],
    );
  }
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: p.brand.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: p.brand.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 16, color: p.coral),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: KitTypography.chip.copyWith(
              color: p.ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal category tiles — habit program types.
class HomeCategoriesRow extends StatelessWidget {
  const HomeCategoriesRow({
    super.key,
    this.onCategoryTap,
    this.onSeeAll,
    this.activeKind,
  });

  final ValueChanged<HabitArtKind>? onCategoryTap;
  final VoidCallback? onSeeAll;
  final HabitArtKind? activeKind;

  static const _categories = [
    (HabitArtKind.focus, 'Фокус', Icons.center_focus_strong_outlined),
    (HabitArtKind.read, 'Чтение', Icons.menu_book_outlined),
    (HabitArtKind.sleep, 'Сон', Icons.nightlight_outlined),
    (HabitArtKind.social, 'Общение', Icons.groups_outlined),
    (HabitArtKind.charge, 'Зарядка', Icons.fitness_center_outlined),
    (HabitArtKind.detox, 'Детокс', Icons.phonelink_off_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeader(
          title: 'Категории',
          actionLabel: 'Смотреть все >',
          onAction: onSeeAll,
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
            itemBuilder: (context, index) {
              final (kind, label, icon) = _categories[index];
              final selected = activeKind == kind;
              return _CategoryTile(
                label: label,
                icon: icon,
                accent: habitArtAccent(kind),
                selected: selected,
                onTap: () => onCategoryTap?.call(kind),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Material(
      color: p.surfaceElevated,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          width: 80,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? accent : p.hairline,
              width: selected ? 1.5 : 0.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: selected ? accent : p.inkSecondary),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                label,
                style: KitTypography.caption.copyWith(
                  color: selected ? p.ink : p.inkMuted,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal scroll of metric cards with progress rings.
class HomeProgressMetrics extends StatelessWidget {
  const HomeProgressMetrics({
    super.key,
    required this.streak,
    required this.primes,
    required this.successDays,
    this.onPrimesTap,
  });

  final int streak;
  final int primes;
  final int successDays;
  final VoidCallback? onPrimesTap;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HomeSectionHeader(title: 'Ваш прогресс'),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 130,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _ProgressMetricCard(
                icon: Icons.local_fire_department_outlined,
                label: 'Серия',
                value: '$streak',
                suffix: ' дн.',
                progress: (streak / 30).clamp(0.05, 1.0),
                accent: p.coral,
              ),
              const SizedBox(width: AppSpacing.xs),
              _ProgressMetricCard(
                icon: Icons.star_outline_rounded,
                label: 'Праймы',
                value: '$primes',
                progress: (primes / 100).clamp(0.05, 1.0),
                accent: p.achievementAmber,
                onTap: onPrimesTap,
              ),
              const SizedBox(width: AppSpacing.xs),
              _ProgressMetricCard(
                icon: Icons.check_circle_outline_rounded,
                label: 'Успешных',
                value: '$successDays',
                suffix: ' дн.',
                progress: (successDays / 30).clamp(0.05, 1.0),
                accent: p.mint,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressMetricCard extends StatelessWidget {
  const _ProgressMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.progress,
    required this.accent,
    this.suffix = '',
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String suffix;
  final double progress;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final card = Container(
      width: 120,
      height: 130,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: kitSurfaceDecoration(context, PrimeSurfaceLevel.solid),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const Spacer(),
              SizedBox(
                width: 36,
                height: 36,
                child: PrimeRadialProgress(
                  progress: progress,
                  valueLabel: '',
                  size: 36,
                  stroke: 3,
                  color: accent,
                  animate: true,
                ),
              ),
            ],
          ),
          const Spacer(),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: KitTypography.metricMedium.copyWith(
                    color: p.ink,
                    fontSize: 22,
                  ),
                ),
                if (suffix.isNotEmpty)
                  TextSpan(
                    text: suffix,
                    style: KitTypography.caption.copyWith(color: p.inkMuted),
                  ),
              ],
            ),
          ),
          Text(
            label,
            style: KitTypography.caption.copyWith(color: p.inkMuted),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: card,
      ),
    );
  }
}

/// Compact 14-day streak strip.
class HomeCalendarStrip extends StatelessWidget {
  const HomeCalendarStrip({
    super.key,
    this.calendar,
    this.onSeeAll,
  });

  final CalendarOut? calendar;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final today = calendar?.today ?? DateTime.now();
    final days = calendar?.days ?? const <CalendarDay>[];
    final byDate = {for (final d in days) _dateKey(d.date): d};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeader(
          title: 'Календарь',
          actionLabel: 'Подробнее >',
          onAction: onSeeAll,
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          decoration: kitSurfaceDecoration(context, PrimeSurfaceLevel.solid),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 13; i >= 0; i--)
                _DayDot(
                  date: today.subtract(Duration(days: i)),
                  day: byDate[_dateKey(today.subtract(Duration(days: i)))],
                  accent: p.mint,
                  missColor: p.coral.withValues(alpha: 0.35),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.date,
    required this.day,
    required this.accent,
    required this.missColor,
  });

  final DateTime date;
  final CalendarDay? day;
  final Color accent;
  final Color missColor;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final hasReport = day != null && (day!.reported || day!.completed);
    final isToday = _sameDay(date, DateTime.now());
    final isFuture = date.isAfter(DateTime.now());
    final missed = !isFuture && !hasReport && day != null;

    Color fill;
    if (hasReport) {
      fill = accent;
    } else if (missed) {
      fill = missColor;
    } else if (isFuture) {
      fill = p.surfaceSoft;
    } else {
      fill = p.hairline;
    }

    return Column(
      children: [
        Container(
          width: isToday ? 14 : 10,
          height: isToday ? 14 : 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: isToday
                ? Border.all(color: p.coral, width: 2)
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${date.day}',
          style: KitTypography.caption.copyWith(
            fontSize: 9,
            color: isToday ? p.ink : p.inkMuted,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Enhanced team pulse with progress bar.
class HomeTeamPulseCard extends StatelessWidget {
  const HomeTeamPulseCard({
    super.key,
    required this.title,
    required this.teamReady,
    required this.teamTotal,
    required this.avatars,
    this.subtitle,
    this.waitingNames = const [],
    this.pulseStatus,
    this.onTap,
    this.onNudge,
  });

  final String title;
  final String? subtitle;
  final int teamReady;
  final int teamTotal;
  final List<PrimeSocialAvatar> avatars;
  final List<String> waitingNames;
  final TeamPulseStatus? pulseStatus;
  final VoidCallback? onTap;
  final VoidCallback? onNudge;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final progress = teamTotal > 0 ? teamReady / teamTotal : 0.0;
    final complete = teamTotal > 0 && teamReady >= teamTotal;
    final accent = switch (pulseStatus) {
      TeamPulseStatus.allDone => p.mint,
      TeamPulseStatus.support => p.warning,
      TeamPulseStatus.high => p.brand,
      _ => complete ? p.mint : p.coral,
    };

    return PrimeContentCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart_outlined, color: accent, size: 22),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: KitTypography.cardTitle.copyWith(
                    fontSize: 18,
                    color: p.ink,
                  ),
                ),
              ),
              Text(
                '$teamReady/$teamTotal',
                style: KitTypography.metricMedium.copyWith(
                  color: accent,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              subtitle!,
              style: KitTypography.caption.copyWith(color: p.inkMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: p.surfaceSoft,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 36,
            child: Stack(
              children: [
                for (var i = 0; i < avatars.length && i < 6; i++)
                  Positioned(
                    left: i * 22.0,
                    child: _PulseAvatar(item: avatars[i]),
                  ),
              ],
            ),
          ),
          if (!complete && waitingNames.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Ждём: ${waitingNames.take(3).join(', ')}',
              style: KitTypography.caption.copyWith(color: p.inkSecondary),
            ),
          ],
          if (!complete && onNudge != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: AppCompactButton(
                label: AppCopy.nudgeTeam,
                onPressed: onNudge,
                primary: false,
              ),
            ),
          ],
          if (complete) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Команда закрыла день',
              style: KitTypography.chip.copyWith(color: p.mint),
            ),
          ],
        ],
      ),
    );
  }
}

class _PulseAvatar extends StatelessWidget {
  const _PulseAvatar({required this.item});

  final PrimeSocialAvatar item;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: item.ready ? p.mint : p.surfaceElevated,
          width: 2,
        ),
      ),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: p.surface,
        child: Text(
          item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
          style: KitTypography.caption,
        ),
      ),
    );
  }
}

/// Quick mood picker for daily check-in.
class HomeMoodPicker extends StatelessWidget {
  const HomeMoodPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String? selected;
  final ValueChanged<String> onSelected;

  static const moods = [
    ('great', '😊', 'Отлично'),
    ('good', '🙂', 'Норм'),
    ('okay', '😐', 'Так себе'),
    ('hard', '😔', 'Сложно'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Как прошёл день?',
          style: AppTypography.titleSerif.copyWith(fontSize: 18, color: p.ink),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (final (id, emoji, label) in moods) ...[
              Expanded(
                child: _MoodChip(
                  emoji: emoji,
                  label: label,
                  selected: selected == id,
                  onTap: () => onSelected(id),
                ),
              ),
              if (id != 'hard') const SizedBox(width: AppSpacing.xxs),
            ],
          ],
        ),
      ],
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Material(
      color: selected ? p.brand.withValues(alpha: 0.15) : p.surfaceElevated,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? p.brand : p.hairline,
              width: selected ? 1.5 : 0.5,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 2),
              Text(
                label,
                style: KitTypography.caption.copyWith(
                  fontSize: 10,
                  color: selected ? p.ink : p.inkMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal feed of team check-ins today.
class HomeTeamActivityFeed extends StatelessWidget {
  const HomeTeamActivityFeed({
    super.key,
    required this.checkIns,
    this.onSeeAll,
  });

  final List<TeamCheckInModel> checkIns;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final ready = checkIns.where((c) => c.kind == 'ready' || c.kind == 'done').toList();
    if (ready.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeader(
          title: 'Сегодня в команде',
          actionLabel: 'Все >',
          onAction: onSeeAll,
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ready.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
            itemBuilder: (context, index) {
              final item = ready[index];
              return _ActivityCard(
                nickname: item.nickname.isNotEmpty ? '@${item.nickname}' : 'Участник',
                message: item.kind == 'done' ? 'Сдал отчёт' : 'Отметился',
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.nickname, required this.message});

  final String nickname;
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Container(
      width: 160,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: kitSurfaceDecoration(context, PrimeSurfaceLevel.solid),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: p.mint,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            nickname,
            style: KitTypography.chip.copyWith(color: p.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            message,
            style: KitTypography.caption.copyWith(color: p.inkMuted),
          ),
        ],
      ),
    );
  }
}
