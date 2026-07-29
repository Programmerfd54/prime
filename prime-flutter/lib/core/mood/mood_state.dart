import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/theme/prime_palette.dart';
import '../../design/visuals/habit_tags.dart';

/// Daily mood check-in — five states mapped to habit filter tags.
enum MoodKind {
  drained(
    label: 'Выжат',
    description: 'Сил мало — лучше мягкий отдых и восстановление, без перегруза.',
    color: PrimePalette.purpleGrey,
    filterTag: HabitFilterTag.rest,
  ),
  tense(
    label: 'Напряжён',
    description: 'Много мыслей — помогут спокойные ритуалы и замедление.',
    color: PrimePalette.coral,
    filterTag: HabitFilterTag.rest,
  ),
  calm(
    label: 'Спокойно',
    description: 'Ровное состояние — хороший момент для лёгкого развития.',
    color: PrimePalette.mint,
    filterTag: HabitFilterTag.growth,
  ),
  balanced(
    label: 'В балансе',
    description: 'Стабильный ресурс — можно выбрать любую привычку по вкусу.',
    color: PrimePalette.brand,
    filterTag: HabitFilterTag.all,
  ),
  energized(
    label: 'Бодро',
    description: 'Много энергии — самое время для движения и активных действий.',
    color: PrimePalette.habitCharge,
    filterTag: HabitFilterTag.body,
  );

  const MoodKind({
    required this.label,
    required this.description,
    required this.color,
    required this.filterTag,
  });

  final String label;
  final String description;
  final Color color;
  final HabitFilterTag filterTag;

  static MoodKind? byName(String? raw) {
    if (raw == null) return null;
    for (final k in MoodKind.values) {
      if (k.name == raw) return k;
    }
    return null;
  }
}

/// One persisted mood log row: `{date, kind}`.
class MoodLogEntry {
  const MoodLogEntry({required this.date, required this.kind});

  final String date;
  final MoodKind kind;

  Map<String, dynamic> toJson() => {
        'date': date,
        'kind': kind.name,
      };

  factory MoodLogEntry.fromJson(Map<String, dynamic> json) {
    return MoodLogEntry(
      date: json['date'] as String? ?? '',
      kind: MoodKind.byName(json['kind'] as String?) ?? MoodKind.balanced,
    );
  }
}

/// Local mood log backed by SharedPreferences.
abstract final class MoodState {
  static const _key = 'prime_mood_log_v1';

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static Future<List<MoodLogEntry>> loadLog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(MoodLogEntry.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _saveLog(List<MoodLogEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  static Future<MoodKind?> today() async {
    final today = _todayKey();
    final log = await loadLog();
    for (final entry in log.reversed) {
      if (entry.date == today) return entry.kind;
    }
    return null;
  }

  static Future<void> logToday(MoodKind kind) async {
    final today = _todayKey();
    final log = await loadLog();
    final updated = [
      for (final entry in log)
        if (entry.date != today) entry,
      MoodLogEntry(date: today, kind: kind),
    ];
    await _saveLog(updated);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
