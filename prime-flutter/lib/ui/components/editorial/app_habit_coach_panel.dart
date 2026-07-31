import 'package:flutter/material.dart';

import '../../../core/habits/habit_program_metadata.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../kit/components/prime_content_card.dart';
import '../app_secondary_button.dart';

/// Collapsible «Сегодня по привычке» coach memo for active cycle.
class AppHabitCoachPanel extends StatefulWidget {
  const AppHabitCoachPanel({
    super.key,
    required this.skillId,
    this.initiallyExpanded = false,
  });

  final String? skillId;
  final bool initiallyExpanded;

  @override
  State<AppHabitCoachPanel> createState() => _AppHabitCoachPanelState();
}

class _AppHabitCoachPanelState extends State<AppHabitCoachPanel> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final meta = HabitProgramCatalog.metaForId(widget.skillId);
    if (meta == null || meta.coachSteps.isEmpty) return const SizedBox.shrink();
    final p = context.prime;

    return PrimeContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: p.brand, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Сегодня по привычке',
                      style: AppTypography.title2.copyWith(color: p.ink),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: p.inkMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < meta.coachSteps.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.brand.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: AppTypography.caption.copyWith(
                        color: p.brand,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      meta.coachSteps[i],
                      style: AppTypography.bodySecondary.copyWith(color: p.inkSecondary),
                    ),
                  ),
                ],
              ),
              if (i < meta.coachSteps.length - 1)
                const SizedBox(height: AppSpacing.xs),
            ],
            const SizedBox(height: AppSpacing.sm),
            AppSecondaryButton(
              label: 'Полная инструкция',
              icon: Icons.menu_book_outlined,
              onPressed: () => _showFullInstruction(context, meta),
            ),
          ],
        ],
      ),
    );
  }

  void _showFullInstruction(BuildContext context, HabitProgramMeta meta) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.prime.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: ListView(
                controller: scrollController,
                children: [
                  Text('Что делать каждый день', style: AppTypography.titleSerif),
                  const SizedBox(height: AppSpacing.sm),
                  for (var i = 0; i < meta.dailySteps.length; i++) ...[
                    Text(
                      '${i + 1}. ${meta.dailySteps[i]}',
                      style: AppTypography.body,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Text('Что получите', style: AppTypography.title2),
                  const SizedBox(height: AppSpacing.xs),
                  Text(meta.outcome, style: AppTypography.bodySecondary),
                  const SizedBox(height: AppSpacing.md),
                  Text('Как отчитаться', style: AppTypography.title2),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Фото: ${meta.reportTips.photo}',
                      style: AppTypography.bodySecondary),
                  const SizedBox(height: AppSpacing.xxs),
                  Text('Видео: ${meta.reportTips.video}',
                      style: AppTypography.bodySecondary),
                  const SizedBox(height: AppSpacing.xxs),
                  Text('Текст: ${meta.reportTips.textTemplate}',
                      style: AppTypography.bodySecondary),
                  const SizedBox(height: AppSpacing.md),
                  Text(meta.cycleNote,
                      style: AppTypography.caption.copyWith(
                        color: context.prime.inkMuted,
                      )),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
