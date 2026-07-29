class AchievementModel {
  final String id;
  final String code;
  final String name;
  final int requiredDays;
  final String description;
  final String icon;
  final bool unlocked;
  final DateTime? awardedAt;

  AchievementModel({
    required this.id,
    required this.code,
    required this.name,
    required this.requiredDays,
    required this.description,
    required this.icon,
    required this.unlocked,
    this.awardedAt,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> j) => AchievementModel(
        id: j['id'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        requiredDays: j['required_days'] as int,
        description: j['description'] as String? ?? '',
        icon: j['icon'] as String? ?? 'medal',
        unlocked: j['unlocked'] as bool? ?? false,
        awardedAt: j['awarded_at'] != null
            ? DateTime.parse(j['awarded_at'] as String)
            : null,
      );
}
