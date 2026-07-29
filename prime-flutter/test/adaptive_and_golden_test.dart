import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/config/theme.dart';
import 'package:prime/design/tokens.dart';
import 'package:prime/design/visuals/habit_art.dart';
import 'package:prime/ui/components/app_bottom_navigation.dart';
import 'package:prime/ui/components/app_navigation_rail.dart';
import 'package:prime/ui/components/editorial/app_hero_module.dart';
import 'package:prime/ui/components/editorial/app_team_formation.dart';

void main() {
  setUp(() => ThemeBinding.bind(Brightness.dark));

  const navItems = [
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
  ];

  testWidgets('tablet width shows NavigationRail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Row(
            children: [
              AppNavigationRail(
                items: navItems,
                selectedIndex: 0,
                onSelected: (_) {},
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppNavigationRail), findsOneWidget);
    expect(find.text('Главная'), findsOneWidget);
  });

  testWidgets('phone width uses bottom navigation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          bottomNavigationBar: AppBottomNavigation(
            items: navItems,
            selectedIndex: 1,
            onSelected: (_) {},
          ),
          body: const SizedBox(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppBottomNavigation), findsOneWidget);
    expect(find.byType(AppNavigationRail), findsNothing);
  });

  testWidgets('golden: hero module', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: AppHeroModule(
              badge: 'Сегодня',
              title: 'Следующий шаг',
              body: 'Сделайте ежедневное действие',
              artKind: HabitArtKind.focus,
              progress: 0.4,
              progressLabel: '12 дн.',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/editorial_hero_module.png'),
    );
  });

  testWidgets('golden: team formation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: AppTeamFormationHero(
              title: 'Поиск команды',
              body: 'Привычка · Москва',
              filled: 3,
              total: 6,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/editorial_team_formation.png'),
    );
  });
}
