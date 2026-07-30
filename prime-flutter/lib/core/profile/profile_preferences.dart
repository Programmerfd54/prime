/// Profile rhythm / support prefs stored in onboarding_preferences JSON.
abstract final class ProfilePreferences {
  static const preferredTimeOfDayKey = 'preferred_time_of_day';
  static const supportStyleKey = 'support_style';

  static const timeOptions = [
    (label: 'Утро', value: 'morning'),
    (label: 'День', value: 'day'),
    (label: 'Вечер', value: 'evening'),
  ];

  static const supportOptions = [
    (label: 'По делу', value: 'practical'),
    (label: 'Мягко', value: 'gentle'),
    (label: 'Строго', value: 'strict'),
  ];

  static String preferredTimeLabel(String? raw) {
    for (final option in timeOptions) {
      if (option.value == raw) return option.label;
    }
    return timeOptions.first.label;
  }

  static String supportStyleLabel(String? raw) {
    for (final option in supportOptions) {
      if (option.value == raw) return option.label;
    }
    return supportOptions.first.label;
  }

  static String supportStyleDescription(String? raw) {
    return switch (raw) {
      'practical' => 'Короткие напоминания, конкретика и дела, без лишних слов',
      'gentle' => 'Поддержка без давления — можно сбиться и вернуться',
      'strict' => 'Чёткая отчётность и дисциплина, когда нужен жёсткий ритм',
      _ => 'Как команда мотивирует и напоминает о привычке',
    };
  }

  static bool rhythmSupportReady(Map<String, dynamic>? prefs) {
    if (prefs == null) return false;
    final time = prefs[preferredTimeOfDayKey];
    final support = prefs[supportStyleKey];
    return time is String &&
        time.isNotEmpty &&
        support is String &&
        support.isNotEmpty;
  }

  static String rhythmSupportSummary(Map<String, dynamic>? prefs) {
    if (!rhythmSupportReady(prefs)) {
      return 'Когда удобно заниматься и какой формат поддержки';
    }
    final time = preferredTimeLabel(prefs![preferredTimeOfDayKey] as String?);
    final support = supportStyleLabel(prefs[supportStyleKey] as String?);
    return '$time · $support';
  }

  static String? timeValueForLabel(String label) {
    for (final option in timeOptions) {
      if (option.label == label) return option.value;
    }
    return null;
  }

  static String? supportValueForLabel(String label) {
    for (final option in supportOptions) {
      if (option.label == label) return option.value;
    }
    return null;
  }
}
