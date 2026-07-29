import 'package:flutter/material.dart';

import '../../../design/theme/prime_palette.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';

/// Surface ladder — each level has a distinct visual job.
enum PrimeSurfaceLevel {
  /// Screen background — no container.
  canvas,

  /// Text/block on canvas — no card chrome.
  flat,

  /// Standard elevated card — solid fill, hairline only.
  solid,

  /// Photography-led card.
  image,

  /// Brand-tinted highlight card.
  accent,

  /// Frosted overlay for nav / hero controls only.
  glass,

  /// Modal / sheet surface.
  modal,
}

/// Semantic accent slots for charts, chips, and series colours.
enum KitAccent {
  brand,
  mint,
  coral,
  amber,
  blue,
  cream,
  neutral,
}

extension KitAccentColor on KitAccent {
  Color resolve(BuildContext context) {
    final p = context.prime;
    return switch (this) {
      KitAccent.brand => p.brand,
      KitAccent.mint => p.mint,
      KitAccent.coral => p.coral,
      KitAccent.amber => p.achievementAmber,
      KitAccent.blue => p.focusBlue,
      KitAccent.cream => PrimePalette.mist,
      KitAccent.neutral => p.inkSecondary,
    };
  }
}

/// Builds decoration for a [PrimeSurfaceLevel].
BoxDecoration kitSurfaceDecoration(
  BuildContext context,
  PrimeSurfaceLevel level, {
  double radius = AppRadius.lg,
  KitAccent accent = KitAccent.brand,
  BorderRadius? borderRadius,
}) {
  final p = context.prime;
  final r = borderRadius ?? BorderRadius.circular(radius);
  return switch (level) {
    PrimeSurfaceLevel.canvas || PrimeSurfaceLevel.flat => const BoxDecoration(),
    PrimeSurfaceLevel.solid => BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: r,
        border: Border.all(color: p.hairline, width: 0.5),
      ),
    PrimeSurfaceLevel.image => BoxDecoration(
        color: p.surface,
        borderRadius: r,
      ),
    PrimeSurfaceLevel.accent => BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.resolve(context).withValues(alpha: 0.22),
            p.surfaceElevated,
          ],
        ),
        border: Border.all(
          color: accent.resolve(context).withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
    PrimeSurfaceLevel.glass => BoxDecoration(
        color: p.glassTint.withValues(alpha: 0.72),
        borderRadius: r,
        border: Border.all(color: p.glassBorder, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    PrimeSurfaceLevel.modal => BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
  };
}
