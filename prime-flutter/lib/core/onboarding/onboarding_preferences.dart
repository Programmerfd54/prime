import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Personalization from onboarding — cached locally, synced via [UserPersonalizationSync].
enum OnboardingGoal {
  lessDistraction('Меньше отвлекаться', 'digital-detox'),
  moveMore('Начать двигаться', 'body-charge'),
  readRegularly('Читать регулярно', 'one-chapter'),
  betterMorning('Лучше начинать день', 'morning-focus'),
  eveningRoutine('Улучшить вечерний режим', 'evening-ritual'),
  socialize('Больше общаться', 'live-communication'),
  betterSleep('Лучше спать', 'evening-ritual'),
  lessStress('Меньше стресса', 'evening-ritual'),
  lessSocialFeed('Меньше ленты', 'digital-detox'),
  readInsteadOfFeed('Читать вместо скролла', 'one-chapter');

  const OnboardingGoal(this.label, this.recommendedSkillId);

  final String label;
  final String recommendedSkillId;

  static OnboardingGoal? byName(String? raw) {
    if (raw == null) return null;
    for (final g in OnboardingGoal.values) {
      if (g.name == raw) return g;
    }
    return null;
  }
}

/// Official program previews shown on onboarding step 3.
class OnboardingProgramPreview {
  const OnboardingProgramPreview({
    required this.skillId,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String skillId;
  final String title;
  final String subtitle;
  final IconData icon;

  static const all = [
    OnboardingProgramPreview(
      skillId: 'live-communication',
      title: 'Живое общение',
      subtitle: 'Один осознанный разговор каждый день — без телефона',
      icon: Icons.forum_outlined,
    ),
    OnboardingProgramPreview(
      skillId: 'digital-detox',
      title: 'Цифровой детокс',
      subtitle: '45 минут хобби вместо бесцельного скролла',
      icon: Icons.phonelink_erase_outlined,
    ),
    OnboardingProgramPreview(
      skillId: 'one-chapter',
      title: 'Одна глава',
      subtitle: 'От 5 страниц в день — и через месяц целая книга',
      icon: Icons.menu_book_outlined,
    ),
    OnboardingProgramPreview(
      skillId: 'morning-focus',
      title: 'Утренний фокус',
      subtitle: '40 минут без экрана — ясная голова с утра',
      icon: Icons.wb_sunny_outlined,
    ),
    OnboardingProgramPreview(
      skillId: 'body-charge',
      title: 'Зарядка для тела',
      subtitle: '10 минут утром + силовая три раза в неделю',
      icon: Icons.fitness_center_outlined,
    ),
    OnboardingProgramPreview(
      skillId: 'evening-ritual',
      title: 'Вечерний ритуал',
      subtitle: 'Телефон вне спальни — качественный отдых',
      icon: Icons.dark_mode_outlined,
    ),
  ];
}

class OnboardingPreferences {
  static const _key = 'prime_onboarding_preferences';

  const OnboardingPreferences({
    this.goal,
    this.goals = const [],
    this.selectedSkillId,
    this.habitQuitCount,
    this.habitAttemptCount,
    this.completedAt,
  });

  /// Primary goal (first selected) — kept for backward compatibility.
  final OnboardingGoal? goal;

  /// Multi-select goals from onboarding step 7 (max 3 in UI).
  final List<OnboardingGoal> goals;

  final String? selectedSkillId;
  final String? habitQuitCount;
  final String? habitAttemptCount;
  final DateTime? completedAt;

  List<OnboardingGoal> get effectiveGoals {
    if (goals.isNotEmpty) return goals;
    if (goal != null) return [goal!];
    return const [];
  }

  String? get recommendedSkillId =>
      selectedSkillId ??
      goal?.recommendedSkillId ??
      (goals.isEmpty ? null : goals.first.recommendedSkillId);

  String? recommendationReason(OnboardingGoal? g) {
    final list = effectiveGoals;
    if (g != null) return 'Вы выбрали цель «${g.label}»';
    if (list.isEmpty) return null;
    if (list.length == 1) return 'Вы выбрали цель «${list.first.label}»';
    final labels = list.map((e) => '«${e.label}»').join(', ');
    return 'Вы выбрали цели: $labels';
  }

  Map<String, dynamic> toJson() => {
        if (goal != null) 'goal': goal!.name,
        if (goals.isNotEmpty) 'goals': goals.map((g) => g.name).toList(),
        if (selectedSkillId != null) 'selected_skill_id': selectedSkillId,
        if (habitQuitCount != null) 'habit_quit_count': habitQuitCount,
        if (habitAttemptCount != null) 'habit_attempt_count': habitAttemptCount,
        if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      };

  factory OnboardingPreferences.fromJson(Map<String, dynamic> json) {
    final parsedGoals = <OnboardingGoal>[];
    final rawGoals = json['goals'];
    if (rawGoals is List) {
      for (final item in rawGoals) {
        final g = OnboardingGoal.byName(item?.toString());
        if (g != null && !parsedGoals.contains(g)) parsedGoals.add(g);
      }
    }

    final primary = OnboardingGoal.byName(json['goal'] as String?) ??
        (parsedGoals.isNotEmpty ? parsedGoals.first : null);
    if (primary != null && parsedGoals.isEmpty) {
      parsedGoals.add(primary);
    } else if (primary != null && !parsedGoals.contains(primary)) {
      parsedGoals.insert(0, primary);
    }

    DateTime? completedAt;
    final rawDate = json['completed_at'] as String?;
    if (rawDate != null) completedAt = DateTime.tryParse(rawDate);

    return OnboardingPreferences(
      goal: primary,
      goals: parsedGoals,
      selectedSkillId: json['selected_skill_id'] as String?,
      habitQuitCount: json['habit_quit_count'] as String?,
      habitAttemptCount: json['habit_attempt_count'] as String?,
      completedAt: completedAt,
    );
  }

  OnboardingPreferences copyWith({
    OnboardingGoal? goal,
    List<OnboardingGoal>? goals,
    String? selectedSkillId,
    String? habitQuitCount,
    String? habitAttemptCount,
    DateTime? completedAt,
  }) {
    return OnboardingPreferences(
      goal: goal ?? this.goal,
      goals: goals ?? this.goals,
      selectedSkillId: selectedSkillId ?? this.selectedSkillId,
      habitQuitCount: habitQuitCount ?? this.habitQuitCount,
      habitAttemptCount: habitAttemptCount ?? this.habitAttemptCount,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  static Future<OnboardingPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const OnboardingPreferences();
    try {
      return OnboardingPreferences.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const OnboardingPreferences();
    }
  }

  static Future<void> save(OnboardingPreferences prefs) async {
    final storage = await SharedPreferences.getInstance();
    await storage.setString(_key, jsonEncode(prefs.toJson()));
  }

  static Future<void> clear() async {
    final storage = await SharedPreferences.getInstance();
    await storage.remove(_key);
  }
}
