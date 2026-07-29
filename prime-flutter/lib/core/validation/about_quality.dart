/// Shared validation for progressive-profiling "about" before joining a team.
abstract final class AboutQuality {
  static const minWords = 50;

  static int wordCount(String text) =>
      text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  /// Rejects punctuation-only, too few unique words, or single-word spam.
  static String? junkReason(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'Расскажите немного о себе перед поиском команды';
    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length < minWords) {
      return 'Нужно минимум $minWords слов (сейчас ${words.length})';
    }
    final lettersOnly =
        trimmed.replaceAll(RegExp(r'[^a-zA-Zа-яА-ЯёЁ0-9\s]'), '');
    if (lettersOnly.trim().isEmpty) {
      return 'Описание не должно состоять только из знаков препинания';
    }
    final normalized = words.map((w) => w.toLowerCase()).toList();
    final unique = normalized.toSet();
    if (unique.length < 3) {
      return 'Добавьте больше разных слов — так команде будет проще узнать вас';
    }
    final top = <String, int>{};
    for (final w in normalized) {
      top[w] = (top[w] ?? 0) + 1;
    }
    final maxCount = top.values.fold<int>(0, (a, b) => a > b ? a : b);
    if (maxCount > words.length * 0.5) {
      return 'Избегайте повторения одного и того же слова';
    }
    return null;
  }
}
