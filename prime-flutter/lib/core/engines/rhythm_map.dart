/// Pure day×hour "rhythm" heatmap builder — no I/O.
///
/// Shows *when* a user tends to act, not just *how often*. Two build
/// modes are provided because the app's actual data sources differ:
///
///  - [RhythmMap.build] — full timestamps are available (e.g. a report's
///    server `created_at`), so a real 7 (weekday) × 24 (hour) grid can be
///    built.
///  - [RhythmMap.buildDayOnly] — only a calendar date is available (e.g.
///    `CalendarDay.date`, which the API returns as a bare date and the
///    client parses with `hour == 0` — that is a parsing artifact, NOT a
///    real "acted at midnight" signal). In that case the hour dimension
///    is left empty and [RhythmGrid.hasHourlyData] is `false` so the UI
///    never draws a fake hourly heatmap from data that doesn't support it.
class RhythmCell {
  const RhythmCell({required this.weekday, required this.hour, required this.count});

  /// 1 = Monday .. 7 = Sunday (matches [DateTime.weekday]).
  final int weekday;

  /// 0-23, or `-1` when hour data is unavailable — see
  /// [RhythmGrid.hasHourlyData] before reading this field.
  final int hour;

  final int count;
}

class RhythmGrid {
  const RhythmGrid({
    required this.cells,
    required this.hasHourlyData,
    required this.maxCount,
  });

  /// Empty grid: no data was supplied at all.
  static const empty = RhythmGrid(cells: [], hasHourlyData: false, maxCount: 0);

  final List<RhythmCell> cells;

  /// `false` means every [RhythmCell.hour] is `-1` — only weekday counts
  /// are meaningful; do not render an hour axis.
  final bool hasHourlyData;

  /// Highest single-cell count, for normalizing heatmap opacity in the UI.
  final int maxCount;

  int countFor(int weekday, [int hour = -1]) {
    for (final cell in cells) {
      if (cell.weekday == weekday && cell.hour == hour) return cell.count;
    }
    return 0;
  }

  /// Total count per weekday, collapsing the hour dimension — useful for
  /// a simple 7-bar chart regardless of [hasHourlyData].
  Map<int, int> get totalsByWeekday {
    final totals = <int, int>{};
    for (final cell in cells) {
      totals[cell.weekday] = (totals[cell.weekday] ?? 0) + cell.count;
    }
    return totals;
  }
}

abstract final class RhythmMap {
  /// Builds a full 7×24 grid from report timestamps that carry real
  /// time-of-day information.
  static RhythmGrid build(List<DateTime> timestamps) {
    if (timestamps.isEmpty) return RhythmGrid.empty;

    final counts = <int, Map<int, int>>{};
    for (final ts in timestamps) {
      final byHour = counts.putIfAbsent(ts.weekday, () => {});
      byHour[ts.hour] = (byHour[ts.hour] ?? 0) + 1;
    }

    final cells = <RhythmCell>[];
    var maxCount = 0;
    for (var weekday = 1; weekday <= 7; weekday++) {
      for (var hour = 0; hour < 24; hour++) {
        final count = counts[weekday]?[hour] ?? 0;
        if (count > maxCount) maxCount = count;
        cells.add(RhythmCell(weekday: weekday, hour: hour, count: count));
      }
    }
    return RhythmGrid(cells: cells, hasHourlyData: true, maxCount: maxCount);
  }

  /// Builds a day-only grid (7 cells, `hour == -1`) when only calendar
  /// dates — not timestamps — are available. See class doc for why the
  /// hour dimension must stay empty here rather than defaulting to 0.
  static RhythmGrid buildDayOnly(List<DateTime> dates) {
    if (dates.isEmpty) return RhythmGrid.empty;

    final counts = <int, int>{};
    for (final date in dates) {
      counts[date.weekday] = (counts[date.weekday] ?? 0) + 1;
    }

    final cells = <RhythmCell>[];
    var maxCount = 0;
    for (var weekday = 1; weekday <= 7; weekday++) {
      final count = counts[weekday] ?? 0;
      if (count > maxCount) maxCount = count;
      cells.add(RhythmCell(weekday: weekday, hour: -1, count: count));
    }
    return RhythmGrid(cells: cells, hasHourlyData: false, maxCount: maxCount);
  }
}
