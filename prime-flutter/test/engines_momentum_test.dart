import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/engines/momentum_engine.dart';

DailyActivity _day(DateTime date, {bool attempted = true, bool met = true}) =>
    DailyActivity(date: date, attempted: attempted, metMinimum: met);

List<DailyActivity> _daysFrom(
  DateTime start,
  int count, {
  required bool Function(int index) met,
  bool Function(int index)? attempted,
}) {
  return List.generate(
    count,
    (i) => _day(
      start.add(Duration(days: i)),
      met: met(i),
      attempted: attempted?.call(i) ?? met(i),
    ),
  );
}

void main() {
  final base = DateTime(2026, 1, 1);

  test('empty history scores zero', () {
    final result = MomentumEngine.score(const []);
    expect(result.score, 0);
    expect(result.trendDelta, 0);
  });

  test('perfect two steady weeks maxes regularity/attempted/recovery '
      'but keeps trend neutral (no improvement to reward)', () {
    final days = _daysFrom(base, 14, met: (_) => true);
    final result = MomentumEngine.score(days);
    expect(result.trendDelta, 0);
    expect(result.regularityPoints, MomentumEngine.maxRegularityPoints);
    expect(result.attemptedPoints, MomentumEngine.maxAttemptedPoints);
    expect(result.returnAfterMissPoints, MomentumEngine.maxReturnAfterMissPoints);
    expect(result.trendPoints, MomentumEngine.maxTrendPoints / 2);
    expect(result.score, 88);
  });

  test('perfect week with improving trend scores maximum', () {
    // prev7: zero met days, last7: all met -> maximum positive trend.
    final days = _daysFrom(
      base,
      14,
      met: (i) => i >= 7,
    );
    final result = MomentumEngine.score(days);
    expect(result.trendDelta, 7);
    expect(result.trendPoints, MomentumEngine.maxTrendPoints);
    expect(result.score, 100);
  });

  test('all misses scores nothing but full recovery bonus is not awarded', () {
    final days = _daysFrom(base, 14, met: (_) => false, attempted: (_) => false);
    final result = MomentumEngine.score(days);
    expect(result.regularityPoints, 0);
    expect(result.attemptedPoints, 0);
    // Every day is a miss with no next-day recovery -> 0 bonus.
    expect(result.returnAfterMissPoints, 0);
    expect(result.score, lessThan(50));
  });

  test('improving week over week scores trend above neutral', () {
    // prev7 (i=0..6): met only on i=0,1 -> 2 met days.
    // last7 (i=7..13): met on every day -> 7 met days.
    final days = _daysFrom(
      base,
      14,
      met: (i) => i < 7 ? i < 2 : true,
    );
    final result = MomentumEngine.score(days);
    expect(result.trendDelta, 5);
    expect(result.trendPoints, greaterThan(MomentumEngine.maxTrendPoints / 2));
  });

  test('declining week over week scores trend below neutral', () {
    // prev7 (i=0..6): met on every day -> 7 met days.
    // last7 (i=7..13): met only on i=7 -> 1 met day.
    final days = _daysFrom(
      base,
      14,
      met: (i) => i < 7 ? true : i == 7,
    );
    final result = MomentumEngine.score(days);
    expect(result.trendDelta, -6);
    expect(result.trendPoints, lessThan(MomentumEngine.maxTrendPoints / 2));
  });

  test('single miss followed by a comeback earns full recovery bonus', () {
    // last7 (indices 7..13): miss on day 7, met every other day.
    final days = _daysFrom(
      base,
      14,
      met: (i) => i < 7 ? true : i != 7,
    );
    final result = MomentumEngine.score(days);
    expect(result.returnAfterMissPoints, MomentumEngine.maxReturnAfterMissPoints);
  });

  test('attempted but not accepted still contributes attempted points', () {
    final days = _daysFrom(
      base,
      7,
      met: (_) => false,
      attempted: (_) => true,
    );
    final result = MomentumEngine.score(days);
    expect(result.regularityPoints, 0);
    expect(result.attemptedPoints, MomentumEngine.maxAttemptedPoints);
  });

  test('order of input records does not matter', () {
    final ordered = _daysFrom(base, 10, met: (i) => i.isEven);
    final shuffled = List<DailyActivity>.from(ordered.reversed);
    expect(
      MomentumEngine.score(ordered).score,
      MomentumEngine.score(shuffled).score,
    );
  });

  test('fewer than 7 days still produces a defined score', () {
    final days = _daysFrom(base, 3, met: (_) => true);
    final result = MomentumEngine.score(days);
    expect(result.score, inInclusiveRange(0, 100));
    expect(result.regularityPoints, MomentumEngine.maxRegularityPoints);
  });
}
