import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/config/theme.dart';
import 'package:prime/l10n/copy.dart';
import 'package:prime/models/report.dart';
import 'package:prime/ui/kit/presentation/profile_context_menu.dart';
import 'package:prime/ui/kit/presentation/profile_editorial_widgets.dart';
import 'package:prime/ui/kit/presentation/profile_sections.dart';
import 'package:prime/ui/kit/presentation/profile_states.dart';

CalendarOut _filledCalendar() {
  final today = DateTime(2026, 7, 29);
  final days = <CalendarDay>[];
  for (var i = 0; i < 28; i++) {
    final d = today.subtract(Duration(days: 27 - i));
    days.add(
      CalendarDay(
        date: d,
        status: i % 5 != 0 ? 'ready' : 'missed',
        reported: i % 5 != 0,
        completed: i % 5 != 0,
        primeAwarded: i % 7 == 0,
        contentText: '',
        attachments: const [],
        reports: const [],
      ),
    );
  }
  return CalendarOut(
    days: days,
    today: today,
    trackingStartDate: days.first.date,
    currentStreak: 6,
    bestStreak: 12,
    successfulDays: 21,
    primePoints: 48,
    cyclePacePercent: 70,
  );
}

Widget _profileHarness(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844)),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0B),
        body: SingleChildScrollView(child: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('profile v2 goldens §31', () {
    testWidgets('01 own filled hero', (tester) async {
      await tester.pumpWidget(
        _profileHarness(
          ProfileHeroCard(
            displayName: 'Алексей Морозов',
            subtitle: '@alex · Москва · 31 лет',
            photoUrl: 'https://example.com/photo.jpg',
            about: 'Утренние пробежки и фокус на привычках.',
            tags: profileHabitTagsFromNames(['Утренний фокус', 'Чтение']),
            metrics: const [
              ProfileMetricPill(
                label: 'Дней подряд',
                value: '6 дн.',
                variant: ProfileMetricPillVariant.gold,
              ),
              ProfileMetricPill(
                label: 'Праймы',
                value: '48',
                variant: ProfileMetricPillVariant.charcoal,
              ),
              ProfileMetricPill(
                label: AppCopy.profileProgressLabel,
                value: '21/30',
                variant: ProfileMetricPillVariant.hatched,
              ),
              ProfileMetricPill(
                label: 'Стаб. 7д',
                value: '86%',
                variant: ProfileMetricPillVariant.glass,
              ),
            ],
            calendar: _filledCalendar(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(ProfileHeroCard),
        matchesGoldenFile('goldens/profile_v2/01_own_filled_hero.png'),
      );
    });

    testWidgets('02 own empty hero', (tester) async {
      await tester.pumpWidget(
        _profileHarness(
          const ProfileHeroCard(
            displayName: 'Новый участник',
            subtitle: '@newbie',
            metrics: [],
            showChart: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(ProfileHeroCard),
        matchesGoldenFile('goldens/profile_v2/02_own_empty_hero.png'),
      );
    });

    testWidgets('04 public no photo monogram', (tester) async {
      await tester.pumpWidget(
        _profileHarness(
          ProfileHeroCard(
            displayName: 'Ivan Petrov',
            subtitle: '@ivan · 19 лет',
            mode: ProfileHeroMode.public,
            metrics: const [
              ProfileMetricPill(label: 'Дней подряд', value: '—'),
              ProfileMetricPill(
                label: 'Праймы',
                value: '0',
                variant: ProfileMetricPillVariant.charcoal,
              ),
              ProfileMetricPill(
                label: AppCopy.profileProgressLabel,
                value: AppCopy.profileProgressEmpty,
                variant: ProfileMetricPillVariant.hatched,
              ),
              ProfileMetricPill(
                label: 'Стаб. 7д',
                value: '—',
                variant: ProfileMetricPillVariant.glass,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(ProfileHeroCard),
        matchesGoldenFile('goldens/profile_v2/04_public_no_photo.png'),
      );
    });

    testWidgets('07 analytics empty', (tester) async {
      await tester.pumpWidget(
        _profileHarness(const ProfileAnalyticsSection(calendar: null)),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(ProfileAnalyticsSection),
        matchesGoldenFile('goldens/profile_v2/07_analytics_empty.png'),
      );
    });

    testWidgets('10 long bio and name', (tester) async {
      await tester.pumpWidget(
        _profileHarness(
          ProfileHeroCard(
            displayName: 'Александр Константинопольский',
            subtitle: '@verylongnickname · Республика Мордовия · 19 лет',
            about:
                'Люблю утренние пробежки, длинные тексты о привычках и '
                'осознанный ритм жизни в команде ПРАЙМ.',
            tags: profileHabitTagsFromNames(['Фокус', 'Чтение', 'Спокойный темп']),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(ProfileHeroCard),
        matchesGoldenFile('goldens/profile_v2/10_long_bio.png'),
      );
    });
  });

  testWidgets('context menu sheet renders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => ProfileContextMenu.show(
                    context: context,
                    nickname: 'ivan',
                  ),
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Скопировать @ivan'), findsOneWidget);
  });

  testWidgets('offline banner renders', (tester) async {
    await tester.pumpWidget(
      _profileHarness(const ProfileOfflineBanner()),
    );
    expect(find.textContaining('Офлайн'), findsOneWidget);
  });
}
