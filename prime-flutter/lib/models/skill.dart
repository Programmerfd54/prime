enum SkillCategory { official, top, custom }

class SkillModel {
  final String id;
  final String name;
  final String description;
  final String icon;
  final SkillCategory category;
  final int popularity;

  SkillModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.popularity,
  });

  factory SkillModel.fromJson(Map<String, dynamic> j) => SkillModel(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String? ?? '',
        icon: j['icon'] as String? ?? 'star',
        category: SkillCategory.values.firstWhere(
          (e) => e.name == j['category'],
          orElse: () => SkillCategory.official,
        ),
        popularity: j['popularity'] as int? ?? 0,
      );
}
