import '../../models/skill.dart';
import '../habits/habit_program_metadata.dart';
import '../onboarding/onboarding_preferences.dart';

/// Pure "how well does this habit fit this person" scoring — no I/O.
///
/// Combines the user's onboarding goals with their stated time budget,
/// difficulty comfort, and preferred time of day against the static facts
/// already published for each program in [HabitProgramCatalog] (never
/// invented numbers — see that file's own "no invented live stats" rule).
///
/// ## Formula (documented, 0-100 total)
///
/// | Component | Points | Rule |
/// |---|---|---|
/// | Goal match | 0-40 | 40 if the skill is the *primary* (first) selected goal's recommended skill; 24 if it matches any other selected goal; 0 otherwise |
/// | Time fit | 0-30 | Compares [HabitFitInput.availableMinutes] to the program's average daily duration (parsed from `durationLabel`); full points within budget, linearly down to 0 at a 30‑minute gap. Neutral (15) when either side is unknown/"Любое" |
/// | Difficulty fit | 0-15 | Full points on exact match with [HabitFitInput.difficultyPreference], half for an adjacent level (easy↔medium, medium↔hard), 0 for easy↔hard. Full points when no preference given |
/// | Time-of-day fit | 0-15 | Full points if the program's time-of-day includes the user's preferred slot (or either side is "any/любое"), 0 otherwise |
///
/// Every non-neutral/non-zero component appends a short reason code to
/// [HabitFitResult.reasons] so the UI can explain *why* a program was
/// recommended instead of just showing a bare number.
enum PreferredTimeOfDay { morning, day, evening, any }

enum DifficultyPreference { easy, medium, hard, any }

class HabitFitInput {
  const HabitFitInput({
    this.goals = const [],
    this.availableMinutes,
    this.preferredTimeOfDay = PreferredTimeOfDay.any,
    this.difficultyPreference = DifficultyPreference.any,
  });

  /// Ordered onboarding goals — first entry is the primary goal.
  final List<OnboardingGoal> goals;
  final int? availableMinutes;
  final PreferredTimeOfDay preferredTimeOfDay;
  final DifficultyPreference difficultyPreference;
}

class HabitFitResult {
  const HabitFitResult({
    required this.skillId,
    required this.score,
    required this.reasons,
  });

  final String skillId;

  /// 0-100, higher is a better fit.
  final int score;

  /// Machine-readable reason codes explaining the score (not localized —
  /// the UI layer maps these to RU copy).
  final List<String> reasons;

  @override
  String toString() => 'HabitFitResult($skillId: $score, $reasons)';
}

abstract final class HabitFitEngine {
  static const double maxGoalPoints = 40;
  static const double maxTimeFitPoints = 30;
  static const double maxDifficultyPoints = 15;
  static const double maxTimeOfDayPoints = 15;
  static const double _secondaryGoalPoints = 24;
  static const int _timeFitToleranceMinutes = 30;

  static HabitFitResult score(SkillModel skill, HabitFitInput input) {
    final meta = HabitProgramCatalog.metaFor(skill);
    final reasons = <String>[];

    final goalPoints = _goalFit(skill.id, input.goals, reasons);
    final timeFitPoints = _timeFit(meta.durationLabel, input.availableMinutes, reasons);
    final difficultyPoints =
        _difficultyFit(meta.difficulty, input.difficultyPreference, reasons);
    final timeOfDayPoints =
        _timeOfDayFit(meta.timeOfDay, input.preferredTimeOfDay, reasons);

    final total = goalPoints + timeFitPoints + difficultyPoints + timeOfDayPoints;
    return HabitFitResult(
      skillId: skill.id,
      score: total.round().clamp(0, 100),
      reasons: reasons,
    );
  }

  /// Scores and sorts [skills] best-fit first.
  static List<HabitFitResult> rank(List<SkillModel> skills, HabitFitInput input) {
    final results = skills.map((s) => score(s, input)).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  static double _goalFit(
    String skillId,
    List<OnboardingGoal> goals,
    List<String> reasons,
  ) {
    if (goals.isEmpty) return 0;
    if (goals.first.recommendedSkillId == skillId) {
      reasons.add('matches_primary_goal');
      return maxGoalPoints;
    }
    final matchesOther =
        goals.skip(1).any((g) => g.recommendedSkillId == skillId);
    if (matchesOther) {
      reasons.add('matches_secondary_goal');
      return _secondaryGoalPoints;
    }
    return 0;
  }

  static double _timeFit(
    String durationLabel,
    int? availableMinutes,
    List<String> reasons,
  ) {
    final avg = _parseDurationMinutes(durationLabel);
    if (availableMinutes == null || avg == null) {
      return maxTimeFitPoints / 2;
    }
    final diff = (avg - availableMinutes).abs();
    final normalized =
        (1 - (diff / _timeFitToleranceMinutes)).clamp(0.0, 1.0);
    if (normalized >= 0.8) {
      reasons.add('fits_available_time');
    } else if (normalized <= 0.2) {
      reasons.add('time_budget_mismatch');
    }
    return normalized * maxTimeFitPoints;
  }

  static double _difficultyFit(
    String difficultyLabel,
    DifficultyPreference preference,
    List<String> reasons,
  ) {
    if (preference == DifficultyPreference.any) return maxDifficultyPoints;
    final skillDifficulty = _parseDifficulty(difficultyLabel);
    if (skillDifficulty == preference) {
      reasons.add('matches_difficulty_preference');
      return maxDifficultyPoints;
    }
    if (_isAdjacentDifficulty(skillDifficulty, preference)) {
      return maxDifficultyPoints / 2;
    }
    return 0;
  }

  static double _timeOfDayFit(
    String timeOfDayLabel,
    PreferredTimeOfDay preference,
    List<String> reasons,
  ) {
    if (preference == PreferredTimeOfDay.any) return maxTimeOfDayPoints;
    final skillSlots = _parseTimeOfDay(timeOfDayLabel);
    if (skillSlots.contains(PreferredTimeOfDay.any) ||
        skillSlots.contains(preference)) {
      reasons.add('matches_preferred_time_of_day');
      return maxTimeOfDayPoints;
    }
    return 0;
  }

  /// Parses labels like "15 мин", "10–15 мин", "20–40 мин", "30+ мин" into
  /// an average minute value. Returns null for non-numeric labels
  /// ("Любое") so callers can treat the duration as unknown.
  static int? _parseDurationMinutes(String label) {
    final numbers = RegExp(r'\d+')
        .allMatches(label)
        .map((m) => int.parse(m.group(0)!))
        .toList();
    if (numbers.isEmpty) return null;
    if (numbers.length == 1) return numbers.first;
    return (numbers.reduce((a, b) => a + b) / numbers.length).round();
  }

  static DifficultyPreference _parseDifficulty(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('лёгк') || lower.contains('легк')) {
      return DifficultyPreference.easy;
    }
    if (lower.contains('сложн') || lower.contains('высок')) {
      return DifficultyPreference.hard;
    }
    return DifficultyPreference.medium;
  }

  static bool _isAdjacentDifficulty(
    DifficultyPreference a,
    DifficultyPreference b,
  ) {
    const order = [
      DifficultyPreference.easy,
      DifficultyPreference.medium,
      DifficultyPreference.hard,
    ];
    final ia = order.indexOf(a);
    final ib = order.indexOf(b);
    if (ia == -1 || ib == -1) return false;
    return (ia - ib).abs() == 1;
  }

  /// Parses labels like "Утро", "Вечер", "День / вечер", "Любое" into the
  /// set of matching slots.
  static Set<PreferredTimeOfDay> _parseTimeOfDay(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('люб')) return {PreferredTimeOfDay.any};
    final result = <PreferredTimeOfDay>{};
    if (lower.contains('утро')) result.add(PreferredTimeOfDay.morning);
    if (lower.contains('день')) result.add(PreferredTimeOfDay.day);
    if (lower.contains('вечер')) result.add(PreferredTimeOfDay.evening);
    return result.isEmpty ? {PreferredTimeOfDay.any} : result;
  }
}
