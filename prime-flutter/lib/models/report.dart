class CalendarDay {
  final DateTime date;
  final String status;
  final bool completed;
  final bool reported;
  final bool primeAwarded;
  final bool supportGiven;
  final String contentText;
  final List<Map<String, dynamic>> attachments;
  final List<Map<String, dynamic>> reports;

  CalendarDay({
    required this.date,
    required this.status,
    required this.completed,
    required this.reported,
    required this.primeAwarded,
    this.supportGiven = false,
    required this.contentText,
    required this.attachments,
    required this.reports,
  });

  factory CalendarDay.fromJson(Map<String, dynamic> j) {
    final status = j['status'] as String? ?? '';
    final reported = j['reported'] as bool? ?? status == 'ready';
    final completed = j['completed'] as bool? ?? reported;
    return CalendarDay(
      date: DateTime.parse(j['date'] as String),
      status: status,
      completed: completed,
      reported: reported,
      primeAwarded: j['prime_awarded'] as bool? ?? completed,
      supportGiven: j['support_given'] as bool? ?? false,
      contentText: j['content_text'] as String? ?? '',
      attachments: (j['attachments'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList(),
      reports: (j['reports'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList(),
    );
  }
}

class ProfileInsightModel {
  const ProfileInsightModel({
    required this.id,
    required this.kind,
    required this.title,
    required this.message,
  });

  final String id;
  final String kind;
  final String title;
  final String message;

  factory ProfileInsightModel.fromJson(Map<String, dynamic> json) =>
      ProfileInsightModel(
        id: json['id'] as String? ?? '',
        kind: json['kind'] as String? ?? '',
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
      );
}

class CalendarOut {
  final List<CalendarDay> days;
  final DateTime today;
  final DateTime? trackingStartDate;
  final int currentStreak;
  final int bestStreak;
  final int successfulDays;
  final int primePoints;
  final int? cyclePacePercent;
  final int streakShields;
  final bool shieldPending;
  final List<ProfileInsightModel> insights;

  CalendarOut({
    required this.days,
    required this.today,
    required this.trackingStartDate,
    required this.currentStreak,
    required this.bestStreak,
    required this.successfulDays,
    required this.primePoints,
    this.cyclePacePercent,
    this.streakShields = 0,
    this.shieldPending = false,
    this.insights = const [],
  });

  factory CalendarOut.fromJson(Map<String, dynamic> j) => CalendarOut(
        days: (j['days'] as List<dynamic>? ?? [])
            .map((d) => CalendarDay.fromJson(d as Map<String, dynamic>))
            .toList(),
        today: DateTime.parse(
          j['today'] as String? ?? DateTime.now().toIso8601String(),
        ),
        trackingStartDate: j['tracking_start_date'] == null
            ? null
            : DateTime.parse(j['tracking_start_date'] as String),
        currentStreak: j['current_streak'] as int? ?? 0,
        bestStreak: j['best_streak'] as int? ?? 0,
        successfulDays: j['successful_days'] as int? ?? 0,
        primePoints: j['prime_points'] as int? ?? 0,
        cyclePacePercent: j['cycle_pace_percent'] as int?,
        streakShields: j['streak_shields'] as int? ?? 0,
        shieldPending: j['shield_pending'] as bool? ?? false,
        insights: (j['insights'] as List<dynamic>? ?? [])
            .map((e) => ProfileInsightModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
