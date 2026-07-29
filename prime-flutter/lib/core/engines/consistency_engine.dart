import 'momentum_engine.dart' show DailyActivity;

/// Pure completion-ratio scoring — deliberately NOT a streak.
///
/// A consecutive-day streak resets to zero on a single miss and hides how
/// consistent someone has actually been overall (e.g. 25/30 good days but
/// one early miss shows a "streak" of a handful of days). Consistency
/// instead answers: "out of the days that mattered, what share did the
/// user actually complete?" — using [DailyActivity.metMinimum].
///
/// ## Formula
///
/// `ratio = daysMet / daysInWindow`, where `daysInWindow` is
/// `min(windowDays, daysAvailable)` — new users are not penalised for
/// history that does not exist yet. `daysAvailable` is either the number
/// of records supplied or, when [trackingStartDate] is given, the number
/// of calendar days between tracking start and [asOf] (inclusive),
/// whichever is smaller after clamping to the requested window.
class ConsistencyResult {
  const ConsistencyResult({
    required this.metCount,
    required this.windowSize,
    required this.ratio,
  });

  /// Days within the window where [DailyActivity.metMinimum] was true.
  final int metCount;

  /// Effective denominator — `min(requested window, days available)`.
  final int windowSize;

  /// `metCount / windowSize` in `[0, 1]`; `0` when [windowSize] is `0`.
  final double ratio;

  /// Convenience 0-100 percentage, rounded.
  int get percent => (ratio * 100).round();

  @override
  String toString() =>
      'ConsistencyResult($metCount/$windowSize = $percent%)';
}

abstract final class ConsistencyEngine {
  /// Ratio of met-minimum days within the most recent [windowDays] days,
  /// ending at [asOf] (defaults to the latest record's date, or now).
  ///
  /// [trackingStartDate], if provided, caps the denominator so a user who
  /// only started 3 days ago is scored out of 3, not out of 7 or 30.
  static ConsistencyResult ratio(
    List<DailyActivity> records, {
    required int windowDays,
    DateTime? asOf,
    DateTime? trackingStartDate,
  }) {
    if (records.isEmpty) {
      return const ConsistencyResult(metCount: 0, windowSize: 0, ratio: 0);
    }

    final sorted = List<DailyActivity>.from(records)
      ..sort((a, b) => a.date.compareTo(b.date));
    final end = _dateOnly(asOf ?? sorted.last.date);
    final start = end.subtract(Duration(days: windowDays - 1));

    final inWindow = sorted.where((d) {
      final day = _dateOnly(d.date);
      return !day.isBefore(start) && !day.isAfter(end);
    }).toList();

    final metCount = inWindow.where((d) => d.metMinimum).length;

    var windowSize = windowDays;
    if (trackingStartDate != null) {
      final trackedDays =
          end.difference(_dateOnly(trackingStartDate)).inDays + 1;
      if (trackedDays > 0 && trackedDays < windowSize) {
        windowSize = trackedDays;
      }
    } else if (inWindow.length < windowSize) {
      // No explicit tracking start — fall back to the span actually
      // covered by supplied records so brand-new histories aren't
      // punished with a low denominator they could not have filled.
      final earliestInRange = inWindow.isEmpty
          ? null
          : _dateOnly(inWindow.first.date);
      if (earliestInRange != null) {
        final span = end.difference(earliestInRange).inDays + 1;
        if (span < windowSize) windowSize = span;
      }
    }

    if (windowSize <= 0) {
      return const ConsistencyResult(metCount: 0, windowSize: 0, ratio: 0);
    }

    return ConsistencyResult(
      metCount: metCount,
      windowSize: windowSize,
      ratio: (metCount / windowSize).clamp(0.0, 1.0),
    );
  }

  static ConsistencyResult sevenDay(
    List<DailyActivity> records, {
    DateTime? asOf,
    DateTime? trackingStartDate,
  }) =>
      ratio(
        records,
        windowDays: 7,
        asOf: asOf,
        trackingStartDate: trackingStartDate,
      );

  static ConsistencyResult thirtyDay(
    List<DailyActivity> records, {
    DateTime? asOf,
    DateTime? trackingStartDate,
  }) =>
      ratio(
        records,
        windowDays: 30,
        asOf: asOf,
        trackingStartDate: trackingStartDate,
      );

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
