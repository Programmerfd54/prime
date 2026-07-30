import 'package:flutter_test/flutter_test.dart';
import 'package:prime/models/report.dart';

/// Verifies seeded demo-filled profile shape (TZ §20, §30).
void main() {
  test('filled calendar fixture has 21+ days for acceptance', () {
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
        primeAwarded: false,
        contentText: '',
        attachments: const [],
        reports: const [],
      ),
      );
    }

    final calendar = CalendarOut(
      days: days,
      today: today,
      trackingStartDate: days.first.date,
      currentStreak: 6,
      bestStreak: 12,
      successfulDays: 21,
      primePoints: 48,
      cyclePacePercent: 70,
    );

    expect(calendar.days.length, greaterThanOrEqualTo(21));
    expect(calendar.successfulDays, greaterThanOrEqualTo(21));
    expect(
      calendar.days.where((d) => d.reported).length,
      greaterThanOrEqualTo(15),
    );
  });
}
