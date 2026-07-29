import 'package:flutter/foundation.dart';

/// Адрес можно переопределить при сборке:
/// `--dart-define=API_BASE_URL=https://api.example.com`.
String get apiBaseUrl {
  const configured = String.fromEnvironment('API_BASE_URL');
  if (configured.isNotEmpty) {
    return normalizeApiBaseUrl(configured);
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8080';
  }
  return 'http://localhost:8080';
}

const String kApiPrefix = '/api/v1';

String normalizeApiBaseUrl(String value) {
  var normalized = value.trim();
  while (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  if (normalized.endsWith(kApiPrefix)) {
    normalized = normalized.substring(0, normalized.length - kApiPrefix.length);
  }
  return normalized;
}
