/// Pure "should we remind this user right now" decision logic.
///
/// This engine never sends a push notification and never reads the clock
/// itself — it only decides, given inputs the caller already resolved in
/// the user's local timezone, whether a reminder is due and why (or why
/// not). Wiring this to an actual push scheduler is out of scope here.
///
/// ## Decision order
///
/// 1. Already checked in today → never remind.
/// 2. Inside quiet hours (if configured) → don't remind, even if the
///    preferred time has passed — respect user-set do-not-disturb.
/// 3. Before the preferred time (if configured) → too early, wait.
/// 4. Otherwise → remind.
///
/// [TimeOfDayValue] intentionally avoids Flutter's `TimeOfDay` so this
/// file has zero framework dependency and can be tested with plain
/// `package:test`-style assertions under `flutter_test`.
class TimeOfDayValue {
  const TimeOfDayValue(this.hour, this.minute);

  final int hour;
  final int minute;

  int get minutesSinceMidnight => hour * 60 + minute;

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class ReminderDecision {
  const ReminderDecision({required this.shouldRemind, required this.reason});

  final bool shouldRemind;

  /// Machine-readable reason code (not localized copy).
  final String reason;

  @override
  String toString() => 'ReminderDecision(shouldRemind: $shouldRemind, reason: $reason)';
}

abstract final class ReminderEngine {
  /// [now] must already be expressed in the user's local timezone — this
  /// engine performs no timezone conversion itself, it only compares
  /// wall-clock minutes-of-day.
  static ReminderDecision decide({
    required DateTime now,
    required bool alreadyCheckedIn,
    TimeOfDayValue? quietHoursStart,
    TimeOfDayValue? quietHoursEnd,
    TimeOfDayValue? preferredTime,
  }) {
    if (alreadyCheckedIn) {
      return const ReminderDecision(
        shouldRemind: false,
        reason: 'already_checked_in',
      );
    }

    final nowMinutes = now.hour * 60 + now.minute;

    if (quietHoursStart != null &&
        quietHoursEnd != null &&
        _inQuietHours(
          nowMinutes,
          quietHoursStart.minutesSinceMidnight,
          quietHoursEnd.minutesSinceMidnight,
        )) {
      return const ReminderDecision(shouldRemind: false, reason: 'quiet_hours');
    }

    if (preferredTime != null &&
        nowMinutes < preferredTime.minutesSinceMidnight) {
      return const ReminderDecision(
        shouldRemind: false,
        reason: 'before_preferred_time',
      );
    }

    return ReminderDecision(
      shouldRemind: true,
      reason: preferredTime != null
          ? 'preferred_time_reached'
          : 'default_reminder_window',
    );
  }

  /// Handles windows that wrap midnight (e.g. 22:00 → 07:00). A
  /// zero-length window (`start == end`) means "no quiet hours".
  static bool _inQuietHours(int nowMinutes, int startMinutes, int endMinutes) {
    if (startMinutes == endMinutes) return false;
    if (startMinutes < endMinutes) {
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    }
    return nowMinutes >= startMinutes || nowMinutes < endMinutes;
  }
}
