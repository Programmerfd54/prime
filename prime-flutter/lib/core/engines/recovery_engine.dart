/// Pure "what to suggest after a miss" decision logic — no UI, no I/O.
///
/// PRIME's product stance is that a miss should never be punished harder
/// than necessary (see `AppCopy.howDayCounts` / `AppCopy.skipPolicy`
/// copy). This engine turns that stance into a deterministic, testable
/// suggestion so the UI layer can render a consistent nudge instead of
/// inventing ad-hoc thresholds per screen.
///
/// ## Decision table
///
/// Input: [consecutiveMisses] — number of days in a row, up to and
/// including the most recent day, where the user did not meet the daily
/// minimum action.
///
/// | `consecutiveMisses` | Suggested action | Reason |
/// |---|---|---|
/// | 0 | [RecoveryAction.none] | Nothing to recover from |
/// | 1 | [RecoveryAction.comeBackTomorrow] | One miss is normal — avoid overreacting |
/// | 2 | [RecoveryAction.tryShortVersion] | A shortened/minimal version breaks the pattern before it compounds |
/// | >= 3 | [RecoveryAction.askTeamForSupport] | Repeated misses call for the team's support channel, not more solo willpower |
enum RecoveryAction {
  none,
  comeBackTomorrow,
  tryShortVersion,
  askTeamForSupport,
}

class RecoverySuggestion {
  const RecoverySuggestion({
    required this.action,
    required this.reason,
    required this.consecutiveMisses,
  });

  final RecoveryAction action;

  /// Short, machine-readable reason code (not localized copy) — the UI
  /// layer maps this to RU text via its own copy table.
  final String reason;

  final int consecutiveMisses;

  @override
  String toString() =>
      'RecoverySuggestion($action, misses: $consecutiveMisses, reason: $reason)';
}

abstract final class RecoveryEngine {
  static RecoverySuggestion suggest({required int consecutiveMisses}) {
    final misses = consecutiveMisses < 0 ? 0 : consecutiveMisses;
    return switch (misses) {
      0 => RecoverySuggestion(
          action: RecoveryAction.none,
          reason: 'no_miss',
          consecutiveMisses: misses,
        ),
      1 => RecoverySuggestion(
          action: RecoveryAction.comeBackTomorrow,
          reason: 'single_miss_is_normal',
          consecutiveMisses: misses,
        ),
      2 => RecoverySuggestion(
          action: RecoveryAction.tryShortVersion,
          reason: 'break_pattern_before_it_compounds',
          consecutiveMisses: misses,
        ),
      _ => RecoverySuggestion(
          action: RecoveryAction.askTeamForSupport,
          reason: 'repeated_misses_need_team_support',
          consecutiveMisses: misses,
        ),
    };
  }

  /// Counts consecutive misses at the tail of a chronologically-sorted
  /// (oldest-first) list of "did the user meet the minimum today" flags.
  static int consecutiveMissesFromTail(List<bool> metMinimumByDayAsc) {
    var count = 0;
    for (var i = metMinimumByDayAsc.length - 1; i >= 0; i--) {
      if (metMinimumByDayAsc[i]) break;
      count++;
    }
    return count;
  }
}
