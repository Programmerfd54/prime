import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/media/media_validation.dart';

void main() {
  group('mimeFromFilename', () {
    test('maps common extensions', () {
      expect(mimeFromFilename('photo.jpg'), 'image/jpeg');
      expect(mimeFromFilename('doc.PDF'), 'application/pdf');
      expect(mimeFromFilename('archive.zip'), 'application/zip');
      expect(mimeFromFilename('note.txt'), 'text/plain');
    });

    test('returns null for unknown extension', () {
      expect(mimeFromFilename('file.xyz'), isNull);
    });
  });

  group('mediaValidationError', () {
    test('rejects image over 10 MB', () {
      expect(
        mediaValidationError(
          sizeBytes: MediaLimits.directImageMaxBytes + 1,
          mimeType: 'image/jpeg',
          isImage: true,
        ),
        contains('10 МБ'),
      );
    });

    test('rejects file over 25 MB', () {
      expect(
        mediaValidationError(
          sizeBytes: MediaLimits.directFileMaxBytes + 1,
          mimeType: 'application/pdf',
          isImage: false,
        ),
        contains('25 МБ'),
      );
    });

    test('rejects unsupported mime for files', () {
      expect(
        mediaValidationError(
          sizeBytes: 1024,
          mimeType: 'application/x-msdownload',
          isImage: false,
        ),
        contains('не поддерживается'),
      );
    });
  });

  group('avatarValidationError', () {
    test('rejects source over 10 MB', () {
      expect(
        avatarValidationError(
          sizeBytes: MediaLimits.avatarSourceMaxBytes + 1,
          mimeType: 'image/jpeg',
        ),
        contains('10 МБ'),
      );
    });

    test('jpeg within limit skips size error', () {
      expect(
        avatarValidationError(sizeBytes: 1024, mimeType: 'image/jpeg'),
        isNot(contains('10 МБ')),
      );
    });

    test('rejects unsupported avatar type', () {
      expect(
        avatarValidationError(sizeBytes: 1024, mimeType: 'image/gif'),
        contains('не поддерживается'),
      );
    });

    test('allows heic at validation layer', () {
      expect(
        avatarValidationError(sizeBytes: 1024, mimeType: 'image/heic'),
        isNot(contains('10 МБ')),
      );
    });
  });

  group('formatFileSize', () {
    test('formats bytes kilobytes megabytes', () {
      expect(formatFileSize(512), '512 Б');
      expect(formatFileSize(2048), contains('КБ'));
      expect(formatFileSize(2 * 1024 * 1024), contains('МБ'));
    });
  });
}
