import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/config/theme.dart';
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
    expect(find.text('Три опоры PRIME'), findsOneWidget);
    expect(find.textContaining('Действие'), findsOneWidget);
    expect(find.text('Здесь не наказывают за пропуск'), findsOneWidget);
  });
}
