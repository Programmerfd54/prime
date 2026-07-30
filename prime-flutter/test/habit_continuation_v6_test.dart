import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/design/theme/prime_theme.dart';
import 'package:prime/l10n/copy.dart';
import 'package:prime/models/skill.dart';
import 'package:prime/ui/components/editorial/app_habit_detail_v2.dart';

void main() {
  testWidgets('AppHabitDetailSections includes cycle continuation', (tester) async {
    final skill = SkillModel(
      id: 'morning-focus',
      name: 'Утренний фокус',
      description: 'Test',
      icon: 'star',
      category: SkillCategory.official,
      popularity: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: PrimeTheme.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AppHabitDetailSections(skill: skill),
          ),
        ),
      ),
    );

    expect(find.text('После 30 дней'), findsOneWidget);
    expect(find.textContaining('90, 180 или 365'), findsOneWidget);
  });
}
