import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/config/theme.dart';
import 'package:prime/design/visuals/habit_art.dart';
import 'package:prime/models/achievement.dart';
import 'package:prime/ui/components/editorial/app_achievement_collection.dart';
import 'package:prime/ui/components/editorial/app_auth_hero.dart';
import 'package:prime/ui/components/editorial/app_hero_module.dart';
import 'package:prime/ui/components/editorial/app_profile_hero.dart';
import 'package:prime/ui/components/editorial/app_team_formation.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }

  testWidgets('editorial hero module renders art and CTA', (tester) async {
    await tester.pumpWidget(
      wrap(
        AppHeroModule(
          title: 'Следующий шаг',
          body: 'Описание действия',
          artKind: HabitArtKind.focus,
          actionLabel: 'Выбрать привычку',
          onAction: () {},
        ),
      ),
    );
    expect(find.text('Следующий шаг'), findsOneWidget);
    expect(find.text('Выбрать привычку'), findsOneWidget);
  });

  testWidgets('auth hero renders brand visual', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AppAuthHero(
          title: 'Вход в ПРАЙМ',
          subtitle: 'Продолжите привычки',
        ),
      ),
    );
    expect(find.text('Вход в ПРАЙМ'), findsOneWidget);
    expect(find.text('ПРАЙМ'), findsOneWidget);
  });

  testWidgets('profile hero renders identity stats', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AppProfileHero(
          name: 'Алекс',
          nickname: 'alex',
          initial: 'А',
          streak: 5,
          primes: 12,
          cycleDay: 3,
        ),
      ),
    );
    expect(find.text('Алекс'), findsOneWidget);
    expect(find.text('5'), findsWidgets);
  });

  testWidgets('team formation hero renders slots', (tester) async {
    await tester.pumpWidget(
      wrap(
        AppTeamFormationHero(
          title: 'Поиск команды',
          body: 'Фокус · Москва',
          filled: 2,
          total: 6,
        ),
      ),
    );
    expect(find.text('Поиск команды'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('achievement empty state is motivating', (tester) async {
    await tester.pumpWidget(
      wrap(const AppAchievementEmptyState()),
    );
    expect(find.text('Коллекция ждёт первый шаг'), findsOneWidget);
  });

  testWidgets('achievement collection renders hero card', (tester) async {
    await tester.pumpWidget(
      wrap(
        AppAchievementCollection(
          achievements: [
            AchievementModel(
              id: '1',
              code: 'student',
              name: 'Ученик',
              requiredDays: 7,
              description: '7 успешных дней',
              icon: 'medal',
              unlocked: false,
            ),
          ],
          successfulDays: 2,
        ),
      ),
    );
    expect(find.text('Ученик'), findsWidgets);
    expect(find.text('Ближайшая цель'), findsOneWidget);
  });
}
