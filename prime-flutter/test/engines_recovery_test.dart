import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/engines/recovery_engine.dart';

void main() {
  test('zero misses suggests no action', () {
    final suggestion = RecoveryEngine.suggest(consecutiveMisses: 0);
    expect(suggestion.action, RecoveryAction.none);
  });

  test('a single miss suggests coming back tomorrow', () {
    final suggestion = RecoveryEngine.suggest(consecutiveMisses: 1);
    expect(suggestion.action, RecoveryAction.comeBackTomorrow);
  });

  test('two consecutive misses suggests a shortened version', () {
    final suggestion = RecoveryEngine.suggest(consecutiveMisses: 2);
    expect(suggestion.action, RecoveryAction.tryShortVersion);
  });

  test('three or more consecutive misses suggests asking the team', () {
    expect(
      RecoveryEngine.suggest(consecutiveMisses: 3).action,
      RecoveryAction.askTeamForSupport,
    );
    expect(
      RecoveryEngine.suggest(consecutiveMisses: 10).action,
      RecoveryAction.askTeamForSupport,
    );
  });

  test('negative input is clamped to zero misses', () {
    final suggestion = RecoveryEngine.suggest(consecutiveMisses: -5);
    expect(suggestion.action, RecoveryAction.none);
    expect(suggestion.consecutiveMisses, 0);
  });

  test('consecutiveMissesFromTail counts only the trailing run', () {
    // met, miss, met, miss, miss -> trailing run of 2 misses.
    final history = [true, false, true, false, false];
    expect(RecoveryEngine.consecutiveMissesFromTail(history), 2);
  });

  test('consecutiveMissesFromTail returns zero when the last day was met', () {
    final history = [false, false, true];
    expect(RecoveryEngine.consecutiveMissesFromTail(history), 0);
  });

  test('consecutiveMissesFromTail handles an all-miss history', () {
    final history = [false, false, false];
    expect(RecoveryEngine.consecutiveMissesFromTail(history), 3);
  });

  test('consecutiveMissesFromTail handles an empty history', () {
    expect(RecoveryEngine.consecutiveMissesFromTail(const []), 0);
  });
}
