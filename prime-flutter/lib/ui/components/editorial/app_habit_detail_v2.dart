import 'package:flutter/material.dart';

import '../../../core/habits/habit_program_metadata.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../design/visuals/charts/charts.dart';
import '../../../l10n/copy.dart';
import '../../../models/skill.dart';
import '../../kit/components/prime_content_card.dart';
import '../../kit/tokens/kit_typography.dart';
import '../app_primary_button.dart';
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
          icon: Icons.schedule_rounded,
          title: 'Пример одного дня',
          child: PrimeTimelinePreview(steps: timelineStepsFromMeta(meta)),
        ),
        _EditorialSectionCard(
          icon: Icons.task_alt_rounded,
          title: 'Что делать каждый день',
          body: meta.dailyAction,
          steps: meta.dailySteps,
        ),
        const _EditorialSectionCard(
          icon: Icons.calendar_today_outlined,
          title: 'Как считается день',
          body: AppCopy.howDayCounts,
        ),
        _EditorialSectionCard(
          icon: Icons.cloud_off_outlined,
          title: 'Если пропустили',
          body: meta.skipPolicy,
        ),
        _VisualSectionCard(
          icon: Icons.groups_outlined,
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
                style: AppTypography.bodySecondary.copyWith(
                  color: context.prime.inkSecondary,
                ),
              ),
            ],
          ),
        ),
        _EditorialSectionCard(
          icon: Icons.trending_up_rounded,
          title: 'Что получите',
          body: meta.outcome,
        ),
        _ReportTipsSection(tips: meta.reportTips, summary: meta.reportFormat),
        _EditorialSectionCard(
          icon: Icons.flag_outlined,
          title: 'После 30 дней',
          body: meta.cycleNote,
        ),
        _VisualSectionCard(
          icon: Icons.show_chart_rounded,
          title: 'Типичный темп сезона',
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

class _ReportTipsSection extends StatelessWidget {
  const _ReportTipsSection({required this.tips, required this.summary});

  final HabitReportTips tips;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PrimeContentCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(icon: Icons.description_outlined, title: 'Как отчитаться'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              summary,
              style: AppTypography.bodySecondary.copyWith(color: p.inkSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            _TipRow(icon: Icons.photo_outlined, label: 'Фото', body: tips.photo),
            const SizedBox(height: AppSpacing.xxs),
            _TipRow(icon: Icons.videocam_outlined, label: 'Видео', body: tips.video),
            const SizedBox(height: AppSpacing.xxs),
            _TipRow(icon: Icons.edit_outlined, label: 'Текст', body: tips.textTemplate),
          ],
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({
    required this.icon,
    required this.label,
    required this.body,
  });

  final IconData icon;
  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: p.brandSoft),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTypography.bodySecondary.copyWith(color: p.inkSecondary),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
                TextSpan(text: body),
              ],
            ),
          ),
        ),
      ],
    );
  }
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.brandContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: Icon(icon, size: 20, color: p.brand),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: KitTypography.cardTitle.copyWith(color: p.ink)),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(subtitle!, style: KitTypography.caption.copyWith(color: p.inkSecondary)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EditorialSectionCard extends StatelessWidget {
  const _EditorialSectionCard({
    required this.icon,
    required this.title,
    required this.body,
    this.steps,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<String>? steps;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final bodyStyle =
        AppTypography.bodySecondary.copyWith(color: p.inkSecondary);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PrimeContentCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(icon: icon, title: title),
            const SizedBox(height: AppSpacing.sm),
            Text(body, style: bodyStyle),
            if (steps != null && steps!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              for (var i = 0; i < steps!.length; i++) ...[
                Text('${i + 1}. ${steps![i]}', style: bodyStyle),
                if (i < steps!.length - 1) const SizedBox(height: AppSpacing.xxs),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _VisualSectionCard extends StatelessWidget {
  const _VisualSectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PrimeContentCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(icon: icon, title: title, subtitle: subtitle),
            const SizedBox(height: AppSpacing.sm),
            child,
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
    final p = context.prime;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PrimeContentCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xxs),
              child: Text(
                'FAQ',
                style: KitTypography.cardTitle.copyWith(color: p.ink),
              ),
            ),
            for (final item in items)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: Material(
                  color: Colors.transparent,
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    iconColor: p.brand,
                    collapsedIconColor: p.inkMuted,
                    title: Text(
                      item.question,
                      style: AppTypography.body.copyWith(color: p.ink),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Text(
                            item.answer,
                            style: AppTypography.bodySecondary.copyWith(
                              color: p.inkSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
