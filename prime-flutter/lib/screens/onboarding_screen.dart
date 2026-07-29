import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/analytics/analytics.dart';
import '../core/sync/user_personalization_sync.dart';
import '../core/onboarding/onboarding_preferences.dart';
import '../design/gradients.dart';
import '../design/haptics.dart';
import '../design/lottie_registry.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../ui/components/app_chip.dart';
import '../l10n/copy.dart';
import '../data/api_client.dart';
import '../providers/auth_provider.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../ui/components/app_primary_button.dart';
import '../ui/components/app_text_button.dart';
import '../core/pending/pending_search.dart';
import '../ui/components/onboarding/onboarding_interactive.dart';

/// Interactive 8-step onboarding — preferences saved for habits recommendation.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  String? _selectedSkillId;
  final Set<OnboardingGoal> _selectedGoals = {};
  String _quitCount = '2';
  String _attemptCount = '2-3';
  bool _finished = false;

  static const _stepCount = 8;

  String get _programTitle {
    final id = _selectedSkillId ??
        (_selectedGoals.isEmpty ? null : _selectedGoals.first.recommendedSkillId);
    if (id == null) return 'Утренний фокус';
    return OnboardingProgramPreview.all
        .firstWhere(
          (p) => p.skillId == id,
          orElse: () => OnboardingProgramPreview.all[3],
        )
        .title;
  }

  String get _effectiveSkillId =>
      _selectedSkillId ??
      (_selectedGoals.isEmpty
          ? null
          : _selectedGoals.first.recommendedSkillId) ??
      'morning-focus';

  @override
  void initState() {
    super.initState();
    Analytics.instance.onboardingStarted();
    Analytics.instance.onboardingStepViewed(0, 'promise');
  }

  @override
  void dispose() {
    if (!_finished) {
      Analytics.instance.onboardingAbandoned(_page, _stepId(_page));
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _persistAndFinish({bool queueTeamSearch = true}) async {
    final skillId = _effectiveSkillId;
    if (queueTeamSearch) {
      await PendingSearch.save(skillId);
    }
    final goals = _selectedGoals.toList();
    await OnboardingPreferences.save(
      OnboardingPreferences(
        goal: goals.isNotEmpty ? goals.first : null,
        goals: goals,
        selectedSkillId: _selectedSkillId ??
            (goals.isEmpty ? null : goals.first.recommendedSkillId),
        habitQuitCount: _quitCount,
        habitAttemptCount: _attemptCount,
        completedAt: DateTime.now(),
      ),
    );
    if (mounted && context.read<AuthProvider>().isAuthenticated) {
      await UserPersonalizationSync.pushOnboarding(context.read<ApiClient>());
    }
    Analytics.instance.onboardingComplete(
      goal: goals.isEmpty ? null : goals.first.name,
      skillId: _selectedSkillId,
    );
    _finished = true;
    if (!mounted) return;
    await context.read<AuthProvider>().finishOnboarding();
  }

  Future<void> _skip() async {
    Analytics.instance.onboardingSkip(_page);
    await _persistAndFinish(queueTeamSearch: false);
  }

  /// Existing users bail out of onboarding straight into the login form
  /// instead of being forced through program/goal selection.
  Future<void> _signIn() async {
    context.read<AuthProvider>().requestLoginOnNextAuth();
    await _skip();
  }

  bool get _canContinue {
    return switch (_page) {
      2 => _selectedSkillId != null,
      6 => _selectedGoals.isNotEmpty,
      _ => true,
    };
  }

  Future<void> _next() async {
    if (!_canContinue) return;
    Analytics.instance.onboardingStepCompleted(_page);

    if (_page < _stepCount - 1) {
      final duration = AppMotion.duration(context, AppDurations.slow);
      await _controller.nextPage(
        duration: duration,
        curve: AppMotion.standard,
      );
    } else {
      await _persistAndFinish();
    }
  }

  void _onPageChanged(int value) {
    setState(() => _page = value);
    Analytics.instance.onboardingStepViewed(value, _stepId(value));
  }

  void _toggleGoal(OnboardingGoal goal) {
    AppHaptics.selection();
    setState(() {
      if (_selectedGoals.contains(goal)) {
        _selectedGoals.remove(goal);
      } else if (_selectedGoals.length < 3) {
        _selectedGoals.add(goal);
        _selectedSkillId ??= goal.recommendedSkillId;
      }
    });
  }

  String _stepId(int page) => switch (page) {
        0 => 'promise',
        1 => 'problem',
        2 => 'programs',
        3 => 'daily',
        4 => 'team',
        5 => 'progress',
        6 => 'goal',
        _ => 'summary',
      };

  @override
  Widget build(BuildContext context) {
    final motion = AppMotion.duration(context, AppDurations.slow);
    final dotMotion = AppMotion.duration(context, AppDurations.normal);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedContainer(
        duration: AppDurations.slow,
        decoration: BoxDecoration(
          gradient: switch (_page) {
            1 => AppGradients.onboardingProblem,
            4 => AppGradients.onboardingTeam,
            5 => AppGradients.onboardingProgress,
            _ => AppGradients.onboardingPromise,
          },
        ),
        child: AmbientCanvas(
          intensity: 0.55,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.xs,
                    AppSpacing.sm,
                    0,
                  ),
                  child: Row(
                    children: [
                      if (_page > 0)
                        TextButton(
                          onPressed: () {
                            _controller.previousPage(
                              duration: motion,
                              curve: AppMotion.standard,
                            );
                          },
                          child: const Text(
                            AppCopy.back,
                            style: AppTypography.bodySecondary,
                          ),
                        )
                      else
                        const SizedBox(width: 72),
                      Expanded(
                        child: Text(
                          '${_page + 1} / $_stepCount',
                          textAlign: TextAlign.center,
                          style: AppTypography.caption,
                        ),
                      ),
                      TextButton(
                        onPressed: _skip,
                        child: const Text(
                          AppCopy.skip,
                          style: AppTypography.bodySecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: _onPageChanged,
                    children: [
                      _StepScroll(
                        child: _StepContent(
                          kicker: 'ПРАЙМ',
                          title: 'Меняться проще,\nкогда рядом ещё *пятеро*',
                          body:
                              'Система держит ритм, а не мотивация. Ежедневное действие, команда из 6 и поддержка без давления.',
                          hero: Column(
                            children: [
                              const PrimeLottie(
                                slot: PrimeLottieSlot.studyDiscussion,
                                width: 100,
                                height: 80,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final short =
                                      MediaQuery.sizeOf(context).height < 700;
                                  return OnboardingHeroOrb(
                                    height: short ? 140 : 180,
                                  );
                                },
                              ),
                            ],
                          ),
                          extra: Column(
                            children: [
                              const OnboardingProofPills(),
                              const SizedBox(height: AppSpacing.lg),
                              AppTextButton(
                                label: 'Уже есть аккаунт? Войти',
                                onPressed: _signIn,
                              ),
                            ],
                          ),
                        ),
                      ),
                      _StepScroll(
                        child: _StepContent(
                          title: 'Один день — легко.\n30 дней — сложнее',
                          body:
                              'Большинство бросает не из-за лени, а из-за потери ритма. ПРАЙМ помогает удерживать темп.',
                          extra: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Сколько раз начинали?',
                                style: AppTypography.caption,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Wrap(
                                spacing: AppSpacing.xs,
                                children: [
                                  for (final option in ['1', '2-3', '4+'])
                                    AppChip(
                                      label: option,
                                      selected: _attemptCount == option,
                                      onTap: () {
                                        AppHaptics.selection();
                                        setState(() => _attemptCount = option);
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Сколько раз бросали?',
                                style: AppTypography.caption,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Wrap(
                                spacing: AppSpacing.xs,
                                children: [
                                  for (final option in ['1', '2', '3+'])
                                    AppChip(
                                      label: option,
                                      selected: _quitCount == option,
                                      onTap: () {
                                        AppHaptics.selection();
                                        setState(() => _quitCount = option);
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              OnboardingInsightCard(
                                attemptCount: _attemptCount,
                                quitCount: _quitCount,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              OnboardingRhythmChart(
                                quitCount: _quitCount,
                                attemptCount: _attemptCount,
                              ),
                            ],
                          ),
                        ),
                      ),
                      _StepScroll(
                        child: _StepContent(
                          title: 'Выберите направление',
                          body:
                              '6 программ с разным характером. Выбор сохранится — после регистрации не придётся искать заново.',
                          extra: OnboardingProgramPicker(
                            selectedSkillId: _selectedSkillId,
                            onSelected: (id) =>
                                setState(() => _selectedSkillId = id),
                          ),
                        ),
                      ),
                      _StepScroll(
                        child: _StepContent(
                          title: 'Как выглядит *один день*',
                          body:
                              'Короткое действие днём и отчёт вечером. Попробуйте отметить день — так работает механика.',
                          extra: OnboardingDayFlow(
                            skillId: _effectiveSkillId,
                            programTitle: _programTitle,
                          ),
                        ),
                      ),
                      _StepScroll(
                        child: _StepContent(
                          title: 'Команда из 6 держит темп',
                          body:
                              'Команда не контролирует — она помогает не исчезнуть после первого пропуска.',
                          extra: const OnboardingTeamRing(),
                        ),
                      ),
                      _StepScroll(
                        child: _StepContent(
                          title: 'Ваш *прогресс* — наглядно',
                          body:
                              'Серия, темп цикла и Праймы — без токсичных рейтингов. К 30 дню вы видите результат.',
                          extra: OnboardingMetricsPreview(
                            skillId: _effectiveSkillId,
                            programTitle: _programTitle,
                          ),
                        ),
                      ),
                      _StepScroll(
                        child: _StepContent(
                          title: 'Что хотите изменить\nв *первую очередь*?',
                          body:
                              'Можно выбрать до трёх целей. Ответ поможет подобрать программу на вкладке «Привычки».',
                          extra: OnboardingGoalPicker(
                            selected: _selectedGoals,
                            onToggle: _toggleGoal,
                          ),
                        ),
                      ),
                      _StepScroll(
                        child: _StepContent(
                          title: 'Ваш план готов',
                          body:
                              'Осталось создать аккаунт — и мы начнём собирать команду.',
                          extra: OnboardingSummaryCard(
                            programTitle: _programTitle,
                            skillId: _effectiveSkillId,
                            goalLabels:
                                _selectedGoals.map((g) => g.label).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    math.max(bottomInset, AppSpacing.md) + AppSpacing.sm,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _stepCount,
                          (index) {
                            final active = index == _page;
                            return AnimatedContainer(
                              duration: dotMotion,
                              curve: AppMotion.standard,
                              margin: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xxs,
                              ),
                              width: active ? 18 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                                color: active
                                    ? AppColors.primary
                                    : AppColors.textMuted
                                        .withValues(alpha: 0.35),
                                boxShadow: active
                                    ? AppGlow.violet(opacity: 0.55)
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppPrimaryButton(
                        label: _page == _stepCount - 1
                            ? 'Создать аккаунт'
                            : AppCopy.continueLabel,
                        onPressed: _canContinue ? _next : null,
                      ),
                      if (_page == _stepCount - 1) ...[
                        const SizedBox(height: AppSpacing.xs),
                        AppTextButton(
                          label: 'Изменить программу',
                          onPressed: () {
                            _controller.animateToPage(
                              2,
                              duration: motion,
                              curve: AppMotion.standard,
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepScroll extends StatelessWidget {
  const _StepScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: child,
    );
  }
}

class _StepContent extends StatelessWidget {
  const _StepContent({
    this.kicker,
    required this.title,
    required this.body,
    this.hero,
    this.extra,
  });

  final String? kicker;
  final String title;
  final String body;
  final Widget? hero;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kicker != null) ...[
          Text(
            kicker!,
            style: AppTypography.caption.copyWith(
              color: AppColors.primarySoft,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (hero != null) ...[
          hero!,
          const SizedBox(height: AppSpacing.lg),
        ],
        AppTypography.accentText(
          title,
          style: AppTypography.display.copyWith(fontSize: 30),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(body, style: AppTypography.bodySecondary),
        if (extra != null) ...[
          const SizedBox(height: AppSpacing.lg),
          extra!,
        ],
      ],
    );
  }
}
