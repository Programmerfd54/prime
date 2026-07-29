import '../../models/report.dart';

/// One day bucket for weekly bars.
class WeekDayBucket {
  const WeekDayBucket({
    required this.date,
    required this.label,
    required this.completed,
    required this.reported,
    required this.isToday,
    required this.isFuture,
  });

  final DateTime date;
  final String label;
  final bool completed;
  final bool reported;
  final bool isToday;
  final bool isFuture;

  /// 0 empty, 0.5 reported only, 1.0 completed.
  double get intensity {
    if (completed) return 1.0;
    if (reported) return 0.55;
    return 0.0;
  }
}

/// One cell for a 30-day cycle heatmap.
class HeatmapCell {
  const HeatmapCell({
    required this.dayIndex,
    required this.date,
    required this.status,
    required this.completed,
    required this.reported,
    required this.primeAwarded,
    required this.isEmpty,
  });

  final int dayIndex;
  final DateTime? date;
  final String status;
  final bool completed;
  final bool reported;
  final bool primeAwarded;
  final bool isEmpty;
}

/// Pure metric helpers — never compute inside widgets.
abstract final class CalendarMetrics {
  static const _weekdayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  /// Last 7 days ending on [calendar.today] (inclusive).
  static List<WeekDayBucket> weeklyBuckets(CalendarOut calendar) {
    final today = DateTime(
      calendar.today.year,
      calendar.today.month,
      calendar.today.day,
    );
    final byDate = <String, CalendarDay>{};
    for (final d in calendar.days) {
      final key = _dateKey(d.date);
      byDate[key] = d;
    }

    return List.generate(7, (i) {
      final date = today.subtract(Duration(days: 6 - i));
      final day = byDate[_dateKey(date)];
      final weekday = date.weekday; // 1=Mon … 7=Sun
      return WeekDayBucket(
        date: date,
        label: _weekdayLabels[weekday - 1],
        completed: day?.completed ?? false,
        reported: day?.reported ?? false,
        isToday: _dateKey(date) == _dateKey(today),
        isFuture: date.isAfter(today),
      );
    });
  }

  /// Up to 30 cells for the current cycle (or last 30 calendar days).
  static List<HeatmapCell> heatmapCells(
    CalendarOut calendar, {
    int cycleLength = 30,
  }) {
    final today = DateTime(
      calendar.today.year,
      calendar.today.month,
      calendar.today.day,
    );
    final byDate = <String, CalendarDay>{};
    for (final d in calendar.days) {
      byDate[_dateKey(d.date)] = d;
    }

    final start = calendar.trackingStartDate == null
        ? today.subtract(Duration(days: cycleLength - 1))
        : DateTime(
            calendar.trackingStartDate!.year,
            calendar.trackingStartDate!.month,
            calendar.trackingStartDate!.day,
          );

    return List.generate(cycleLength, (i) {
      final date = start.add(Duration(days: i));
      if (date.isAfter(today)) {
        return HeatmapCell(
          dayIndex: i,
          date: date,
          status: '',
          completed: false,
          reported: false,
          primeAwarded: false,
          isEmpty: true,
        );
      }
      final day = byDate[_dateKey(date)];
      if (day == null) {
        return HeatmapCell(
          dayIndex: i,
          date: date,
          status: '',
          completed: false,
          reported: false,
          primeAwarded: false,
          isEmpty: true,
        );
      }
      return HeatmapCell(
        dayIndex: i,
        date: date,
        status: day.status,
        completed: day.completed,
        reported: day.reported,
        primeAwarded: day.primeAwarded,
        isEmpty: false,
      );
    });
  }

  /// 0–1 pace ratio for radial progress. Prefers API [cyclePacePercent].
  static double paceRatio(CalendarOut calendar, {int cycleLength = 30}) {
    if (calendar.cyclePacePercent != null) {
      return (calendar.cyclePacePercent! / 100).clamp(0.0, 1.0);
    }
    if (calendar.successfulDays <= 0) return 0;
    final day = calendar.successfulDays % cycleLength;
    if (day == 0 && calendar.successfulDays > 0) return 1.0;
    return (day / cycleLength).clamp(0.0, 1.0);
  }

  /// Today's completion for "am I on track today".
  static bool todayCompleted(CalendarOut calendar) {
    final key = _dateKey(calendar.today);
    for (final d in calendar.days) {
      if (_dateKey(d.date) == key) return d.completed;
    }
    return false;
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
