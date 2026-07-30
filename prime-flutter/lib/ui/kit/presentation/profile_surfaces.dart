import 'package:flutter/material.dart';

/// V3/V4 semantic surface tokens for profile screens.
abstract final class ProfileSurfaces {
  static const canvas = Color(0xFF0F0D14);
  static const profileShell = Color(0xFF1A1622);
  static const surfaceNeutral = Color(0xFF211C2B);
  static const surfaceElevated = Color(0xFF292331);
  static const surfaceTinted = Color(0xFF2B2140);
  static const surfaceWarm = Color(0xFF332D2A);
  static const surfaceAnalytics = Color(0xFF171719);
  static const surfaceSuccess = Color(0xFF18342E);

  /// Subtle warm accent extracted from photo — local only, not full beige panel.
  static const heroAccentWarm = Color(0xFF3D3428);

  static const outlineSoft = Color(0x14FFFFFF);
  static const outlineStrong = Color(0x24FFFFFF);

  static const photoInset = 0.0;
  static const photoRadius = 0.0;
  static const heroContentPadding = 20.0;
  static const shellRadius = 26.0;
  static const contentRadius = 20.0;

  static BoxDecoration shellDecoration({Color? fill}) => BoxDecoration(
        color: fill ?? profileShell,
        borderRadius: BorderRadius.circular(shellRadius),
        border: Border.all(color: outlineSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      );

  static BoxDecoration heroShellDecoration() => BoxDecoration(
        color: profileShell,
        borderRadius: BorderRadius.circular(shellRadius),
        border: Border.all(color: outlineSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      );

  static LinearGradient photoOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.black.withValues(alpha: 0.20),
      Colors.black.withValues(alpha: 0.10),
      Colors.black.withValues(alpha: 0.68),
    ],
    stops: const [0.0, 0.40, 1.0],
  );

  static LinearGradient photoToShellGradient(Color shell) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.08),
          shell.withValues(alpha: 0.55),
          shell,
        ],
        stops: const [0.50, 0.82, 1.0],
      );

  static BoxDecoration cardDecoration({
    required Color fill,
    double radius = contentRadius,
    Color? border,
  }) =>
      BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? outlineSoft),
      );
}

enum ProfileSurfaceKind {
  neutral,
  elevated,
  tinted,
  warm,
  analytics,
  success,
}

Color profileSurfaceColor(ProfileSurfaceKind kind) {
  switch (kind) {
    case ProfileSurfaceKind.neutral:
      return ProfileSurfaces.surfaceNeutral;
    case ProfileSurfaceKind.elevated:
      return ProfileSurfaces.surfaceElevated;
    case ProfileSurfaceKind.tinted:
      return ProfileSurfaces.surfaceTinted;
    case ProfileSurfaceKind.warm:
      return ProfileSurfaces.surfaceWarm;
    case ProfileSurfaceKind.analytics:
      return ProfileSurfaces.surfaceAnalytics;
    case ProfileSurfaceKind.success:
      return const Color(0xFF18342E);
  }
}
