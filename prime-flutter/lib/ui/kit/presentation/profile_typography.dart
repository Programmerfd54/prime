import 'package:flutter/material.dart';

import '../../../design/typography.dart';

/// Profile typography — forwards to [AppTypography] where aligned (V5).
abstract final class ProfileTypography {
  static const String family = AppTypography.family;
  static const List<String> fallback = AppTypography.fallback;

  static const TextStyle displayName = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w500,
    fontSize: 38,
    height: 1.08,
    letterSpacing: -0.4,
  );

  static const TextStyle subtitle = AppTypography.body;
  static const TextStyle bio = AppTypography.body;
  static const TextStyle sectionTitle = AppTypography.titleXL;
  static const TextStyle cardTitle = AppTypography.title1;
  static const TextStyle metricValue = AppTypography.numericSm;
  static const TextStyle metricLabel = AppTypography.caption;
  static const TextStyle secondary = AppTypography.bodySecondary;
  static const TextStyle tag = AppTypography.caption;
  static const TextStyle cta = AppTypography.button;
}
