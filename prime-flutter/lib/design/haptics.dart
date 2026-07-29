import 'package:flutter/services.dart';

/// Light haptics for meaningful moments only — never every tap.
abstract final class AppHaptics {
  static Future<void> selection() => HapticFeedback.selectionClick();

  static Future<void> light() => HapticFeedback.lightImpact();

  static Future<void> medium() => HapticFeedback.mediumImpact();

  static Future<void> success() => HapticFeedback.mediumImpact();

  static Future<void> warning() => HapticFeedback.heavyImpact();

  static Future<void> send() => HapticFeedback.lightImpact();
}
