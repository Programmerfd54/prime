import '../../models/report.dart';

/// Days where the user reported ready but the team day is not complete.
int reportTeamGapDays(CalendarOut calendar) {
  return calendar.days.where((d) => d.reported && !d.completed).length;
}

/// Skill name → count of completed team-day reports.
Map<String, int> completionBySkill(CalendarOut calendar) {
  final counts = <String, int>{};
  for (final day in calendar.days) {
    if (!day.completed) continue;
    for (final report in day.reports) {
      if (report['status'] != 'ready') continue;
      final name = report['skill_name'] as String? ?? '';
      if (name.isEmpty) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }
  }
  return counts;
}

/// Skill id → total positive prime amount from event list.
Map<String, int> primesBySkill(List<dynamic> events) {
  final counts = <String, int>{};
  for (final raw in events) {
    if (raw is! Map) continue;
    final map = Map<String, dynamic>.from(raw);
    final skillId = map['skill_id'] as String?;
    if (skillId == null || skillId.isEmpty) continue;
    final amount = map['amount'] as num? ?? 0;
    if (amount > 0) {
      counts[skillId] = (counts[skillId] ?? 0) + amount.toInt();
    }
  }
  return counts;
}
