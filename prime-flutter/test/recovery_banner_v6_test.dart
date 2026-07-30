import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/design/theme/prime_theme.dart';
import 'package:prime/ui/components/dashboard/recovery_banner.dart';

void main() {
  testWidgets('RecoveryBanner uses supportive copy and CTA', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: PrimeTheme.dark(),
        home: Scaffold(
          body: RecoveryBanner(onAction: () => tapped = true),
        ),
      ),
    );

    expect(find.text('Можно вернуться в ритм'), findsOneWidget);
    expect(find.text('Отправить отчёт'), findsOneWidget);
    await tester.tap(find.text('Отправить отчёт'));
    expect(tapped, isTrue);
  });
}
