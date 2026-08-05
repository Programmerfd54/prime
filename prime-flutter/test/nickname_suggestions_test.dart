import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/auth/nickname_suggestions.dart';

void main() {
  test('isValidNicknameFormat accepts latin and cyrillic', () {
    expect(isValidNicknameFormat('prime_user'), isTrue);
    expect(isValidNicknameFormat('праймоля'), isTrue);
    expect(isValidNicknameFormat('ab'), isFalse);
    expect(isValidNicknameFormat('a' * 21), isFalse);
  });

  test('suggestNicknames returns up to count ideas', () {
    final ru = NicknameSuggestions.suggestNicknames('вол');
    expect(ru, isNotEmpty);
    expect(ru.length, lessThanOrEqualTo(3));
    for (final item in ru) {
      expect(item.length, lessThanOrEqualTo(NicknameSuggestions.maxLength));
    }

    final en = NicknameSuggestions.suggestNicknames('spark');
    expect(en, isNotEmpty);
  });

  test('isCyrillic detects script', () {
    expect(NicknameSuggestions.isCyrillic('прайм'), isTrue);
    expect(NicknameSuggestions.isCyrillic('prime'), isFalse);
  });
}
