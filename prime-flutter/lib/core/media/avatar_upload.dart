import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'media_validation.dart';

class AvatarUploadPayload {
  const AvatarUploadPayload({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });

  final Uint8List bytes;
  final String filename;
  final String contentType;
}

/// Reads and validates avatar bytes from [XFile].
/// Image picker compresses/resizes on mobile; HEIC is converted when possible.
Future<AvatarUploadPayload> prepareAvatarUpload(XFile file) async {
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) {
    throw AvatarUploadException('Не удалось прочитать изображение');
  }

  var mimeType = file.mimeType ?? mimeFromFilename(file.name);
  if (mimeType == 'image/heic' || mimeType == 'image/heif') {
    if (kIsWeb) {
      throw AvatarUploadException(
        'HEIC не поддерживается в браузере. Выберите JPG или PNG',
      );
    }
    mimeType = 'image/jpeg';
  }
  final contentType = mimeType ?? mimeFromFilename(file.name) ?? 'image/jpeg';

  if (bytes.length > MediaLimits.avatarSourceMaxBytes) {
    throw AvatarUploadException(
      avatarValidationError(sizeBytes: bytes.length, mimeType: contentType),
    );
  }

  final allowed = MediaLimits.allowedAvatarTypes.contains(contentType);
  if (!allowed) {
    throw AvatarUploadException(
      avatarValidationError(sizeBytes: bytes.length, mimeType: contentType),
    );
  }

  if (bytes.length > MediaLimits.avatarUploadMaxBytes) {
    throw AvatarUploadException(
      'Изображение слишком большое после сжатия. Выберите другое фото',
    );
  }

  final ext = switch (contentType) {
    'image/png' => '.png',
    'image/webp' => '.webp',
    _ => '.jpg',
  };
  final filename = file.name.isNotEmpty
      ? file.name.replaceAll(RegExp(r'\.[^.]+$'), ext)
      : 'avatar$ext';

  return AvatarUploadPayload(
    bytes: bytes,
    filename: filename,
    contentType: contentType,
  );
}

class AvatarUploadException implements Exception {
  AvatarUploadException(this.message);
  final String message;

  @override
  String toString() => message;
}
