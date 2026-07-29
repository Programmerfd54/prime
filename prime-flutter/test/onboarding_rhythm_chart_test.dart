import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/config/theme.dart';
import 'package:prime/ui/components/onboarding/onboarding_rhythm_chart.dart';

void main() {
  testWidgets('rhythm chart readout reacts to quitCount', (tester) async {
    var quit = '2';
    var attempt = '2-3';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: Column(
                children: [
                  OnboardingRhythmChart(
                    quitCount: quit,
                    attemptCount: attempt,
                  ),
                  TextButton(
                    key: const ValueKey('set-quit-3'),
                    onPressed: () => setState(() => quit = '3+'),
                    child: const Text('quit 3+'),
                  ),
                  TextButton(
                    key: const ValueKey('set-attempt-4'),
                    onPressed: () => setState(() => attempt = '4+'),
                    child: const Text('attempt 4+'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('на 8-й день'), findsWidgets);
    expect(OnboardingRhythmChart.breakDayFor('2'), 8);
    expect(OnboardingRhythmChart.ghostCountFor('2-3'), 2);

    await tester.tap(find.byKey(const ValueKey('set-quit-3')));
    await tester.pumpAndSettle();

    expect(find.textContaining('на 5-й день'), findsWidgets);
    expect(OnboardingRhythmChart.breakDayFor('3+'), 5);
    expect(OnboardingRhythmChart.floorFor('3+'), 0.08);

    await tester.tap(find.byKey(const ValueKey('set-attempt-4')));
    await tester.pumpAndSettle();

    expect(OnboardingRhythmChart.ghostCountFor('4+'), 4);
    expect(find.textContaining('Прошлые попытки (4)'), findsOneWidget);
  });

  test('curve generation differs by quitCount', () {
    final soft = OnboardingRhythmChart.declineCurve(
      breakDay: OnboardingRhythmChart.breakDayFor('1'),
      floor: OnboardingRhythmChart.floorFor('1'),
    );
    final hard = OnboardingRhythmChart.declineCurve(
      breakDay: OnboardingRhythmChart.breakDayFor('3+'),
      floor: OnboardingRhythmChart.floorFor('3+'),
    );
    expect(soft.length, 30);
    expect(hard.length, 30);
    expect(soft.last, closeTo(0.45, 0.02));
    expect(hard.last, closeTo(0.08, 0.02));
    expect(soft.last, greaterThan(hard.last + 0.2));
    expect(
      OnboardingRhythmChart.breakDayFor('1'),
      greaterThan(OnboardingRhythmChart.breakDayFor('3+')),
    );
  });
}
