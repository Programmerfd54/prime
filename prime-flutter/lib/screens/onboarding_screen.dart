import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/analytics/analytics.dart';
import '../core/sync/user_personalization_sync.dart';
import '../core/onboarding/onboarding_preferences.dart';
import '../design/gradients.dart';
import '../design/haptics.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../l10n/copy.dart';
import '../data/api_client.dart';
import '../providers/auth_provider.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../ui/kit/presentation/profile_surfaces.dart';
import '../ui/components/app_primary_button.dart';
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
      backgroundColor: ProfileSurfaces.canvas,
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: 72,
                        child: _page > 0
                            ? TextButton(
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
                            : null,
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
                        child: OnboardingPromiseHero(onSignIn: _signIn),
                      ),
                      _StepScroll(
                        child: _StepContent(
                          title: 'Один день — легко.\n30 дней — сложнее',
                          body:
                              'Большинство бросает не из-за лени, а из-за потери ритма.',
                          extra: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OnboardingExperienceCard(
                                attemptCount: _attemptCount,
                                quitCount: _quitCount,
                                onAttemptChanged: (v) =>
                                    setState(() => _attemptCount = v),
                                onQuitChanged: (v) =>
                                    setState(() => _quitCount = v),
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
                              const SizedBox(height: AppSpacing.md),
                              OnboardingRhythmMiniStats(quitCount: _quitCount),
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
                          title: 'Как PRIME *удерживает* ритм',
                          body:
                              'Не через контроль — через систему из трёх простых опор и мягких правил.',
                          extra: OnboardingSoftSystemPreview(
                            programTitle: _programTitle,
                          ),
                        ),
                      ),
                      _StepScroll(
                        child: _StepContent(
                          title: 'Шестеро — *достаточно*, чтобы не пропасть',
                          body:
                              'Не контроль — поддержка, когда хочется исчезнуть после первого пропуска.',
                          extra: const OnboardingTeamRing(),
                        ),
                      ),
                      _StepScroll(
                        child: _StepContent(
                          title: 'Один *взгляд* — весь прогресс',
                          body:
                              'Серия, темп и Праймы — без сравнения с другими и токсичных рейтингов.',
                          extra: OnboardingMetricsPreview(
                            skillId: _effectiveSkillId,
                            programTitle: _programTitle,
                          ),
                        ),
                      ),
                      _StepScroll(
                        child: _StepContent(
                          title: 'Что *важно* прямо сейчас?',
                          body: 'До трёх целей — подберём программу под вас.',
                          extra: OnboardingGoalPicker(
                            selected: _selectedGoals,
                            onToggle: _toggleGoal,
                          ),
                        ),
                      ),
                      _StepScroll(
                        child: _StepContent(
                          title: 'Давайте начнём',
                          body:
                              'Создайте аккаунт — и мы соберём команду из шести.',
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
    required this.title,
    required this.body,
    this.extra,
  });

  final String title;
  final String body;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
