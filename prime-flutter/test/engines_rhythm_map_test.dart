import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/engines/rhythm_map.dart';

void main() {
  group('RhythmMap.build (full timestamps)', () {
    test('empty input returns an empty grid without hourly data', () {
      final grid = RhythmMap.build(const []);
      expect(grid.cells, isEmpty);
      expect(grid.hasHourlyData, isFalse);
      expect(grid.maxCount, 0);
    });

    test('produces a full 7x24 grid and counts by weekday+hour', () {
      // 2026-01-05 is a Monday.
      final monday8am = DateTime(2026, 1, 5, 8, 0);
      final anotherMonday8am = DateTime(2026, 1, 12, 8, 0);
      final tuesday9pm = DateTime(2026, 1, 6, 21, 0);

      final grid = RhythmMap.build([monday8am, anotherMonday8am, tuesday9pm]);

      expect(grid.hasHourlyData, isTrue);
      expect(grid.cells.length, 7 * 24);
      expect(grid.countFor(DateTime.monday, 8), 2);
      expect(grid.countFor(DateTime.tuesday, 21), 1);
      expect(grid.countFor(DateTime.wednesday, 8), 0);
      expect(grid.maxCount, 2);
    });

    test('totalsByWeekday collapses the hour dimension', () {
      final grid = RhythmMap.build([
        DateTime(2026, 1, 5, 7, 0), // Monday
        DateTime(2026, 1, 5, 19, 0), // Monday
        DateTime(2026, 1, 6, 8, 0), // Tuesday
      ]);
      expect(grid.totalsByWeekday[DateTime.monday], 2);
      expect(grid.totalsByWeekday[DateTime.tuesday], 1);
    });
  });

  group('RhythmMap.buildDayOnly (date-only fallback)', () {
    test('empty input returns an empty grid', () {
      final grid = RhythmMap.buildDayOnly(const []);
      expect(grid.cells, isEmpty);
      expect(grid.hasHourlyData, isFalse);
    });

    test('marks hasHourlyData false and every cell hour as -1', () {
      final grid = RhythmMap.buildDayOnly([
        DateTime(2026, 1, 5), // Monday
        DateTime(2026, 1, 12), // Monday
        DateTime(2026, 1, 7), // Wednesday
      ]);
      expect(grid.hasHourlyData, isFalse);
      expect(grid.cells, hasLength(7));
      expect(grid.cells.every((c) => c.hour == -1), isTrue);
      expect(grid.countFor(DateTime.monday), 2);
      expect(grid.countFor(DateTime.wednesday), 1);
      expect(grid.countFor(DateTime.sunday), 0);
    });
  });
}
