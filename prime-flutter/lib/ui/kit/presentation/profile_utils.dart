/// Removes debug / placeholder bio text (TZ §7.4, §19).
String sanitizeProfileBio(String? raw) {
  if (raw == null) return '';
  final text = raw.trim();
  if (text.isEmpty) return '';
  final lower = text.toLowerCase();
  const blocked = [
    'lorem ipsum',
    'test bio',
    'debug bio',
    'asdf',
    'qwerty',
    'todo:',
    'fixme',
  ];
  for (final token in blocked) {
    if (lower.contains(token)) return '';
  }
  return text;
}
