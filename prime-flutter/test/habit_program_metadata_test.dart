import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/habits/habit_program_metadata.dart';
import 'package:prime/models/skill.dart';

void main() {
  test('morning-focus includes Gregory daily steps and report template', () {
    final meta = HabitProgramCatalog.metaFor(
      SkillModel(
        id: 'morning-focus',
        name: 'Утренний фокус',
        description: 'fallback',
        icon: 'wb_sunny',
        category: SkillCategory.official,
        popularity: 1,
      ),
    );
    expect(meta.dailySteps.length, greaterThanOrEqualTo(4));
    expect(meta.shortDescription, contains('40 минут'));
    expect(meta.reportTips.textTemplate, contains('Утренняя практика'));
    expect(meta.coachSteps.length, lessThanOrEqualTo(5));
  });

  test('live-communication outcome mentions communication skill', () {
    final meta = HabitProgramCatalog.metaForId('live-communication');
    expect(meta, isNotNull);
    expect(meta!.outcome, contains('коммуника'));
  });
}
