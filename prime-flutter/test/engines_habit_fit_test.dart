import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/engines/habit_fit_engine.dart';
import 'package:prime/core/onboarding/onboarding_preferences.dart';
import 'package:prime/models/skill.dart';

SkillModel _skill(String id, {String name = 'Test'}) => SkillModel(
      id: id,
      name: name,
      description: '',
      icon: 'star',
      category: SkillCategory.official,
      popularity: 0,
    );

void main() {
  group('HabitFitEngine.score', () {
    test('perfect match on goal, time, difficulty and time-of-day scores 100', () {
      // morning-focus: 15 min, Утро, Средняя difficulty.
      final result = HabitFitEngine.score(
        _skill('morning-focus'),
        const HabitFitInput(
          goals: [OnboardingGoal.betterMorning],
          availableMinutes: 15,
          preferredTimeOfDay: PreferredTimeOfDay.morning,
          difficultyPreference: DifficultyPreference.medium,
        ),
      );
      expect(result.score, 100);
      expect(result.reasons, contains('matches_primary_goal'));
      expect(result.reasons, contains('fits_available_time'));
      expect(result.reasons, contains('matches_difficulty_preference'));
      expect(result.reasons, contains('matches_preferred_time_of_day'));
    });

    test('no goals selected contributes zero goal points', () {
      final result = HabitFitEngine.score(
        _skill('morning-focus'),
        const HabitFitInput(),
      );
      expect(result.reasons, isNot(contains('matches_primary_goal')));
    });

    test('primary goal outweighs a secondary goal match', () {
      final primaryMatch = HabitFitEngine.score(
        _skill('morning-focus'),
        const HabitFitInput(
          goals: [OnboardingGoal.betterMorning, OnboardingGoal.moveMore],
        ),
      );
      final secondaryMatch = HabitFitEngine.score(
        _skill('body-charge'),
        const HabitFitInput(
          goals: [OnboardingGoal.betterMorning, OnboardingGoal.moveMore],
        ),
      );
      expect(primaryMatch.reasons, contains('matches_primary_goal'));
      expect(secondaryMatch.reasons, contains('matches_secondary_goal'));
      expect(primaryMatch.score, greaterThan(secondaryMatch.score));
    });

    test('time budget far outside the program duration scores low time fit', () {
      final closeFit = HabitFitEngine.score(
        _skill('morning-focus'), // 15 min
        const HabitFitInput(availableMinutes: 15),
      );
      final farFit = HabitFitEngine.score(
        _skill('morning-focus'),
        const HabitFitInput(availableMinutes: 60),
      );
      expect(closeFit.reasons, contains('fits_available_time'));
      expect(farFit.reasons, contains('time_budget_mismatch'));
      expect(closeFit.score, greaterThan(farFit.score));
    });

    test('unknown time budget or duration is scored as neutral, not penalised', () {
      final result = HabitFitEngine.score(
        _skill('morning-focus'),
        const HabitFitInput(),
      );
      expect(result.reasons, isNot(contains('time_budget_mismatch')));
      expect(result.reasons, isNot(contains('fits_available_time')));
    });

    test('adjacent difficulty gets partial credit, opposite gets none', () {
      // one-chapter is "Лёгкая" (easy).
      final adjacent = HabitFitEngine.score(
        _skill('one-chapter'),
        const HabitFitInput(difficultyPreference: DifficultyPreference.medium),
      );
      final opposite = HabitFitEngine.score(
        _skill('one-chapter'),
        const HabitFitInput(difficultyPreference: DifficultyPreference.hard),
      );
      expect(adjacent.score, greaterThan(opposite.score));
    });

    test('any difficulty/time preference always grants full credit', () {
      final result = HabitFitEngine.score(
        _skill('one-chapter'),
        const HabitFitInput(),
      );
      // No goals/time given either, so only difficulty+time-of-day are "any".
      expect(result.score, HabitFitEngine.maxDifficultyPoints.round() +
          HabitFitEngine.maxTimeOfDayPoints.round() +
          (HabitFitEngine.maxTimeFitPoints ~/ 2));
    });

    test('mismatched time of day scores zero for that component', () {
      // morning-focus is "Утро" only.
      final matched = HabitFitEngine.score(
        _skill('morning-focus'),
        const HabitFitInput(preferredTimeOfDay: PreferredTimeOfDay.morning),
      );
      final mismatched = HabitFitEngine.score(
        _skill('morning-focus'),
        const HabitFitInput(preferredTimeOfDay: PreferredTimeOfDay.evening),
      );
      expect(matched.score, greaterThan(mismatched.score));
      expect(mismatched.reasons, isNot(contains('matches_preferred_time_of_day')));
    });
  });

  group('HabitFitEngine.rank', () {
    test('sorts skills best-fit first', () {
      final ranked = HabitFitEngine.rank(
        [
          _skill('body-charge'),
          _skill('morning-focus'),
          _skill('one-chapter'),
        ],
        const HabitFitInput(
          goals: [OnboardingGoal.betterMorning],
          availableMinutes: 15,
          preferredTimeOfDay: PreferredTimeOfDay.morning,
        ),
      );
      expect(ranked.first.skillId, 'morning-focus');
      for (var i = 1; i < ranked.length; i++) {
        expect(ranked[i - 1].score, greaterThanOrEqualTo(ranked[i].score));
      }
    });
  });
}
