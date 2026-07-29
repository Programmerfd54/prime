import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/engines/reminder_engine.dart';

void main() {
  test('already checked in never reminds, even during the preferred time', () {
    final decision = ReminderEngine.decide(
      now: DateTime(2026, 1, 1, 20, 0),
      alreadyCheckedIn: true,
      preferredTime: const TimeOfDayValue(20, 0),
    );
    expect(decision.shouldRemind, isFalse);
    expect(decision.reason, 'already_checked_in');
  });

  test('inside quiet hours does not remind even if preferred time passed', () {
    final decision = ReminderEngine.decide(
      now: DateTime(2026, 1, 1, 23, 30),
      alreadyCheckedIn: false,
      quietHoursStart: const TimeOfDayValue(22, 0),
      quietHoursEnd: const TimeOfDayValue(7, 0),
      preferredTime: const TimeOfDayValue(20, 0),
    );
    expect(decision.shouldRemind, isFalse);
    expect(decision.reason, 'quiet_hours');
  });

  test('quiet hours window wraps midnight correctly', () {
    final earlyMorning = ReminderEngine.decide(
      now: DateTime(2026, 1, 1, 5, 0),
      alreadyCheckedIn: false,
      quietHoursStart: const TimeOfDayValue(22, 0),
      quietHoursEnd: const TimeOfDayValue(7, 0),
    );
    expect(earlyMorning.shouldRemind, isFalse);
    expect(earlyMorning.reason, 'quiet_hours');

    final midday = ReminderEngine.decide(
      now: DateTime(2026, 1, 1, 12, 0),
      alreadyCheckedIn: false,
      quietHoursStart: const TimeOfDayValue(22, 0),
      quietHoursEnd: const TimeOfDayValue(7, 0),
    );
    expect(midday.shouldRemind, isTrue);
  });

  test('before the preferred time does not remind yet', () {
    final decision = ReminderEngine.decide(
      now: DateTime(2026, 1, 1, 8, 0),
      alreadyCheckedIn: false,
      preferredTime: const TimeOfDayValue(20, 0),
    );
    expect(decision.shouldRemind, isFalse);
    expect(decision.reason, 'before_preferred_time');
  });

  test('at or after the preferred time reminds', () {
    final decision = ReminderEngine.decide(
      now: DateTime(2026, 1, 1, 20, 0),
      alreadyCheckedIn: false,
      preferredTime: const TimeOfDayValue(20, 0),
    );
    expect(decision.shouldRemind, isTrue);
    expect(decision.reason, 'preferred_time_reached');
  });

  test('no configuration at all falls back to a default reminder window', () {
    final decision = ReminderEngine.decide(
      now: DateTime(2026, 1, 1, 15, 0),
      alreadyCheckedIn: false,
    );
    expect(decision.shouldRemind, isTrue);
    expect(decision.reason, 'default_reminder_window');
  });

  test('zero-length quiet hours window means no quiet hours at all', () {
    final decision = ReminderEngine.decide(
      now: DateTime(2026, 1, 1, 3, 0),
      alreadyCheckedIn: false,
      quietHoursStart: const TimeOfDayValue(9, 0),
      quietHoursEnd: const TimeOfDayValue(9, 0),
    );
    expect(decision.shouldRemind, isTrue);
  });
}
