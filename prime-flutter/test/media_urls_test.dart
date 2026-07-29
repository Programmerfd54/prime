import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/media/media_urls.dart';

void main() {
  group('absolutePhotoUrl', () {
    test('returns null for empty values', () {
      expect(absolutePhotoUrl(null), isNull);
      expect(absolutePhotoUrl(''), isNull);
    });

    test('passes through absolute http urls', () {
      const url = 'https://cdn.example/avatars/u1.jpg?v=2';
      expect(absolutePhotoUrl(url), url);
    });

    test('prefixes relative api paths', () {
      final resolved = absolutePhotoUrl('/uploads/avatars/u1.jpg');
      expect(resolved, isNotNull);
      expect(resolved!, contains('/uploads/avatars/u1.jpg'));
      expect(resolved.startsWith('http'), isTrue);
    });
  });

  group('absoluteMediaUrl', () {
    test('resolves chat media paths', () {
      final resolved = absoluteMediaUrl('/media/chat/file.pdf');
      expect(resolved, isNotNull);
      expect(resolved!, contains('/media/chat/file.pdf'));
    });
  });
}
