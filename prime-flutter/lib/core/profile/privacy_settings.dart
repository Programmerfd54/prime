/// Default visibility flags — mirrors backend [DEFAULT_PRIVACY_SETTINGS].
const defaultPrivacySettings = <String, bool>{
  'show_bio': true,
  'show_age': true,
  'show_region': true,
  'show_habits': true,
  'show_streak': true,
  'show_achievements': true,
  'show_groups': true,
};

Map<String, bool> parsePrivacySettings(Object? raw) {
  if (raw is! Map) return Map<String, bool>.from(defaultPrivacySettings);
  final merged = Map<String, bool>.from(defaultPrivacySettings);
  for (final key in defaultPrivacySettings.keys) {
    final value = raw[key];
    if (value is bool) merged[key] = value;
  }
  return merged;
}
