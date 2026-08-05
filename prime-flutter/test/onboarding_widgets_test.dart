import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/config/theme.dart';
import 'package:prime/l10n/copy.dart';
import 'package:prime/screens/onboarding_screen.dart';
import 'package:prime/ui/components/onboarding/onboarding_interactive.dart';

void main() {
  testWidgets('OnboardingPromiseHero renders centered copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: OnboardingPromiseHero(onSignIn: () {}),
        ),
      ),
    );

    expect(find.text('ПРАЙМ'), findsOneWidget);
    expect(find.textContaining('поддержат'), findsOneWidget);
    expect(find.text('Уже есть аккаунт? Войти'), findsOneWidget);
  });

  testWidgets('OnboardingSoftSystemPreview renders pillars and no-pressure block',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: OnboardingSoftSystemPreview(
              programTitle: 'Вечерний ритуал',
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Ваша программа'), findsOneWidget);
    expect(find.text('Три опоры ПРАЙМ'), findsOneWidget);
    expect(find.textContaining('Действие'), findsOneWidget);
    expect(find.text('Здесь не наказывают за пропуск'), findsOneWidget);
  });

  testWidgets('OnboardingScreen hides Continue on reflection step', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const OnboardingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppCopy.continueLabel), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('Ваш темп — честный разбор'), findsOneWidget);
    expect(find.text(AppCopy.continueLabel), findsNothing);
  });
}
