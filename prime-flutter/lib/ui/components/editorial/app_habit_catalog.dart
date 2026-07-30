import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../core/habits/habit_program_metadata.dart';
import '../../../design/haptics.dart';
import '../../../design/pressable.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../design/visuals/charts/charts.dart';
import '../../../design/visuals/habit_art.dart';
import '../../../design/visuals/scene_art.dart';
import '../../../l10n/copy.dart';
import '../../../models/skill.dart';

List<TimelineStep> timelineStepsFromMeta(HabitProgramMeta meta) {
  final steps = <TimelineStep>[];
  for (final entry in meta.sampleDay) {
    final parts = entry.split('—');
    if (parts.length >= 2) {
      steps.add(
        TimelineStep(
          time: parts.first.trim(),
          label: parts.sublist(1).join('—').trim(),
        ),
      );
    }
  }
  if (steps.isEmpty) {
    return const [
      TimelineStep(time: '09:00', label: 'Действие'),
      TimelineStep(time: '20:00', label: 'Отчёт'),
      TimelineStep(time: '+', label: 'Праймы', accent: true),
    ];
  }
  steps.add(const TimelineStep(time: '+', label: 'Праймы', accent: true));
  return steps;
}

Widget _metaPill({required IconData icon, required String label, Color? color}) {
  final c = color ?? AppColors.primarySoft;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: c.withValues(alpha: 0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: c,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    ),
  );
}

Widget _photoThumb({
  required String asset,
  required double size,
  double radius = AppRadius.sm,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.cover,
    ),
  );
}

/// Featured habit — full-bleed program photo with gradient overlay.
class AppHabitFeaturedCard extends StatelessWidget {
  const AppHabitFeaturedCard({
    super.key,
    required this.skill,
    required this.onTap,
    this.selected = false,
  });

  final SkillModel skill;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final kind = habitArtKindFor('${skill.id} ${skill.name} ${skill.icon}');
    final accent = habitArtAccent(kind);
    final meta = HabitProgramCatalog.metaFor(skill);
    final photo = habitPhotoAssetFor('${skill.id} ${skill.name}');
    final daily = meta.dailyAction.trim();
    final subtitle = skill.description.trim().isEmpty
        ? habitPromise(kind)
        : skill.description.trim();

    return PrimePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.bentoOuter),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.bentoOuter),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.10),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: AppGlow.violet(opacity: 0.16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.bentoOuter - 1),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(photo, fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.88),
                      Colors.black.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 0.85],
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.largeTitle.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySecondary.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (daily.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        daily,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primarySoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _metaPill(
                          icon: Icons.calendar_today_outlined,
                          label: AppCopy.cycleDays,
                          color: accent,
                        ),
                        _metaPill(
                          icon: Icons.schedule_outlined,
                          label: meta.durationLabel,
                          color: accent,
                        ),
                        _metaPill(
                          icon: Icons.group_outlined,
                          label: '6 человек',
                          color: accent,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Text(
                          'Открыть программу',
                          style: AppTypography.body.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: accent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact horizontal catalog tile.
class AppHabitCompactTile extends StatelessWidget {
  const AppHabitCompactTile({
    super.key,
    required this.skill,
    required this.onTap,
    this.selected = false,
  });

  final SkillModel skill;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final kind = habitArtKindFor('${skill.id} ${skill.name} ${skill.icon}');
    final accent = habitArtAccent(kind);
    final meta = HabitProgramCatalog.metaFor(skill);
    final photo = habitPhotoAssetFor('${skill.id} ${skill.name}');
    final daily = meta.dailyAction.trim();
    final subtitle = daily.isNotEmpty ? daily : habitPromise(kind);

    return Material(
      color: selected ? AppColors.selectedSurface : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          width: 168,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.5)
                  : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _photoThumb(asset: photo, size: 56, radius: AppRadius.sm),
              const SizedBox(height: AppSpacing.sm),
              Text(
                skill.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.title2.copyWith(fontSize: 15),
              ),
              const Spacer(),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width vertical catalog row — readable on small phones.
class AppHabitListRow extends StatelessWidget {
  const AppHabitListRow({
    super.key,
    required this.skill,
    required this.onTap,
    this.selected = false,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  final SkillModel skill;
  final VoidCallback onTap;
  final bool selected;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final kind = habitArtKindFor('${skill.id} ${skill.name} ${skill.icon}');
    final accent = habitArtAccent(kind);
    final meta = HabitProgramCatalog.metaFor(skill);
    final photo = habitPhotoAssetFor('${skill.id} ${skill.name}');
    final daily = meta.dailyAction.trim();
    final description = skill.description.trim();
    final subtitle = daily.isNotEmpty
        ? daily
        : (description.isEmpty ? habitPromise(kind) : description);

    final row = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            color: selected ? AppColors.selectedSurface : AppColors.surface,
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.45)
                  : AppColors.border,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _photoThumb(asset: photo, size: 72, radius: AppRadius.sm),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            skill.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.title2,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySecondary,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _metaPill(
                                icon: Icons.calendar_today_outlined,
                                label: AppCopy.cycleDays,
                                color: accent,
                              ),
                              _metaPill(
                                icon: Icons.schedule_outlined,
                                label: meta.durationLabel,
                                color: accent,
                              ),
                              _metaPill(
                                icon: Icons.speed_outlined,
                                label: meta.difficulty,
                                color: accent,
                              ),
                              _metaPill(
                                icon: Icons.wb_twilight_outlined,
                                label: meta.timeOfDay,
                                color: accent,
                              ),
                              _metaPill(
                                icon: Icons.group_outlined,
                                label: '6 человек',
                                color: accent,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            AppCopy.dayClosesTogether,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primarySoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onFavoriteToggle != null)
                      IconButton(
                        onPressed: onFavoriteToggle,
                        icon: Icon(
                          isFavorite
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: isFavorite
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (MediaQuery.textScalerOf(context).scale(1) < 1.5)
                  PrimeTimelinePreview(steps: timelineStepsFromMeta(meta)),
              ],
            ),
          ),
        ),
      ),
    );

    if (onFavoriteToggle == null) return row;

    return Slidable(
      key: ValueKey('habit-row-${skill.id}'),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.28,
        children: [
          CustomSlidableAction(
            onPressed: (_) {
              AppHaptics.light();
              onFavoriteToggle!();
            },
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isFavorite
                      ? Icons.bookmark_remove_rounded
                      : Icons.bookmark_add_rounded,
                  color: AppColors.primarySoft,
                ),
                const SizedBox(height: 4),
                Text(
                  isFavorite ? 'Убрать' : 'В избранное',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primarySoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      child: row,
    );
  }
}

/// Square / tall bento tile for curated catalog grids.
class AppHabitBentoTile extends StatelessWidget {
  const AppHabitBentoTile({
    super.key,
    required this.skill,
    required this.onTap,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.height,
  });

  final SkillModel skill;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  /// When null, expands to fill the parent (bento grid cell).
  final double? height;

  @override
  Widget build(BuildContext context) {
    final kind = habitArtKindFor('${skill.id} ${skill.name} ${skill.icon}');
    final accent = habitArtAccent(kind);
    final meta = HabitProgramCatalog.metaFor(skill);
    final photo = habitPhotoAssetFor('${skill.id} ${skill.name}');

    return PrimePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.bentoOuter),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.bentoOuter),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.bentoOuter),
          child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.bentoOuter),
              child: Image.asset(photo, fit: BoxFit.cover),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.bentoOuter),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.82),
                    Colors.black.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      HabitArtObject(kind: kind, size: 28),
                      const Spacer(),
                      if (onFavoriteToggle != null)
                        GestureDetector(
                          onTap: onFavoriteToggle,
                          child: Icon(
                            isFavorite
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            size: 20,
                            color: isFavorite
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    skill.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.title2.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meta.durationLabel,
                    style: AppTypography.caption.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

/// Aspirational unlock card for custom habits.
class AppCustomHabitUnlockCard extends StatelessWidget {
  const AppCustomHabitUnlockCard({
    super.key,
    required this.primePoints,
    required this.unlocked,
    this.onCreate,
  });

  final int primePoints;
  final bool unlocked;
  final VoidCallback? onCreate;

  static const unlockAt = 10;

  @override
  Widget build(BuildContext context) {
    final progress = (primePoints / unlockAt).clamp(0.0, 1.0);
    final remaining = (unlockAt - primePoints).clamp(0, unlockAt);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: unlocked
              ? [AppColors.accentSurface, AppColors.surface]
              : [
                  AppColors.heroSurfaceStart.withValues(alpha: 0.7),
                  AppColors.surfaceSoft,
                ],
        ),
        border: Border.all(
          color: unlocked
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SceneArt(
                kind: unlocked ? SceneKind.growth : SceneKind.empty,
                size: 56,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Своя привычка', style: AppTypography.title2),
                    Text(
                      unlocked
                          ? 'Создайте программу под себя'
                          : 'Откройте после $unlockAt Праймов — сейчас $primePoints',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!unlocked) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.primaryContainer,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Ещё $remaining ${remaining == 1 ? 'Прайм' : 'Праймов'} до открытия',
              style: AppTypography.caption.copyWith(
                color: AppColors.primarySoft,
              ),
            ),
          ],
          if (unlocked && onCreate != null) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Создать привычку'),
            ),
          ],
        ],
      ),
    );
  }
}
