import '../../core/habits/habit_program_metadata.dart';
import '../../models/skill.dart';
import 'habit_art.dart';

/// Product-facing habit filters aligned with program themes.
enum HabitFilterTag {
  all('Все'),
  focus('Фокус'),
  body('Тело'),
  rest('Отдых'),
  social('Общение'),
  growth('Развитие');

  const HabitFilterTag(this.label);
  final String label;
}

HabitFilterTag? habitFilterForSkill(SkillModel skill) {
  final kind = habitArtKindFor('${skill.id} ${skill.name} ${skill.icon}');
  return switch (kind) {
    HabitArtKind.focus => HabitFilterTag.focus,
    HabitArtKind.charge => HabitFilterTag.body,
    HabitArtKind.sleep || HabitArtKind.detox => HabitFilterTag.rest,
    HabitArtKind.social => HabitFilterTag.social,
    HabitArtKind.read => HabitFilterTag.growth,
    HabitArtKind.generic => null,
  };
}

bool skillMatchesFilter(SkillModel skill, HabitFilterTag filter) {
  if (filter == HabitFilterTag.all) return true;
  return habitFilterForSkill(skill) == filter;
}

/// Time-of-day chips for catalog filtering.
enum HabitTimeOfDayFilter {
  any('Любое'),
  morning('Утро'),
  day('День'),
  evening('Вечер');

  const HabitTimeOfDayFilter(this.label);
  final String label;
}

bool skillMatchesTimeOfDay(SkillModel skill, HabitTimeOfDayFilter filter) {
  if (filter == HabitTimeOfDayFilter.any) return true;
  final tod = HabitProgramCatalog.metaFor(skill).timeOfDay.toLowerCase();
  return tod.contains(filter.label.toLowerCase());
}
