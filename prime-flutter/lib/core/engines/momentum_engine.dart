/// Pure, unit-testable momentum scoring — no Flutter/IO dependencies.
///
/// Momentum answers "is the user's habit rhythm getting stronger or weaker
/// right now" — distinct from [DailyActivity]-free `current_streak` (which
/// resets hard on any single miss) and from long-run completion ratio
/// (see `consistency_engine.dart`).
///
/// ## Input
///
/// A list of [DailyActivity] records, one per calendar day, in any order
/// (the engine sorts by date). Each day carries two independent signals:
///  - [DailyActivity.attempted] — user did *something* toward the habit
///    today (e.g. submitted any report), regardless of whether it was
///    accepted.
///  - [DailyActivity.metMinimum] — the action met the program's defined
///    daily minimum (e.g. report `status == ready`).
///
/// ## Formula (documented, always sums to 0-100)
///
/// Only the two most recent 7-day windows are used:
///  - `last7` = the most recent (up to) 7 days.
///  - `prev7` = the (up to) 7 days immediately before `last7`.
///
/// | Component | Points | Meaning |
/// |---|---|---|
/// | Regularity | 0-40 | share of `last7` days with `metMinimum == true` |
/// | Trend | 0-25 | week-over-week change in met-minimum day count (`prev7` -> `last7`); 12.5 = flat/no data |
/// | Return-after-miss | 0-15 | for every miss in `last7`, did the user meet minimum again within the next 2 days? Full marks if `last7` has zero misses |
/// | Attempted | 0-20 | share of `last7` days with `attempted == true` (shows up even when the report didn't count) |
///
/// Missing history shrinks denominators rather than erroring, so the score
/// is always defined for any input, including an empty list (score 0).
class DailyActivity {
  const DailyActivity({
    required this.date,
    required this.attempted,
    required this.metMinimum,
  });

  final DateTime date;
  final bool attempted;
  final bool metMinimum;
}

class MomentumResult {
  const MomentumResult({
    required this.score,
    required this.regularityPoints,
    required this.trendPoints,
    required this.returnAfterMissPoints,
    required this.attemptedPoints,
    required this.trendDelta,
  });

  /// Final 0-100 momentum score (rounded, clamped).
  final int score;
  final double regularityPoints;
  final double trendPoints;
  final double returnAfterMissPoints;
  final double attemptedPoints;

  /// `last7` met-minimum count minus `prev7` met-minimum count.
  final int trendDelta;

  @override
  String toString() =>
      'MomentumResult(score: $score, regularity: ${regularityPoints.toStringAsFixed(1)}, '
      'trend: ${trendPoints.toStringAsFixed(1)} (Δ$trendDelta), '
      'returnAfterMiss: ${returnAfterMissPoints.toStringAsFixed(1)}, '
      'attempted: ${attemptedPoints.toStringAsFixed(1)})';
}

abstract final class MomentumEngine {
  static const int windowDays = 7;
  static const double maxRegularityPoints = 40;
  static const double maxTrendPoints = 25;
  static const double maxReturnAfterMissPoints = 15;
  static const double maxAttemptedPoints = 20;

  static MomentumResult score(List<DailyActivity> records) {
    final sorted = List<DailyActivity>.from(records)
      ..sort((a, b) => a.date.compareTo(b.date));

    if (sorted.isEmpty) {
      return const MomentumResult(
        score: 0,
        regularityPoints: 0,
        trendPoints: 0,
        returnAfterMissPoints: 0,
        attemptedPoints: 0,
        trendDelta: 0,
      );
    }

    final last7 = _lastWindow(sorted, windowDays);
    final prev7 = _priorWindow(sorted, windowDays);

    final regularityPoints =
        _ratio(last7, (d) => d.metMinimum) * maxRegularityPoints;
    final attemptedPoints =
        _ratio(last7, (d) => d.attempted) * maxAttemptedPoints;

    final lastMetCount = last7.where((d) => d.metMinimum).length;
    final prevMetCount = prev7.where((d) => d.metMinimum).length;
    final trendDelta = lastMetCount - prevMetCount;
    final trendPoints = prev7.isEmpty
        ? maxTrendPoints / 2
        : (((trendDelta.clamp(-windowDays, windowDays) + windowDays) /
                (windowDays * 2)) *
            maxTrendPoints);

    final returnAfterMissPoints =
        _returnAfterMissRatio(last7) * maxReturnAfterMissPoints;

    final total = regularityPoints +
        trendPoints +
        returnAfterMissPoints +
        attemptedPoints;

    return MomentumResult(
      score: total.round().clamp(0, 100),
      regularityPoints: regularityPoints,
      trendPoints: trendPoints,
      returnAfterMissPoints: returnAfterMissPoints,
      attemptedPoints: attemptedPoints,
      trendDelta: trendDelta,
    );
  }

  static double _ratio(
    List<DailyActivity> days,
    bool Function(DailyActivity) test,
  ) {
    if (days.isEmpty) return 0;
    return days.where(test).length / days.length;
  }

  static List<DailyActivity> _lastWindow(
    List<DailyActivity> sortedAsc,
    int n,
  ) {
    if (sortedAsc.length <= n) return sortedAsc;
    return sortedAsc.sublist(sortedAsc.length - n);
  }

  static List<DailyActivity> _priorWindow(
    List<DailyActivity> sortedAsc,
    int n,
  ) {
    final total = sortedAsc.length;
    if (total <= n) return const [];
    final end = total - n;
    final start = (end - n).clamp(0, end);
    return sortedAsc.sublist(start, end);
  }

  /// Fraction of misses in [last7] that were followed by a met-minimum day
  /// within the next 2 days. A week with zero misses scores full marks —
  /// there was nothing to recover from.
  static double _returnAfterMissRatio(List<DailyActivity> last7) {
    final missIndexes = <int>[
      for (var i = 0; i < last7.length; i++)
        if (!last7[i].metMinimum) i,
    ];
    if (missIndexes.isEmpty) return 1.0;

    var recovered = 0;
    for (final i in missIndexes) {
      final nextDay = i + 1 < last7.length && last7[i + 1].metMinimum;
      final dayAfter = i + 2 < last7.length && last7[i + 2].metMinimum;
      if (nextDay || dayAfter) recovered++;
    }
    return recovered / missIndexes.length;
  }
}
