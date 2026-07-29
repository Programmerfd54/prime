import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/validation/about_quality.dart';

void main() {
  String words(int n, {String base = 'слово'}) =>
      List.generate(n, (i) => '$base$i').join(' ');

  test('accepts diverse 50+ word about', () {
    expect(AboutQuality.junkReason(words(50)), isNull);
  });

  test('rejects too few words', () {
    expect(AboutQuality.junkReason(words(10)), contains('50'));
  });

  test('rejects punctuation only', () {
    final text = List.filled(50, '...').join(' ');
    expect(AboutQuality.junkReason(text), isNotNull);
  });

  test('rejects single-word spam', () {
    final text = List.filled(50, 'привет').join(' ');
    expect(AboutQuality.junkReason(text), isNotNull);
  });
}
