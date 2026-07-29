import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/onboarding/onboarding_preferences.dart';

void main() {
  test('OnboardingGoal maps to skill id', () {
    expect(
      OnboardingGoal.betterMorning.recommendedSkillId,
      'morning-focus',
    );
    expect(OnboardingGoal.betterSleep.recommendedSkillId, 'evening-ritual');
    expect(OnboardingGoal.lessSocialFeed.recommendedSkillId, 'digital-detox');
  });

  test('OnboardingPreferences roundtrip json', () {
    final prefs = OnboardingPreferences(
      goal: OnboardingGoal.readRegularly,
      selectedSkillId: 'one-chapter',
      completedAt: DateTime.utc(2026, 7, 27),
    );
    final restored =
        OnboardingPreferences.fromJson(prefs.toJson());
    expect(restored.goal, OnboardingGoal.readRegularly);
    expect(restored.selectedSkillId, 'one-chapter');
    expect(restored.recommendedSkillId, 'one-chapter');
  });

  test('multi goals roundtrip and primary goal', () {
    final prefs = OnboardingPreferences(
      goal: OnboardingGoal.moveMore,
      goals: const [
        OnboardingGoal.moveMore,
        OnboardingGoal.betterSleep,
        OnboardingGoal.readInsteadOfFeed,
      ],
      habitQuitCount: '2',
      habitAttemptCount: '4+',
      selectedSkillId: 'body-charge',
    );
    final restored = OnboardingPreferences.fromJson(prefs.toJson());
    expect(restored.goals.map((g) => g.name).toList(), [
      'moveMore',
      'betterSleep',
      'readInsteadOfFeed',
    ]);
    expect(restored.goal, OnboardingGoal.moveMore);
    expect(restored.habitQuitCount, '2');
    expect(restored.habitAttemptCount, '4+');
    expect(
      restored.recommendationReason(null),
      contains('цели'),
    );
  });

  test('partial about-only fields stay null in fromJson', () {
    final prefs = OnboardingPreferences.fromJson({
      'selected_skill_id': 'morning-focus',
    });
    expect(prefs.goal, isNull);
    expect(prefs.recommendedSkillId, 'morning-focus');
  });
}
