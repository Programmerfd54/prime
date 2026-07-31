import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

/// Best-effort local IANA timezone for server team-day alignment.
abstract final class DeviceTimezone {
  static String? _cached;

  static Future<String?> localIana() async {
    if (_cached != null) return _cached;
    try {
      if (kIsWeb) {
        _cached = 'UTC';
        return _cached;
      }
      final tz = await FlutterTimezone.getLocalTimezone();
      _cached = tz;
      return _cached;
    } catch (_) {
      return null;
    }
  }
}
