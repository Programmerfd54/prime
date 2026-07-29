import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/media/avatar_upload.dart';
import 'package:prime/core/media/media_validation.dart';

void main() {
  group('prepareAvatarUpload', () {
    test('accepts small jpeg bytes', () async {
      final file = XFile.fromData(
        Uint8List.fromList(List.filled(512, 1)),
        name: 'profile.jpg',
        mimeType: 'image/jpeg',
      );

      final payload = await prepareAvatarUpload(file);

      expect(payload.contentType, 'image/jpeg');
      expect(payload.filename, endsWith('.jpg'));
      expect(payload.bytes.length, 512);
    });

    test('rejects oversize source file', () async {
      final file = XFile.fromData(
        Uint8List(MediaLimits.avatarSourceMaxBytes + 1),
        name: 'big.jpg',
        mimeType: 'image/jpeg',
      );

      expect(
        () => prepareAvatarUpload(file),
        throwsA(isA<AvatarUploadException>()),
      );
    });

    test('rejects unsupported mime type', () async {
      final file = XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'avatar.gif',
        mimeType: 'image/gif',
      );

      expect(
        () => prepareAvatarUpload(file),
        throwsA(
          predicate<AvatarUploadException>(
            (e) => e.message.contains('не поддерживается'),
          ),
        ),
      );
    });

    test('rejects empty file', () async {
      final file = XFile.fromData(
        Uint8List(0),
        name: 'empty.jpg',
        mimeType: 'image/jpeg',
      );

      expect(
        () => prepareAvatarUpload(file),
        throwsA(isA<AvatarUploadException>()),
      );
    });
  });
}
