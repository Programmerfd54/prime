/// Client-side media limits aligned with backend direct-chat upload.
abstract final class MediaLimits {
  static const avatarSourceMaxBytes = 10 * 1024 * 1024;
  static const avatarUploadMaxBytes = 5 * 1024 * 1024;
  static const directImageMaxBytes = 10 * 1024 * 1024;
  static const directFileMaxBytes = 25 * 1024 * 1024;

  static const allowedAvatarTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  static const allowedImageTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
    'image/heif',
  };

  static const allowedFileTypes = {
    'application/pdf',
    'text/plain',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/zip',
  };
}

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes Б';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} КБ';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
}

String? mimeFromFilename(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic')) return 'image/heic';
  if (lower.endsWith('.heif')) return 'image/heif';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.txt')) return 'text/plain';
  if (lower.endsWith('.doc')) return 'application/msword';
  if (lower.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
  if (lower.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
  if (lower.endsWith('.pptx')) {
    return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
  }
  if (lower.endsWith('.zip')) return 'application/zip';
  return null;
}

String mediaValidationError({
  required int sizeBytes,
  required String? mimeType,
  required bool isImage,
}) {
  final max = isImage
      ? MediaLimits.directImageMaxBytes
      : MediaLimits.directFileMaxBytes;
  if (sizeBytes > max) {
    return isImage
        ? 'Изображение слишком большое. Максимальный размер — 10 МБ'
        : 'Файл слишком большой. Максимальный размер — 25 МБ';
  }
  if (mimeType == null || mimeType.isEmpty) {
    return 'Этот формат пока не поддерживается';
  }
  if (isImage && !MediaLimits.allowedImageTypes.contains(mimeType)) {
    return 'Этот формат пока не поддерживается';
  }
  if (!isImage &&
      !MediaLimits.allowedFileTypes.contains(mimeType) &&
      !mimeType.startsWith('image/')) {
    return 'Этот формат пока не поддерживается';
  }
  return 'Не удалось обработать файл';
}

String avatarValidationError({required int sizeBytes, required String? mimeType}) {
  if (sizeBytes > MediaLimits.avatarSourceMaxBytes) {
    return 'Файл слишком большой. Максимальный размер — 10 МБ';
  }
  if (mimeType == null ||
      !MediaLimits.allowedAvatarTypes.contains(mimeType) &&
          mimeType != 'image/heic' &&
          mimeType != 'image/heif') {
    return 'Этот формат пока не поддерживается. Используйте JPG, PNG или WebP';
  }
  return 'Не удалось обработать изображение';
}
