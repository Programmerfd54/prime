import 'package:flutter/material.dart';

/// V5 Apple-style dark glass constants — no white specular leaks.
abstract final class PrimeGlassV5 {
  /// Dark canvas tint over blur (α .72–.86).
  static const minCanvasTintAlpha = 0.72;
  static const maxCanvasTintAlpha = 0.86;

  /// Top edge highlight — hint only, never a band.
  static const maxTopRimAlpha = 0.10;

  /// Dock fill — translucent liquid glass; scrim in [MainShell] blocks bleed.
  static const dockFillOpacityDark = 0.55;
  static const dockFillOpacityLight = 0.72;

  /// Dock-only top specular (liquid glass rim).
  static const dockTopSpecular = 0.28;

  /// Selection pill — bright white capsule (classic liquid glass dock).
  static Color dockSelectionFill(Color brand, {required bool isDark}) =>
      Colors.white.withValues(alpha: isDark ? 0.88 : 0.92);

  static Color dockSelectionBorder(Color brand, {required bool isDark}) =>
      Colors.white.withValues(alpha: isDark ? 0.35 : 0.45);
}
