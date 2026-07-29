import 'privacy_settings.dart';

enum PrivacyPreset { open, team, private }

const privacyPresetLabels = {
  PrivacyPreset.open: 'Открытый',
  PrivacyPreset.team: 'Команда',
  PrivacyPreset.private: 'Приватный',
};

Map<String, bool> privacyPresetValues(PrivacyPreset preset) {
  switch (preset) {
    case PrivacyPreset.open:
      return Map.from(defaultPrivacySettings);
    case PrivacyPreset.team:
      return {
        'show_bio': false,
        'show_age': false,
        'show_region': false,
        'show_streak': true,
        'show_achievements': true,
        'show_habits': true,
        'show_groups': true,
      };
    case PrivacyPreset.private:
      return {
        for (final key in defaultPrivacySettings.keys) key: false,
      };
  }
}

PrivacyPreset? detectPrivacyPreset(Map<String, bool> settings) {
  for (final preset in PrivacyPreset.values) {
    final values = privacyPresetValues(preset);
    if (values.entries.every((e) => settings[e.key] == e.value)) {
      return preset;
    }
  }
  return null;
}
