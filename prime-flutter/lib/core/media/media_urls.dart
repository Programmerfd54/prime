import '../../config/constants.dart';

/// Resolves relative API photo paths to absolute URLs.
String? absolutePhotoUrl(String? value) {
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  if (value.startsWith('/')) return '$apiBaseUrl$value';
  return '$apiBaseUrl/$value';
}

/// Resolves chat media URLs (absolute or API-relative).
String? absoluteMediaUrl(String? value) {
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  if (value.startsWith('/')) return '$apiBaseUrl$value';
  return value;
}
