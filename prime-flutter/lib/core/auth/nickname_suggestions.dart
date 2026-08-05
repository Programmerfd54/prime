import 'dart:math';

/// Client-side nickname ideas for signup (RU / EN, max 20 chars).
abstract final class NicknameSuggestions {
  static const maxLength = 20;
  static const minLength = 3;

  static final _random = Random();

  static const _ruAdjectives = [
    'волна',
    'искра',
    'ритм',
    'фокус',
    'свет',
    'шаг',
    'путь',
    'день',
  ];

  static const _ruNouns = [
    'прайм',
    'комета',
    'пульс',
    'старт',
    'огонь',
    'ветер',
    'заряд',
    'ум',
  ];

  static const _enAdjectives = [
    'spark',
    'focus',
    'calm',
    'bright',
    'prime',
    'steady',
    'clear',
    'bold',
  ];

  static const _enNouns = [
    'wave',
    'pulse',
    'step',
    'flow',
    'orbit',
    'rise',
    'path',
    'day',
  ];

  static bool isCyrillic(String value) {
    for (final rune in value.runes) {
      if (rune >= 0x0400 && rune <= 0x04FF) return true;
    }
    return false;
  }

  static List<String> suggestNicknames(
    String seed, {
    int count = 3,
  }) {
    final trimmed = seed.trim().toLowerCase().replaceAll('@', '');
    final cyrillic = isCyrillic(trimmed);
    final adjectives = cyrillic ? _ruAdjectives : _enAdjectives;
    final nouns = cyrillic ? _ruNouns : _enNouns;
    final ideas = <String>{};

    if (trimmed.length >= minLength && trimmed.length <= maxLength) {
      ideas.add(trimmed);
    }

    final prefix = trimmed.isNotEmpty
        ? trimmed.replaceAll(RegExp(r'[^a-z0-9_\u0401\u0430-\u044f\u0451]'), '')
        : '';

    while (ideas.length < count + 2) {
      final adj = adjectives[_random.nextInt(adjectives.length)];
      final noun = nouns[_random.nextInt(nouns.length)];
      final digits = _random.nextInt(90) + 10;
      final candidates = <String>[
        if (prefix.isNotEmpty) _truncate('${prefix}_$digits'),
        if (prefix.isNotEmpty) _truncate('$prefix$digits'),
        _truncate('$adj$noun'),
        _truncate('${adj}_$noun'),
        _truncate('${noun}_$digits'),
        _truncate('$adj$digits'),
      ];
      for (final candidate in candidates) {
        if (_looksValid(candidate)) ideas.add(candidate);
        if (ideas.length >= count + 2) break;
      }
    }

    return ideas.take(count).toList();
  }

  static String _truncate(String value) {
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }

  static bool _looksValid(String value) {
    if (value.length < minLength || value.length > maxLength) return false;
    return RegExp(r'^[a-z0-9_\u0401\u0430-\u044f\u0451][a-z0-9_.\-\u0401\u0430-\u044f\u0451]+$')
        .hasMatch(value);
  }
}

/// Shared nickname validation pattern (RU + EN, 3–20 chars).
final nicknamePattern = RegExp(
  r'^[a-z0-9_\u0401\u0430-\u044f\u0451][a-z0-9_.\-\u0401\u0430-\u044f\u0451]{2,19}$',
);

bool isValidNicknameFormat(String value) =>
    nicknamePattern.hasMatch(value.trim().toLowerCase().replaceAll('@', ''));

const nicknameFormatHint =
    '3–20 символов · русский или английский · a-z, 0-9, _, -, .';

const nicknameFormatError =
    '3–20 символов: русские или латинские буквы, цифры, точка, дефис или _';
