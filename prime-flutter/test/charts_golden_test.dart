import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/config/theme.dart';
import 'package:prime/core/metrics/calendar_metrics.dart';
import 'package:prime/design/tokens.dart';
import 'package:prime/design/visuals/charts/charts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ThemeBinding.bind(Brightness.dark);

  Widget wrap(Widget child, {Size size = const Size(390, 420)}) {
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

  testWidgets('golden: radial progress empty', (tester) async {
    await tester.binding.setSurfaceSize(const Size(220, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrap(
        const PrimeRadialProgress(
          progress: 0,
          valueLabel: '0%',
          animate: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PrimeRadialProgress),
      matchesGoldenFile('goldens/chart_radial_empty.png'),
    );
  });

  testWidgets('golden: radial progress filled', (tester) async {
    await tester.binding.setSurfaceSize(const Size(220, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrap(
        const PrimeRadialProgress(
          progress: 0.72,
          valueLabel: '72%',
          animate: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PrimeRadialProgress),
      matchesGoldenFile('goldens/chart_radial_filled.png'),
    );
  });

  testWidgets('golden: weekly bars empty', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 160));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final buckets = List.generate(
      7,
      (i) => WeekDayBucket(
        date: DateTime(2026, 7, 21 + i),
        label: const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'][i],
        completed: false,
        reported: false,
        isToday: i == 6,
        isFuture: false,
      ),
    );
    await tester.pumpWidget(wrap(PrimeWeeklyBars(buckets: buckets)));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PrimeWeeklyBars),
      matchesGoldenFile('goldens/chart_weekly_empty.png'),
    );
  });

  testWidgets('golden: weekly bars filled', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 160));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final buckets = List.generate(
      7,
      (i) => WeekDayBucket(
        date: DateTime(2026, 7, 21 + i),
        label: const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'][i],
        completed: i.isEven,
        reported: true,
        isToday: i == 6,
        isFuture: false,
      ),
    );
    await tester.pumpWidget(wrap(PrimeWeeklyBars(buckets: buckets)));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PrimeWeeklyBars),
      matchesGoldenFile('goldens/chart_weekly_filled.png'),
    );
  });

  testWidgets('golden: heatmap empty', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cells = List.generate(
      30,
      (i) => HeatmapCell(
        dayIndex: i,
        date: DateTime(2026, 7, 1 + i),
        status: '',
        completed: false,
        reported: false,
        primeAwarded: false,
        isEmpty: true,
      ),
    );
    await tester.pumpWidget(wrap(PrimeHeatmap(cells: cells)));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PrimeHeatmap),
      matchesGoldenFile('goldens/chart_heatmap_empty.png'),
    );
  });

  testWidgets('golden: heatmap filled', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cells = List.generate(30, (i) {
      final completed = i % 4 == 0;
      final reported = i % 4 == 1;
      final missed = i % 4 == 2;
      return HeatmapCell(
        dayIndex: i,
        date: DateTime(2026, 7, 1 + i),
        status: completed
            ? 'completed'
            : reported
                ? 'reported'
                : missed
                    ? 'missed'
                    : '',
        completed: completed,
        reported: reported,
        primeAwarded: completed,
        isEmpty: i % 4 == 3,
      );
    });
    await tester.pumpWidget(wrap(PrimeHeatmap(cells: cells)));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PrimeHeatmap),
      matchesGoldenFile('goldens/chart_heatmap_filled.png'),
    );
  });

  testWidgets('golden: team ring empty', (tester) async {
    await tester.binding.setSurfaceSize(const Size(240, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(wrap(const PrimeTeamRing(slots: [], animate: false)));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PrimeTeamRing),
      matchesGoldenFile('goldens/chart_team_ring_empty.png'),
    );
  });

  testWidgets('golden: sparkline', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 140));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrap(const PrimeSparkline(values: [8, 7, 6.5, 5, 4.2, 3, 2.5])),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PrimeSparkline),
      matchesGoldenFile('goldens/chart_sparkline.png'),
    );
  });
}
