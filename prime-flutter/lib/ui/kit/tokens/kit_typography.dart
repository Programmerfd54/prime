import 'package:flutter/material.dart';

import '../../../design/typography.dart';

/// Kit UI type scale — forwards to [AppTypography] (V5 unified).
abstract final class KitTypography {
  static const String family = AppTypography.family;
  static const List<String> fallback = AppTypography.fallback;

  static const TextStyle pageTitle = AppTypography.pageTitle;
  static const TextStyle sectionTitle = AppTypography.sectionTitle;
  static const TextStyle cardTitle = AppTypography.cardTitle;
  static const TextStyle body = AppTypography.body;
  static const TextStyle bodyMuted = AppTypography.bodySecondary;
  static const TextStyle bodySecondary = AppTypography.bodySecondary;
  static const TextStyle chip = AppTypography.chip;
  static const TextStyle caption = AppTypography.caption;
  static const TextStyle metric = AppTypography.numericSm;
  static const TextStyle metricLarge = AppTypography.numeric;
  static const TextStyle metricSm = AppTypography.numericSm;
  static const TextStyle metricMedium = AppTypography.metricMedium;
  static const TextStyle title2 = AppTypography.title1;
  static const TextStyle listTitle = AppTypography.listTitle;
  static const TextStyle listSubtitle = AppTypography.listSubtitle;
}
