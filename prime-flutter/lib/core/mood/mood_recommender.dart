import '../../design/visuals/habit_tags.dart';
import 'mood_state.dart';

/// Intensity hint for habit recommendations based on mood.
enum MoodIntensity {
  low('Лёгкая нагрузка'),
  medium('Умеренный темп'),
  high('Можно активнее');

  const MoodIntensity(this.label);
  final String label;
}

/// Maps [MoodKind] to catalog filter tag + intensity guidance.
class MoodRecommendation {
  const MoodRecommendation({
    required this.filterTag,
    required this.intensity,
    required this.hint,
  });

  final HabitFilterTag filterTag;
  final MoodIntensity intensity;
  final String hint;
}

abstract final class MoodRecommender {
  static MoodRecommendation forKind(MoodKind kind) {
    return switch (kind) {
      MoodKind.drained => const MoodRecommendation(
          filterTag: HabitFilterTag.rest,
          intensity: MoodIntensity.low,
          hint: 'Короткие ритуалы отдыха и восстановления',
        ),
      MoodKind.tense => const MoodRecommendation(
          filterTag: HabitFilterTag.rest,
          intensity: MoodIntensity.low,
          hint: 'Дыхание, растяжка и мягкое замедление',
        ),
      MoodKind.calm => const MoodRecommendation(
          filterTag: HabitFilterTag.growth,
          intensity: MoodIntensity.medium,
          hint: 'Чтение, фокус или спокойное развитие',
        ),
      MoodKind.balanced => const MoodRecommendation(
          filterTag: HabitFilterTag.all,
          intensity: MoodIntensity.medium,
          hint: 'Любая привычка — выбирайте по интересу',
        ),
      MoodKind.energized => const MoodRecommendation(
          filterTag: HabitFilterTag.body,
          intensity: MoodIntensity.high,
          hint: 'Движение, зарядка и активные действия',
        ),
    };
  }

  static HabitFilterTag filterTagFor(MoodKind kind) =>
      forKind(kind).filterTag;

  static MoodIntensity intensityFor(MoodKind kind) =>
      forKind(kind).intensity;
}
