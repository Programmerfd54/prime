import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/metrics/calendar_metrics.dart';
import 'package:prime/models/report.dart';

void main() {
  CalendarOut calendarWithDays(List<CalendarDay> days, {DateTime? today}) {
    final t = today ?? DateTime(2026, 7, 20);
    return CalendarOut(
      days: days,
      today: t,
      trackingStartDate: DateTime(2026, 7, 1),
      currentStreak: 2,
      bestStreak: 5,
      successfulDays: 4,
      primePoints: 40,
      cyclePacePercent: 40,
    );
  }

  test('weeklyBuckets returns 7 days ending on today', () {
    final today = DateTime(2026, 7, 20);
    final days = [
      CalendarDay(
        date: DateTime(2026, 7, 18),
        status: 'ready',
        completed: true,
        reported: true,
        primeAwarded: true,
        contentText: '',
        attachments: const [],
        reports: const [],
      ),
      CalendarDay(
        date: DateTime(2026, 7, 20),
        status: 'ready',
        completed: true,
        reported: true,
        primeAwarded: true,
        contentText: '',
        attachments: const [],
        reports: const [],
      ),
    ];
    final buckets = CalendarMetrics.weeklyBuckets(
      calendarWithDays(days, today: today),
    );
    expect(buckets, hasLength(7));
    expect(buckets.last.isToday, isTrue);
    expect(buckets.last.completed, isTrue);
    expect(buckets[4].completed, isTrue); // Jul 18 is index 4 of Jul 14-20
  });

  test('heatmapCells pads empty future days', () {
    final today = DateTime(2026, 7, 5);
    final cal = calendarWithDays(const [], today: today);
    final cells = CalendarMetrics.heatmapCells(cal, cycleLength: 30);
    expect(cells, hasLength(30));
    expect(cells.where((c) => c.isEmpty).length, greaterThan(0));
  });

  test('paceRatio prefers cyclePacePercent', () {
    final cal = calendarWithDays(const []);
    expect(CalendarMetrics.paceRatio(cal), closeTo(0.4, 0.001));
  });

  test('paceRatio falls back to successfulDays', () {
    final cal = CalendarOut(
      days: const [],
      today: DateTime(2026, 7, 20),
      trackingStartDate: null,
      currentStreak: 0,
      bestStreak: 0,
      successfulDays: 15,
      primePoints: 0,
    );
    expect(CalendarMetrics.paceRatio(cal), closeTo(0.5, 0.001));
  });

  test('todayCompleted reads matching day', () {
    final today = DateTime(2026, 7, 20);
    final cal = calendarWithDays([
      CalendarDay(
        date: today,
        status: 'ready',
        completed: true,
        reported: true,
        primeAwarded: true,
        contentText: '',
        attachments: const [],
        reports: const [],
      ),
    ], today: today);
    expect(CalendarMetrics.todayCompleted(cal), isTrue);
  });
}
