import 'package:flutter/material.dart';

/// All-sans working UI type scale for the visual reset kit.
///
/// Serif is intentionally excluded — use only for rare editorial heroes
/// outside this namespace.
abstract final class KitTypography {
  static const String _ui = 'Poppins';
  static const String _uiFallback = 'Poppins';
  static const String _numeric = 'Unbounded';
  static const List<String> _fallback = [_uiFallback, 'sans-serif'];

  static const TextStyle pageTitle = TextStyle(
    fontFamily: _ui,
    fontFamilyFallback: _fallback,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.12,
    fontSize: 32,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: _ui,
    fontFamilyFallback: _fallback,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.2,
    fontSize: 22,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: _ui,
    fontFamilyFallback: _fallback,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
    height: 1.25,
    fontSize: 18,
  );

  static const TextStyle title2 = TextStyle(
    fontFamily: _ui,
    fontFamilyFallback: _fallback,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.3,
    fontSize: 17,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _ui,
    fontFamilyFallback: _fallback,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 1.45,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontFamily: _ui,
    fontFamilyFallback: _fallback,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.45,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _ui,
    fontFamilyFallback: _fallback,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    height: 1.35,
    letterSpacing: 0.1,
  );

  static const TextStyle metricLarge = TextStyle(
    fontFamily: _numeric,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.8,
    height: 1.05,
    fontSize: 36,
  );

  static const TextStyle metricMedium = TextStyle(
    fontFamily: _numeric,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.1,
    fontSize: 28,
  );

  static const TextStyle chip = TextStyle(
    fontFamily: _ui,
    fontFamilyFallback: _fallback,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    height: 1.2,
  );

  static const TextStyle navLabel = TextStyle(
    fontFamily: _ui,
    fontFamilyFallback: _fallback,
    fontWeight: FontWeight.w600,
    fontSize: 11,
    height: 1.1,
    letterSpacing: 0.2,
  );
}
