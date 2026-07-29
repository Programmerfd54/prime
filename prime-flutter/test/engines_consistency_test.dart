import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/engines/consistency_engine.dart';
import 'package:prime/core/engines/momentum_engine.dart';

DailyActivity _day(DateTime date, bool met) =>
    DailyActivity(date: date, attempted: met, metMinimum: met);

void main() {
  final base = DateTime(2026, 1, 1);

  test('empty history has zero ratio and zero window', () {
    final result = ConsistencyEngine.sevenDay(const []);
    expect(result.metCount, 0);
    expect(result.windowSize, 0);
    expect(result.ratio, 0);
    expect(result.percent, 0);
  });

  test('7-day ratio counts met days out of a full window', () {
    // 10 days of history, most recent 7 have 5 met / 2 missed.
    final days = [
      for (var i = 0; i < 10; i++) _day(base.add(Duration(days: i)), i >= 5),
    ];
    final result = ConsistencyEngine.sevenDay(days, asOf: base.add(const Duration(days: 9)));
    expect(result.windowSize, 7);
    // Days 3..9 (7 days) -> met on days 5..9 = 5 met.
    expect(result.metCount, 5);
    expect(result.percent, 71);
  });

  test('new user with less history than the window is not penalised', () {
    // Only 3 days of history exist at all, all met.
    final days = [
      for (var i = 0; i < 3; i++) _day(base.add(Duration(days: i)), true),
    ];
    final result = ConsistencyEngine.sevenDay(
      days,
      asOf: base.add(const Duration(days: 2)),
    );
    expect(result.windowSize, 3);
    expect(result.metCount, 3);
    expect(result.ratio, 1.0);
  });

  test('trackingStartDate caps the denominator explicitly', () {
    final days = [
      _day(base, true),
      _day(base.add(const Duration(days: 1)), true),
    ];
    final result = ConsistencyEngine.ratio(
      days,
      windowDays: 30,
      asOf: base.add(const Duration(days: 1)),
      trackingStartDate: base,
    );
    expect(result.windowSize, 2);
    expect(result.metCount, 2);
    expect(result.ratio, 1.0);
  });

  test('30-day ratio differs from a naive streak for a broken-then-recovered history', () {
    // Miss on day 0, then met every day for the next 29 days.
    final days = [
      _day(base, false),
      for (var i = 1; i < 30; i++) _day(base.add(Duration(days: i)), true),
    ];
    final result = ConsistencyEngine.thirtyDay(
      days,
      asOf: base.add(const Duration(days: 29)),
      trackingStartDate: base,
    );
    expect(result.windowSize, 30);
    expect(result.metCount, 29);
    expect(result.percent, 97);
  });

  test('unmet days outside the window do not count against the ratio', () {
    final days = [
      _day(base, false), // outside the 7-day window below
      for (var i = 1; i < 10; i++) _day(base.add(Duration(days: i)), true),
    ];
    final result = ConsistencyEngine.sevenDay(
      days,
      asOf: base.add(const Duration(days: 9)),
    );
    expect(result.windowSize, 7);
    expect(result.metCount, 7);
    expect(result.ratio, 1.0);
  });
}
