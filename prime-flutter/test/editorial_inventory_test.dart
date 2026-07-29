import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/config/theme.dart';
import 'package:prime/core/home/home_state.dart';
import 'package:prime/design/tokens.dart';
import 'package:prime/models/group.dart';
import 'package:prime/screens/dashboard/home_next_step_card.dart';
import 'package:prime/ui/components/editorial/app_group_pulse.dart';
import 'package:prime/ui/components/editorial/app_group_recap.dart';
import 'package:prime/ui/components/editorial/app_hero_module.dart';
import 'package:prime/models/report.dart';
import 'package:prime/ui/components/editorial/app_profile_growth.dart';

/// Golden + a11y inventory for editorial modules (product v2).
///
/// Screen mapping:
/// - [dashboard_screen] → home states, bento, journey strip
/// - [group_detail_screen] → group pulse
/// - [profile_screen] → profile growth
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget goldenWrap(
    Widget child, {
    Size size = const Size(390, 520),
  }) {
    ThemeBinding.bind(Brightness.dark);
    return MediaQuery(
      data: MediaQueryData(size: size, disableAnimations: true),
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pumpA11y(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: child,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  const sampleInsights = [
    ProfileInsightModel(
      id: 'streak_momentum',
      kind: 'streak',
      title: 'Серия набирает силу',
      message: 'У вас 7 дней подряд с готовым отчётом.',
    ),
  ];

  const samplePulse = TeamPulseModel(
    completedToday: 4,
    totalActive: 6,
    status: TeamPulseStatus.high,
    message: 'Большая часть команды уже отметилась сегодня',
    checkIns: [
      TeamCheckInModel(userId: 'u1', nickname: 'anna', kind: 'done'),
      TeamCheckInModel(userId: 'u2', nickname: 'ivan', kind: 'starting'),
    ],
  );

  final sampleRecap = TeamRecapModel(
    periodStart: DateTime(2026, 7, 21),
    periodEnd: DateTime(2026, 7, 27),
    readyReports: 18,
    pacePercent: 43,
    bestDay: DateTime(2026, 7, 25),
    bestDayCount: 5,
    supportSignals: 7,
    message:
        'За неделю команда закрыла 18 действий. темп 43%. лучший день — 25.07 (5 участников). поддержка — 7.',
  );

  const sampleMilestones = TeamMilestonesModel(
    items: [
      TeamMilestoneModel(
        id: 'first_full_day',
        title: 'Первый полный день',
        description: 'Вся команда отправила отчёт в один день',
        current: 1,
        target: 1,
        unlocked: true,
      ),
      TeamMilestoneModel(
        id: 'week_together',
        title: 'Неделя вместе',
        description: '7 дней с отчётами команды',
        current: 4,
        target: 7,
        unlocked: false,
      ),
    ],
  );

  group('golden inventory — home (dashboard_screen)', () {
    testWidgets('new user hero', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 440));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final state = HomeStateResolver.resolve(
        const HomeStateInput(
          hasActiveGroups: false,
          reportedToday: false,
          hasHistory: false,
          searching: false,
        ),
      );

      await tester.pumpWidget(
        goldenWrap(HomeNextStepCard(state: state), size: const Size(390, 440)),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(HomeNextStepCard),
        matchesGoldenFile('goldens/inventory_home_new_user.png'),
      );
    });

    testWidgets('report due hero', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 440));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final state = HomeStateResolver.resolve(
        const HomeStateInput(
          hasActiveGroups: true,
          reportedToday: false,
          hasHistory: true,
          searching: false,
          streak: 12,
          primarySkillName: 'Утренний фокус',
        ),
      );

      await tester.pumpWidget(
        goldenWrap(HomeNextStepCard(state: state), size: const Size(390, 440)),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(HomeNextStepCard),
        matchesGoldenFile('goldens/inventory_home_report_due.png'),
      );
    });

    testWidgets('searching team hero', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 440));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final state = HomeStateResolver.resolve(
        const HomeStateInput(
          hasActiveGroups: false,
          reportedToday: false,
          hasHistory: false,
          searching: true,
          peopleWaiting: 4,
          needed: 6,
          queueSkillName: 'Цифровой детокс',
        ),
      );

      await tester.pumpWidget(
        goldenWrap(HomeNextStepCard(state: state), size: const Size(390, 440)),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(HomeNextStepCard),
        matchesGoldenFile('goldens/inventory_home_searching.png'),
      );
    });

    testWidgets('journey strip', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 120));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(goldenWrap(const AppJourneyStrip()));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(AppJourneyStrip),
        matchesGoldenFile('goldens/inventory_journey_strip.png'),
      );
    });

    testWidgets('bento metrics empty', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 280));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        goldenWrap(
          const AppBentoMetrics(streak: 0, primes: 0, successDays: 0),
          size: const Size(390, 280),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(AppBentoMetrics),
        matchesGoldenFile('goldens/inventory_bento_empty.png'),
      );
    });

    testWidgets('bento metrics filled', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        goldenWrap(
          const AppBentoMetrics(streak: 14, primes: 28, successDays: 18),
          size: const Size(390, 200),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(AppBentoMetrics),
        matchesGoldenFile('goldens/inventory_bento_filled.png'),
      );
    });
  });

  group('golden inventory — groups (group_detail_screen)', () {
    testWidgets('team pulse panel', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        goldenWrap(
          AppGroupPulsePanel(
            pulse: samplePulse,
            onCheckIn: (_) {},
          ),
          size: const Size(390, 360),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(AppGroupPulsePanel),
        matchesGoldenFile('goldens/inventory_group_pulse.png'),
      );
    });

    testWidgets('team recap panel', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        goldenWrap(
          AppGroupRecapPanel(recap: sampleRecap),
          size: const Size(390, 360),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(AppGroupRecapPanel),
        matchesGoldenFile('goldens/inventory_group_recap.png'),
      );
    });

    testWidgets('team milestones panel', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 280));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        goldenWrap(
          const AppGroupMilestonesPanel(milestones: sampleMilestones),
          size: const Size(390, 280),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(AppGroupMilestonesPanel),
        matchesGoldenFile('goldens/inventory_group_milestones.png'),
      );
    });
  });

  group('golden inventory — profile (profile_screen)', () {
    testWidgets('profile growth section', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 620));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        goldenWrap(
          const AppProfileGrowthSection(
            currentStreak: 7,
            successfulDays: 18,
            primePoints: 24,
            bestStreak: 9,
            cyclePacePercent: 60,
            insights: sampleInsights,
          ),
          size: const Size(390, 620),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(AppProfileGrowthSection),
        matchesGoldenFile('goldens/inventory_profile_growth.png'),
      );
    });
  });

  group('a11y inventory — text scale 200%', () {
    testWidgets('HomeNextStepCard new user', (tester) async {
      final state = HomeStateResolver.resolve(
        const HomeStateInput(
          hasActiveGroups: false,
          reportedToday: false,
          hasHistory: false,
          searching: false,
        ),
      );
      await pumpA11y(tester, HomeNextStepCard(state: state));
      expect(find.textContaining('путь'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('HomeNextStepCard report due', (tester) async {
      final state = HomeStateResolver.resolve(
        const HomeStateInput(
          hasActiveGroups: true,
          reportedToday: false,
          hasHistory: true,
          searching: false,
          streak: 5,
        ),
      );
      await pumpA11y(tester, HomeNextStepCard(state: state));
      expect(find.textContaining('Закройте день'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppGroupPulsePanel', (tester) async {
      await pumpA11y(
        tester,
        AppGroupPulsePanel(pulse: samplePulse, onCheckIn: (_) {}),
      );
      expect(find.text('Командный ритм'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppGroupRecapPanel', (tester) async {
      await pumpA11y(
        tester,
        AppGroupRecapPanel(recap: sampleRecap),
      );
      expect(find.text('Recap недели'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppGroupMilestonesPanel', (tester) async {
      await pumpA11y(
        tester,
        const AppGroupMilestonesPanel(milestones: sampleMilestones),
      );
      expect(find.text('Milestones команды'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppProfileGrowthSection', (tester) async {
      await pumpA11y(
        tester,
        const AppProfileGrowthSection(
          currentStreak: 3,
          successfulDays: 10,
          primePoints: 5,
          cyclePacePercent: 33,
        ),
      );
      expect(find.text('Ваш темп'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppBentoMetrics empty', (tester) async {
      await pumpA11y(
        tester,
        const AppBentoMetrics(streak: 0, primes: 0, successDays: 0),
      );
      expect(find.text('Сегодняшний темп'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppBentoMetrics filled', (tester) async {
      await pumpA11y(
        tester,
        const AppBentoMetrics(streak: 9, primes: 15, successDays: 12),
      );
      expect(find.text('Ваш темп'), findsOneWidget);
      expect(find.textContaining('Праймы'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppJourneyStrip', (tester) async {
      await pumpA11y(tester, const AppJourneyStrip());
      expect(find.textContaining('привычку'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
