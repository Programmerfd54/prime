import 'package:flutter/material.dart';

import '../../../core/habits/habit_preview_day.dart';
import '../../../core/habits/habit_program_metadata.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../design/visuals/charts/charts.dart';
import '../../../l10n/copy.dart';
import '../../../models/skill.dart';
import '../app_primary_button.dart';
import '../app_secondary_button.dart';
import '../app_dialog.dart';
import 'app_habit_catalog.dart';

class AppHabitDetailSections extends StatelessWidget {
  const AppHabitDetailSections({super.key, required this.skill});

  final SkillModel skill;

  @override
  Widget build(BuildContext context) {
    final meta = HabitProgramCatalog.metaFor(skill);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VisualSectionCard(
          title: 'Пример одного дня',
          child: PrimeTimelinePreview(steps: timelineStepsFromMeta(meta)),
        ),
        _SectionCard(
          title: 'Что делать каждый день',
          body: meta.dailyAction,
        ),
        const _SectionCard(
          title: 'Как считается день',
          body: AppCopy.howDayCounts,
        ),
        _SectionCard(
          title: 'Если пропустили',
          body: meta.skipPolicy,
        ),
        _VisualSectionCard(
          title: 'Роль команды',
          child: Column(
            children: [
              const Center(
                child: PrimeTeamRing(
                  slots: [],
                  size: 180,
                  centerLabel: '6',
                  centerSubtitle: 'человек в команде',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                meta.teamRole,
                textAlign: TextAlign.center,
                style: AppTypography.bodySecondary,
              ),
            ],
          ),
        ),
        _SectionCard(
          title: 'Что изменится',
          body: meta.outcome,
        ),
        _SectionCard(
          title: 'Формат отчёта',
          body: meta.reportFormat,
        ),
        _VisualSectionCard(
          title: 'Типичный темп цикла',
          subtitle: 'Иллюстрация — не ваши данные',
          child: PrimeNeonLineChart(
            values: const [0.35, 0.48, 0.62, 0.78, 0.85, 0.72, 0.65],
            labels: const [
              'Нед 1',
              'Нед 2',
              'Нед 3',
              'Нед 4',
              'Пик',
              'Нед 5',
              'Финиш',
            ],
            height: 100,
          ),
        ),
        _FaqBlock(items: meta.faq),
      ],
    );
  }
}

class AppHabitPreviewDayCard extends StatefulWidget {
  const AppHabitPreviewDayCard({
    super.key,
    required this.skillId,
    required this.dailyAction,
    this.onCompleted,
  });

  final String skillId;
  final String dailyAction;
  final VoidCallback? onCompleted;

  @override
  State<AppHabitPreviewDayCard> createState() => _AppHabitPreviewDayCardState();
}

class _AppHabitPreviewDayCardState extends State<AppHabitPreviewDayCard> {
  var _done = false;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final done = await HabitPreviewDay.isCompleted(widget.skillId);
    if (mounted) setState(() {
      _done = done;
      _loaded = true;
    });
  }

  Future<void> _toggle() async {
    if (_done) {
      await HabitPreviewDay.reset(widget.skillId);
    } else {
      await HabitPreviewDay.markCompleted(widget.skillId);
      widget.onCompleted?.call();
    }
    if (mounted) setState(() => _done = !_done);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        color: AppColors.accentSurface.withValues(alpha: 0.35),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ознакомительный день',
            style: AppTypography.title2.copyWith(color: AppColors.primarySoft),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Попробуйте действие до вступления в группу. Не запускает серию и не влияет на рейтинг.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(widget.dailyAction, style: AppTypography.bodySecondary),
          const SizedBox(height: AppSpacing.md),
          AppSecondaryButton(
            label: _done ? 'Сбросить demo' : 'Отметить demo-выполнение',
            icon: _done ? Icons.restart_alt : Icons.check_circle_outline,
            onPressed: _toggle,
          ),
        ],
      ),
    );
  }
}

Future<void> showHabitCompareSheet({
  required BuildContext context,
  required SkillModel primary,
  required List<SkillModel> allSkills,
}) {
  SkillModel? secondary;
  for (final s in allSkills) {
    if (s.id != primary.id) {
      secondary = s;
      break;
    }
  }

  return showAppBottomSheet<void>(
    context: context,
    child: StatefulBuilder(
      builder: (context, setState) {
        final b = secondary ?? primary;
        final metaA = HabitProgramCatalog.metaFor(primary);
        final metaB = HabitProgramCatalog.metaFor(b);

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Сравнение программ', style: AppTypography.title1),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  value: b.id,
                  decoration: const InputDecoration(labelText: 'Сравнить с'),
                  items: [
                    for (final s in allSkills.where((x) => x.id != primary.id))
                      DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (id) {
                    if (id == null) return;
                    setState(() {
                      secondary = allSkills.firstWhere((s) => s.id == id);
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                _CompareRow(
                  label: 'Программа',
                  a: primary.name,
                  b: b.name,
                ),
                _CompareRow(
                  label: 'Длительность',
                  a: AppCopy.cycleDays,
                  b: AppCopy.cycleDays,
                ),
                _CompareRow(
                  label: 'Сложность',
                  a: metaA.difficulty,
                  b: metaB.difficulty,
                ),
                _CompareRow(
                  label: 'Время дня',
                  a: metaA.timeOfDay,
                  b: metaB.timeOfDay,
                ),
                _CompareRow(
                  label: 'Длительность действия',
                  a: metaA.durationLabel,
                  b: metaB.durationLabel,
                ),
                _CompareRow(
                  label: 'Ежедневное действие',
                  a: metaA.dailyAction,
                  b: metaB.dailyAction,
                ),
                _CompareRow(
                  label: 'Формат отчёта',
                  a: metaA.reportFormat,
                  b: metaB.reportFormat,
                ),
                const SizedBox(height: AppSpacing.md),
                AppPrimaryButton(
                  label: 'Закрыть',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.a,
    required this.b,
  });

  final String label;
  final String a;
  final String b;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(a, style: AppTypography.body)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(b, style: AppTypography.bodySecondary)),
            ],
          ),
          const Divider(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _VisualSectionCard extends StatelessWidget {
  const _VisualSectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.title2.copyWith(fontSize: 16)),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(subtitle!, style: AppTypography.caption),
            ],
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.title2.copyWith(fontSize: 16)),
            const SizedBox(height: AppSpacing.xxs),
            Text(body, style: AppTypography.bodySecondary),
          ],
        ),
      ),
    );
  }
}

class _FaqBlock extends StatelessWidget {
  const _FaqBlock({required this.items});

  final List<HabitFaqItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FAQ', style: AppTypography.title2),
        const SizedBox(height: AppSpacing.sm),
        for (final item in items)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(item.question, style: AppTypography.body),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      item.answer,
                      style: AppTypography.bodySecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
