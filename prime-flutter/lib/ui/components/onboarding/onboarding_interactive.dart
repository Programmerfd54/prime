import 'package:flutter/material.dart';

import '../../../core/habits/habit_program_metadata.dart';
import '../../../core/onboarding/onboarding_preferences.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../../../design/haptics.dart';
import '../../../design/motion.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../design/visuals/charts/charts.dart';
import '../../../design/visuals/gauges/prime_dot_plot.dart';
import '../../../design/visuals/habit_art.dart';
import 'onboarding_rhythm_chart.dart';
import '../../../l10n/copy.dart';
import '../../../models/skill.dart';
import '../app_text_button.dart';
import '../app_chip.dart';
import '../../kit/components/prime_content_card.dart';

export 'onboarding_rhythm_chart.dart';

/// V6 onboarding copy — re-exports [AppCopy.cycleContinuationFootnote].
abstract final class OnboardingCopy {
  static const cycleContinuationFootnote = AppCopy.cycleContinuationFootnote;
}

/// Interactive widgets for the 8-step onboarding flow.

/// Typographic hero for onboarding step 1 — no images or Lottie.
class OnboardingPromiseHero extends StatelessWidget {
  const OnboardingPromiseHero({super.key, required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final short = MediaQuery.sizeOf(context).height < 700;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: short ? AppSpacing.md : AppSpacing.xl),
        Text(
          'ПРАЙМ',
          textAlign: TextAlign.center,
          style: AppTypography.displayHero.copyWith(
            fontSize: short ? 36 : 42,
            letterSpacing: 8,
            color: AppColors.primarySoft,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: short ? AppSpacing.lg : AppSpacing.xl),
        AppTypography.accentText(
          'Менять проще,\nкогда рядом есть\nте, кто *поддержат*',
          textAlign: TextAlign.center,
          style: AppTypography.display.copyWith(fontSize: short ? 26 : 30),
        ),
        const SizedBox(height: AppSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            'Система держит ритм, а не мотивация. Ежедневное действие, команда из 6 и поддержка без давления.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySecondary.copyWith(height: 1.45),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Center(child: OnboardingProofPills()),
        const SizedBox(height: AppSpacing.lg),
        AppTextButton(
          label: 'Уже есть аккаунт? Войти',
          onPressed: onSignIn,
        ),
        SizedBox(height: short ? AppSpacing.sm : AppSpacing.lg),
      ],
    );
  }
}

class OnboardingHeroOrb extends StatelessWidget {
  const OnboardingHeroOrb({super.key, this.height = 220});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          return RadialGradient(
            center: Alignment.center,
            radius: 0.72,
            colors: [
              Colors.white,
              Colors.white.withValues(alpha: 0.85),
              Colors.white.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(bounds);
        },
        child: Image.asset(
          'assets/photos/hero_orb.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}

class OnboardingProofPills extends StatelessWidget {
  const OnboardingProofPills({super.key});

  static const _items = [
    '30 дней',
    'команда из 6',
    '1 действие в день',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (var i = 0; i < _items.length; i++)
          PrimeStagger(
            index: i,
            child: AppChip(label: _items[i]),
          ),
      ],
    );
  }
}

class OnboardingExperienceCard extends StatelessWidget {
  const OnboardingExperienceCard({
    super.key,
    required this.attemptCount,
    required this.quitCount,
    required this.onAttemptChanged,
    required this.onQuitChanged,
  });

  final String attemptCount;
  final String quitCount;
  final ValueChanged<String> onAttemptChanged;
  final ValueChanged<String> onQuitChanged;

  @override
  Widget build(BuildContext context) {
    return PrimeContentCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ваш опыт',
            style: AppTypography.caption.copyWith(
              color: AppColors.primarySoft,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Сколько раз начинали?', style: AppTypography.caption),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final option in ['1', '2-3', '4+'])
                AppChip(
                  label: option,
                  selected: attemptCount == option,
                  onTap: () {
                    AppHaptics.selection();
                    onAttemptChanged(option);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Сколько раз бросали?', style: AppTypography.caption),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final option in ['1', '2', '3+'])
                AppChip(
                  label: option,
                  selected: quitCount == option,
                  onTap: () {
                    AppHaptics.selection();
                    onQuitChanged(option);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Это разные вопросы: можно начать один раз и бросать несколько — так бывает у многих.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingInsightCard extends StatelessWidget {
  const OnboardingInsightCard({
    super.key,
    required this.attemptCount,
    required this.quitCount,
  });

  final String attemptCount;
  final String quitCount;

  String get _attemptLabel => switch (attemptCount) {
        '1' => '1 раз',
        '4+' => '4+ раза',
        _ => '2–3 раза',
      };

  String get _quitLabel => switch (quitCount) {
        '1' => '1 раз',
        '3+' => '3+ раза',
        _ => '2 раза',
      };

  int get _breakDay => OnboardingRhythmChart.breakDayFor(quitCount);

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return PrimeContentCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.timeline_rounded,
              size: 20,
              color: AppColors.primarySoft,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTypography.bodySecondary.copyWith(
                  color: p.inkSecondary,
                  height: 1.45,
                ),
                children: [
                  TextSpan(text: 'Вы начинали $_attemptLabel и бросали $_quitLabel — '),
                  const TextSpan(
                    text: 'это два разных измерения опыта. ',
                  ),
                  const TextSpan(text: 'Обычно ритм ломается на '),
                  TextSpan(
                    text: '$_breakDay-й день',
                    style: TextStyle(
                      color: AppColors.primarySoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: ' — там и нужна команда.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingRhythmMiniStats extends StatelessWidget {
  const OnboardingRhythmMiniStats({super.key, required this.quitCount});

  final String quitCount;

  int get _breakDay => OnboardingRhythmChart.breakDayFor(quitCount);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            value: '~$_breakDay день',
            label: 'типичный срыв',
            accent: AppColors.coral,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _MiniStatCard(
            value: '30 дней',
            label: 'первый цикл с командой',
            accent: AppColors.primarySoft,
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.value,
    required this.label,
    required this.accent,
  });

  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return PrimeContentCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTypography.title2.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }
}

class OnboardingSoftSystemPreview extends StatelessWidget {
  const OnboardingSoftSystemPreview({super.key, required this.programTitle});

  final String programTitle;

  static const _pillars = [
    (
      icon: Icons.bolt_rounded,
      title: 'Действие',
      body: 'Короткий шаг каждый день — без марафонов',
    ),
    (
      icon: Icons.groups_2_outlined,
      title: 'Команда',
      body: 'Шестеро рядом, когда мотивация пропадает',
    ),
    (
      icon: Icons.chat_bubble_outline_rounded,
      title: 'Честный отчёт',
      body: '~30 сек вечером — команда видит, что вы здесь',
    ),
  ];

  static const _noPressure = [
    'Пропуск не выкидывает из команды',
    'Нет публичных рейтингов и стыда',
    'Честный отчёт важнее идеальной серии',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: AppChip(label: 'Ваша программа: $programTitle', selected: true),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Три опоры ПРАЙМ',
          style: AppTypography.caption.copyWith(
            color: AppColors.primarySoft,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < _pillars.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          _PillarCard(
            index: i + 1,
            icon: _pillars[i].icon,
            title: _pillars[i].title,
            body: _pillars[i].body,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        PrimeContentCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Здесь не наказывают за пропуск',
                style: AppTypography.title2.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final line in _noPressure)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: AppColors.mint,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(line, style: AppTypography.bodySecondary),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PillarCard extends StatelessWidget {
  const _PillarCard({
    required this.index,
    required this.icon,
    required this.title,
    required this.body,
  });

  final int index;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return PrimeContentCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.brand.withValues(alpha: 0.22),
            ),
            child: Icon(icon, size: 20, color: AppColors.primarySoft),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$index. $title',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(body, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingProgramPicker extends StatelessWidget {
  const OnboardingProgramPicker({
    super.key,
    required this.selectedSkillId,
    required this.onSelected,
  });

  final String? selectedSkillId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.95,
          ),
          itemCount: OnboardingProgramPreview.all.length,
          itemBuilder: (context, index) {
            final item = OnboardingProgramPreview.all[index];
            final selected = selectedSkillId == item.skillId;
            final kind = habitArtKindFor('${item.skillId} ${item.title}');
            final accent = habitArtAccent(kind);
            final meta = HabitProgramCatalog.metaFor(
              SkillModel(
                id: item.skillId,
                name: item.title,
                description: '',
                icon: 'star',
                category: SkillCategory.official,
                popularity: 0,
              ),
            );
            return AnimatedContainer(
              duration: AppDurations.fast,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: PrimeContentCard(
                padding: EdgeInsets.zero,
                onTap: () {
                  AppHaptics.selection();
                  onSelected(item.skillId);
                },
                child: AnimatedOpacity(
                duration: AppDurations.fast,
                opacity: selectedSkillId == null || selected ? 1 : 0.72,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg - 1),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        habitPhotoAsset(kind),
                        fit: BoxFit.cover,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.05),
                              Colors.black.withValues(alpha: 0.82),
                            ],
                            stops: const [0.28, 1],
                          ),
                        ),
                      ),
                      if (selected)
                        Positioned(
                          top: AppSpacing.xs,
                          right: AppSpacing.xs,
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: accent,
                            size: 22,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Spacer(),
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.title2.copyWith(
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              '${meta.durationLabel}/день',
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
                    ],
                  ),
                ),
              ),
            ),
          );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          selectedSkillId == null
              ? 'Выберите то, что вам близко — то, в чём давно хотели вырасти'
              : '30 дней · команда из 6 · программу можно поменять позже',
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(
            color: AppColors.primarySoft,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class OnboardingDayFlow extends StatefulWidget {
  const OnboardingDayFlow({
    super.key,
    required this.skillId,
    required this.programTitle,
  });

  final String skillId;
  final String programTitle;

  @override
  State<OnboardingDayFlow> createState() => _OnboardingDayFlowState();
}

class _OnboardingDayFlowState extends State<OnboardingDayFlow>
    with TickerProviderStateMixin {
  double _progress = 0;
  final Set<int> _completedSteps = {};
  final Map<int, AnimationController> _springControllers = {};

  HabitProgramMeta get _meta => HabitProgramCatalog.metaFor(
        SkillModel(
          id: widget.skillId,
          name: widget.programTitle,
          description: '',
          icon: 'star',
          category: SkillCategory.official,
          popularity: 0,
        ),
      );

  int get _activeStepCount {
    if (_progress >= 1) return 3;
    if (_progress >= 0.66) return 2;
    if (_progress >= 0.33) return 1;
    return 0;
  }

  bool get _done => _progress >= 1;

  @override
  void dispose() {
    for (final c in _springControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onScrub(double value) {
    final clamped = value.clamp(0.0, 1.0);
    setState(() => _progress = clamped);

    for (var step = 1; step <= 3; step++) {
      final threshold = step / 3.0;
      if (clamped >= threshold && !_completedSteps.contains(step)) {
        _completedSteps.add(step);
        AppHaptics.selection();
        _triggerSpring(step);
      }
    }
  }

  void _triggerSpring(int step) {
    _springControllers[step]?.dispose();
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _springControllers[step] = controller;
    controller.forward(from: 0).then((_) {
      if (mounted) controller.reverse();
    });
  }

  double _springScale(int step) {
    final controller = _springControllers[step];
    if (controller == null) return 1;
    return 1 + Curves.elasticOut.transform(controller.value) * 0.22;
  }

  @override
  Widget build(BuildContext context) {
    final kind = habitArtKindFor(widget.skillId);
    final sample = _meta.sampleDay;
    final actionHint = sample.isNotEmpty ? sample.first : _meta.dailyAction;
    final reportHint =
        sample.length > 1 ? sample.last : 'Короткий отчёт вечером';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppChip(label: 'Утро', selected: _progress > 0),
                  AppChip(label: 'День', selected: _progress >= 0.33),
                  AppChip(label: 'Вечер', selected: _progress >= 0.66),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor:
                      AppColors.primaryContainer.withValues(alpha: 0.5),
                  thumbColor: AppColors.primaryBright,
                ),
                child: Slider(
                  value: _progress,
                  onChanged: _onScrub,
                ),
              ),
              Text(
                _done
                    ? 'День пройден — так работает механика'
                    : 'Проведите ползунок, чтобы пройти день',
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        PrimeContentCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Image.asset(
                  habitPhotoAsset(kind),
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.programTitle, style: AppTypography.title2),
                    Text(
                      '${_meta.durationLabel} · ${_meta.timeOfDay}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _meta.dailyAction,
            style: AppTypography.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          _DayStep(
            index: 1,
            title: 'Действие днём',
            subtitle: actionHint,
            active: _activeStepCount >= 1,
            icon: Icons.bolt_rounded,
            scale: _springScale(1),
          ),
          const SizedBox(height: AppSpacing.xs),
          _DayStep(
            index: 2,
            title: 'Отчёт вечером · ~30 сек',
            subtitle: reportHint,
            active: _activeStepCount >= 2,
            icon: Icons.chat_bubble_outline_rounded,
            scale: _springScale(2),
          ),
          const SizedBox(height: AppSpacing.xs),
          _DayStep(
            index: 3,
            title: 'Прайм + серия, команда видит',
            subtitle: _done ? '+10 Праймов · команда 5 из 6' : 'Ритм команды растёт',
            active: _activeStepCount >= 3,
            icon: Icons.auto_awesome_rounded,
            scale: _springScale(3),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Пропуск не выкидывает из команды. Честный отчёт важнее идеальной серии.',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
          ),
        ),
      ],
    );
  }
}

class _DayStep extends StatelessWidget {
  const _DayStep({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.icon,
    this.scale = 1,
  });

  final int index;
  final String title;
  final String subtitle;
  final bool active;
  final IconData icon;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return PrimeContentCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Transform.scale(
            scale: scale,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? p.brand.withValues(alpha: 0.25)
                    : p.surfaceSoft,
              ),
              child: Icon(
                active ? Icons.check_rounded : icon,
                size: 18,
                color: active ? p.mint : p.inkMuted,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$index. $title',
                  style: AppTypography.caption.copyWith(
                    color: p.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(color: p.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingTeamRing extends StatefulWidget {
  const OnboardingTeamRing({super.key});

  @override
  State<OnboardingTeamRing> createState() => _OnboardingTeamRingState();
}

class _OnboardingTeamRingState extends State<OnboardingTeamRing> {
  var _checked = 3;

  static const _demos = [
    (name: 'Аня', asset: 'assets/avatars/demo/a1.jpg'),
    (name: 'Игорь', asset: 'assets/avatars/demo/a2.jpg'),
    (name: 'Мила', asset: 'assets/avatars/demo/a3.jpg'),
    (name: 'Саша', asset: 'assets/avatars/demo/a4.jpg'),
    (name: 'Лена', asset: 'assets/avatars/demo/a5.jpg'),
    (name: 'Вы', asset: 'assets/avatars/demo/a6.jpg'),
  ];

  @override
  void initState() {
    super.initState();
    _runStagger();
  }

  Future<void> _runStagger() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _checked = 4);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _checked = 4);
  }

  @override
  Widget build(BuildContext context) {
    final slots = <TeamRingSlot>[
      for (var i = 0; i < _demos.length; i++)
        TeamRingSlot(
          name: _demos[i].name,
          assetPath: _demos[i].asset,
          filled: true,
          checkedIn: i < _checked && i < _demos.length - 1,
        ),
    ];

    return Column(
      children: [
        PrimeTeamRing(
          size: 220,
          slots: slots,
          centerLabel: '$_checked из 6',
          centerSubtitle: 'уже отметились',
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xxs,
          children: [
            for (final demo in _demos)
              Text(
                demo.name,
                style: AppTypography.caption.copyWith(
                  color: demo.name == 'Вы'
                      ? AppColors.primarySoft
                      : AppColors.textMuted,
                  fontWeight:
                      demo.name == 'Вы' ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const _WhySixBlock(),
      ],
    );
  }
}

class _WhySixBlock extends StatelessWidget {
  const _WhySixBlock();

  static const _items = [
    (
      icon: Icons.groups_2_outlined,
      title: 'Достаточно для поддержки',
      body: 'И мало для анонимности — вас знают в лицо.',
    ),
    (
      icon: Icons.flag_outlined,
      title: 'Один старт на всех',
      body: 'Команда начинает цикл в один день — общий ритм.',
    ),
    (
      icon: Icons.favorite_outline,
      title: 'Пропуск не исключает',
      body: 'Сорвались — напишите. Команда остаётся рядом.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Почему шесть',
          style: AppTypography.caption.copyWith(
            color: AppColors.primarySoft,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < _items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PrimeContentCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      color: AppColors.primary.withValues(alpha: 0.14),
                      border: Border.all(
                        color: AppColors.primarySoft.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '0${i + 1}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primarySoft,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            height: 1,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Icon(
                          _items[i].icon,
                          size: 18,
                          color: AppColors.primarySoft,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _items[i].title,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _items[i].body,
                          style: AppTypography.caption.copyWith(
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class OnboardingMetricsPreview extends StatefulWidget {
  const OnboardingMetricsPreview({
    super.key,
    this.skillId,
    this.programTitle,
  });

  final String? skillId;
  final String? programTitle;

  @override
  State<OnboardingMetricsPreview> createState() =>
      _OnboardingMetricsPreviewState();
}

class _OnboardingMetricsPreviewState extends State<OnboardingMetricsPreview> {
  String get _outcome {
    final id = widget.skillId ?? 'morning-focus';
    return HabitProgramCatalog.metaFor(
      SkillModel(
        id: id,
        name: widget.programTitle ?? 'Утренний фокус',
        description: '',
        icon: 'star',
        category: SkillCategory.official,
        popularity: 0,
      ),
    ).outcome;
  }

  static const _demoDots = [
    0.2, 0.45, 0.35, 0.6, 0.55, 0.7, 0.5, 0.65, 0.8, 0.72,
    0.68, 0.75, 0.82, 0.78, 0.85, 0.9, 0.88, 0.92, 0.95, 0.9,
    0.86, 0.88, 0.91, 0.94, 0.96, 0.93, 0.97, 0.95, 0.98, 0.92,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimeContentCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Text(
                'ГЛАВНОЕ',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primarySoft,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: _HeroStreakRingPainter(progress: 7 / 30),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '7',
                          style: AppTypography.numeric.copyWith(
                            fontSize: 28,
                            height: 1,
                          ),
                        ),
                        Text(
                          'дней',
                          style: AppTypography.caption.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'серия подряд',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                '12 день цикла · темп 40%',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _MetricPill(label: 'Праймы', value: '120'),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MetricPill(label: 'Темп', value: '78%'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        PrimeContentCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Активность · 30 дней',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primarySoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const PrimeDotPlot(
                values: _demoDots,
                height: 88,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimeContentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'К 30 дню',
                style: AppTypography.caption.copyWith(
                  color: context.prime.brandSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                _outcome,
                style: AppTypography.bodySecondary.copyWith(
                  color: context.prime.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroStreakRingPainter extends CustomPainter {
  _HeroStreakRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const stroke = 6.0;
    final radius = (size.shortestSide - stroke) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.primaryContainer.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      3.14159 * 2 * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HeroStreakRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return PrimeContentCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTypography.title2.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class OnboardingGoalPicker extends StatelessWidget {
  const OnboardingGoalPicker({
    super.key,
    required this.selected,
    required this.onToggle,
    this.maxSelections = 3,
  });

  final Set<OnboardingGoal> selected;
  final ValueChanged<OnboardingGoal> onToggle;
  final int maxSelections;

  static IconData _iconFor(OnboardingGoal goal) => switch (goal) {
        OnboardingGoal.lessDistraction => Icons.phonelink_erase_outlined,
        OnboardingGoal.moveMore => Icons.fitness_center_outlined,
        OnboardingGoal.readRegularly => Icons.menu_book_outlined,
        OnboardingGoal.betterMorning => Icons.wb_sunny_outlined,
        OnboardingGoal.eveningRoutine => Icons.dark_mode_outlined,
        OnboardingGoal.socialize => Icons.forum_outlined,
        OnboardingGoal.betterSleep => Icons.bedtime_outlined,
        OnboardingGoal.lessStress => Icons.spa_outlined,
        OnboardingGoal.lessSocialFeed => Icons.smartphone_outlined,
        OnboardingGoal.readInsteadOfFeed => Icons.auto_stories_outlined,
      };

  /// One-line, honest consequence of picking a goal — sets expectations
  /// instead of just labelling the card.
  static String _consequenceFor(OnboardingGoal goal) => switch (goal) {
        OnboardingGoal.lessDistraction =>
          'подберём программу с окном без экрана каждый день',
        OnboardingGoal.moveMore => 'ежедневная короткая зарядка + отчёт',
        OnboardingGoal.readRegularly => 'минимум одна глава каждый вечер',
        OnboardingGoal.betterMorning => 'утренний ритуал без телефона',
        OnboardingGoal.eveningRoutine => 'спокойное закрытие дня перед сном',
        OnboardingGoal.socialize => 'один живой контакт в день',
        OnboardingGoal.betterSleep => 'вечерний ритуал для более лёгкого засыпания',
        OnboardingGoal.lessStress => 'короткая вечерняя рефлексия каждый день',
        OnboardingGoal.lessSocialFeed => 'осознанное окно без ленты',
        OnboardingGoal.readInsteadOfFeed => 'глава вместо скролла по вечерам',
      };

  static const _popularGoals = [
    OnboardingGoal.lessDistraction,
    OnboardingGoal.moveMore,
    OnboardingGoal.readRegularly,
    OnboardingGoal.betterMorning,
    OnboardingGoal.eveningRoutine,
    OnboardingGoal.socialize,
  ];

  static const _extraGoals = [
    OnboardingGoal.betterSleep,
    OnboardingGoal.lessStress,
    OnboardingGoal.lessSocialFeed,
    OnboardingGoal.readInsteadOfFeed,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              'Выбрано ${selected.length} из $maxSelections',
              style: AppTypography.caption.copyWith(
                color: AppColors.primarySoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final goal in _popularGoals) ...[
          _GoalRow(
            goal: goal,
            isSelected: selected.contains(goal),
            atMax: !selected.contains(goal) && selected.length >= maxSelections,
            onToggle: onToggle,
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Ещё цели',
              style: AppTypography.caption.copyWith(
                color: AppColors.primarySoft,
                fontWeight: FontWeight.w600,
              ),
            ),
            children: [
              for (final goal in _extraGoals) ...[
                _GoalRow(
                  goal: goal,
                  isSelected: selected.contains(goal),
                  atMax:
                      !selected.contains(goal) && selected.length >= maxSelections,
                  onToggle: onToggle,
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          selected.isEmpty
              ? 'Отметьте всё, что откликается'
              : 'Первая выбранная цель станет главной для рекомендации',
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(color: AppColors.primarySoft),
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          PrimeContentCard(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final goal in selected)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                    child: Text(
                      '${goal.label}: ${_consequenceFor(goal)}',
                      style: AppTypography.caption,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.goal,
    required this.isSelected,
    required this.atMax,
    required this.onToggle,
  });

  final OnboardingGoal goal;
  final bool isSelected;
  final bool atMax;
  final ValueChanged<OnboardingGoal> onToggle;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.fast,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: isSelected ? AppGlow.violet(opacity: 0.22) : null,
      ),
      child: PrimeContentCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        onTap: atMax
            ? null
            : () {
                if (!isSelected && atMax) return;
                onToggle(goal);
              },
        child: AnimatedOpacity(
          duration: AppDurations.fast,
          opacity: atMax ? 0.45 : 1,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.28)
                      : AppColors.elevatedSurface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  OnboardingGoalPicker._iconFor(goal),
                  size: 22,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.label,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      OnboardingGoalPicker._consequenceFor(goal),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingSummaryCard extends StatelessWidget {
  const OnboardingSummaryCard({
    super.key,
    required this.programTitle,
    required this.skillId,
    required this.goalLabels,
  });

  final String programTitle;
  final String skillId;
  final List<String> goalLabels;

  @override
  Widget build(BuildContext context) {
    final kind = habitArtKindFor(skillId);
    return PrimeContentCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.asset(
                habitPhotoAsset(kind),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Готово',
            style: AppTypography.caption.copyWith(color: AppColors.primarySoft),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(programTitle, style: AppTypography.title1),
          if (goalLabels.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final label in goalLabels)
                  AppChip(label: label, selected: true),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            '30 дней · команда из 6 · ежедневный отчёт',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            OnboardingCopy.cycleContinuationFootnote,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Что дальше',
            style: AppTypography.caption.copyWith(
              color: AppColors.primarySoft,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const _NextStep(
            icon: Icons.person_add_outlined,
            text: 'Создайте аккаунт — около 30 секунд',
          ),
          const _NextStep(
            icon: Icons.groups_2_outlined,
            text: 'Соберём команду из 6',
          ),
          const _NextStep(
            icon: Icons.flag_outlined,
            text: 'Стартуете первый день вместе',
          ),
        ],
      ),
    );
  }
}

class _NextStep extends StatelessWidget {
  const _NextStep({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 16, color: AppColors.primarySoft),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTypography.caption)),
        ],
      ),
    );
  }
}
