import 'package:flutter/material.dart';

/// Poppins-only typography for participant profile screens (TZ §4).
abstract final class ProfileTypography {
  static const String family = 'Poppins';
  static const List<String> fallback = ['sans-serif'];

  static const TextStyle displayName = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w400,
    fontSize: 38,
    height: 1.08,
    letterSpacing: -0.4,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 1.3,
  );

  static const TextStyle bio = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w400,
    fontSize: 15,
    height: 1.45,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w500,
    fontSize: 24,
    height: 1.2,
    letterSpacing: -0.2,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w500,
    fontSize: 18,
    height: 1.25,
  );

  static const TextStyle metricValue = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle metricLabel = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 1.2,
  );

  static const TextStyle secondary = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 1.35,
  );

  static const TextStyle tag = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    height: 1.2,
  );

  static const TextStyle cta = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w500,
    fontSize: 16,
    height: 1.2,
  );
}
