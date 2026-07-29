import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/config/theme.dart';
import 'package:prime/design/tokens.dart';
import 'package:prime/design/visuals/habit_art.dart';
import 'package:prime/models/skill.dart';
import 'package:prime/ui/components/app_bottom_navigation.dart';
import 'package:prime/ui/components/editorial/app_group_editorial.dart';
import 'package:prime/ui/components/editorial/app_habit_catalog.dart';
import 'package:prime/ui/components/editorial/app_home_greeting.dart';
import 'package:prime/ui/components/editorial/app_profile_hero.dart';
import 'package:prime/ui/components/editorial/app_public_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child, {Size size = const Size(390, 520)}) {
    ThemeBinding.bind(Brightness.dark);
    return MediaQuery(
      data: MediaQueryData(size: size, disableAnimations: true),
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('golden: habit svg illustration', (tester) async {
    await tester.binding.setSurfaceSize(const Size(200, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(const HabitArtObject(kind: HabitArtKind.focus, size: 120)),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HabitArtObject),
      matchesGoldenFile('goldens/habit_focus_svg.png'),
    );
  });

  testWidgets('golden: home greeting', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 160));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(
        const AppHomeGreeting(
          name: 'Даниил',
          dateLabel: 'Понедельник, 27 июля',
          subtitle: 'Первый шаг — выбрать привычку',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppHomeGreeting),
      matchesGoldenFile('goldens/pilot_home_greeting.png'),
    );
  });

  testWidgets('golden: profile hero starter', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(
        const AppProfileHero(
          name: 'Даниил',
          nickname: 'daniil',
          initial: 'Д',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppProfileHero),
      matchesGoldenFile('goldens/pilot_profile_starter.png'),
    );
  });

  testWidgets('golden: habit list row', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 140));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final skill = SkillModel(
      id: 'morning-focus',
      name: 'Утренний фокус',
      description: 'Спокойное утро без телефона и с главным намерением дня.',
      icon: 'wb_sunny',
      category: SkillCategory.official,
      popularity: 4,
    );

    await tester.pumpWidget(
      wrap(AppHabitListRow(skill: skill, onTap: () {})),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppHabitListRow),
      matchesGoldenFile('goldens/pilot_habit_list_row.png'),
    );
  });

  testWidgets('golden: group list row', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 88));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(
        const AppGroupListRow(
          title: 'Утренний фокус',
          statusLabel: 'активна',
          membersCount: 6,
          maxMembers: 6,
          active: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppGroupListRow),
      matchesGoldenFile('goldens/pilot_group_list_row.png'),
    );
  });

  testWidgets('golden: group empty state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap(const AppGroupEmptyState()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppGroupEmptyState),
      matchesGoldenFile('goldens/pilot_group_empty.png'),
    );
  });

  testWidgets('golden: public profile hero', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(
        const Column(
          children: [
            AppPublicProfileHero(
              name: 'Анна',
              nickname: 'anna_prime',
              location: 'Москва · 28 лет',
            ),
            SizedBox(height: 16),
            AppPublicProfileMetrics(primes: 42, successfulDays: 18),
          ],
        ),
        size: const Size(390, 420),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppPublicProfileHero),
      matchesGoldenFile('goldens/pilot_public_profile.png'),
    );
  });

  testWidgets('golden: floating bottom nav', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 120));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          backgroundColor: AppColors.background,
          bottomNavigationBar: AppBottomNavigation(
            items: const [
              AppBottomNavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: 'Главная',
              ),
              AppBottomNavItem(
                icon: Icons.forum_outlined,
                selectedIcon: Icons.forum,
                label: 'Чаты',
              ),
            ],
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppBottomNavigation),
      matchesGoldenFile('goldens/pilot_bottom_nav.png'),
    );
  });
}
