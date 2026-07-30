import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/design/theme/prime_theme.dart';
import 'package:prime/ui/components/onboarding/onboarding_interactive.dart';

void main() {
  testWidgets('OnboardingSummaryCard shows V6 cycle continuation footnote', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PrimeTheme.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: OnboardingSummaryCard(
              programTitle: 'Утренний фокус',
              skillId: 'morning-focus',
              goalLabels: const ['Больше энергии'],
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('90, 180 или 365'), findsOneWidget);
    expect(find.textContaining('первый цикл'), findsWidgets);
  });
}
