import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../design/visuals/ambient_and_progress.dart';
import '../../../models/group.dart';

/// Weekly team recap — real metrics from [TeamRecapModel].
class AppGroupRecapPanel extends StatelessWidget {
  const AppGroupRecapPanel({super.key, required this.recap});

  final TeamRecapModel recap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.surfaceSoft.withValues(alpha: 0.65),
          ],
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.insights_outlined, color: AppColors.primarySoft),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Recap недели', style: AppTypography.title2),
              ),
              AppProgressRing(
                progress: recap.pacePercent / 100,
                label: '${recap.pacePercent}%',
                subtitle: 'темп',
                size: 56,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(recap.message, style: AppTypography.bodySecondary),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _RecapMetricTile(
                  label: 'Действия',
                  value: '${recap.readyReports}',
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _RecapMetricTile(
                  label: 'Поддержка',
                  value: '${recap.supportSignals}',
                  icon: Icons.favorite_border,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _RecapMetricTile(
                  label: 'Лучший день',
                  value: recap.bestDay != null
                      ? '${recap.bestDayCount}'
                      : '—',
                  caption: recap.bestDay != null
                      ? _formatDay(recap.bestDay!)
                      : null,
                  icon: Icons.emoji_events_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDay(DateTime day) =>
      '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}';
}

class _RecapMetricTile extends StatelessWidget {
  const _RecapMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primarySoft),
          const SizedBox(height: AppSpacing.xxs),
          Text(value, style: AppTypography.title2),
          Text(label, style: AppTypography.caption),
          if (caption != null) Text(caption!, style: AppTypography.caption),
        ],
      ),
    );
  }
}

/// Team milestones strip — progress from API, no invented stats.
class AppGroupMilestonesPanel extends StatelessWidget {
  const AppGroupMilestonesPanel({super.key, required this.milestones});

  final TeamMilestonesModel milestones;

  @override
  Widget build(BuildContext context) {
    if (milestones.items.isEmpty) return const SizedBox.shrink();

    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final listHeight = textScale >= 1.5 ? 320.0 : 160.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Milestones команды', style: AppTypography.title2),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: listHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: milestones.items.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              return SizedBox(
                height: listHeight,
                child: _MilestoneCard(item: milestones.items[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({required this.item});

  final TeamMilestoneModel item;

  @override
  Widget build(BuildContext context) {
    final accent = item.unlocked ? AppColors.success : AppColors.primarySoft;
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return Container(
      width: 168,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: AppColors.surfaceSoft.withValues(alpha: 0.55),
        border: Border.all(
          color: item.unlocked
              ? AppColors.success.withValues(alpha: 0.45)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.unlocked
                    ? Icons.verified_rounded
                    : Icons.flag_outlined,
                color: accent,
                size: 20,
              ),
              const Spacer(),
              if (!item.unlocked)
                Text(
                  '${item.current}/${item.target}',
                  style: AppTypography.caption.copyWith(color: accent),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            item.title,
            maxLines: textScale >= 1.5 ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.title2.copyWith(fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            item.description,
            maxLines: textScale >= 1.5 ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption,
          ),
          if (!item.unlocked) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: item.progress,
                minHeight: 4,
                backgroundColor: AppColors.elevatedSurface,
                color: accent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
