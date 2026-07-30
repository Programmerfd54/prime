import 'package:flutter/cupertino.dart';

import '../typography.dart';
import 'prime_colors.dart';

/// Manrope-backed [CupertinoThemeData] aligned with [PrimeTheme] (TZ §4.1).
abstract final class PrimeCupertinoTheme {
  static CupertinoThemeData fromColors(PrimeColors c) {
    final base = TextStyle(
      fontFamily: AppTypography.family,
      fontFamilyFallback: AppTypography.fallback,
      color: c.ink,
    );

    return CupertinoThemeData(
      brightness: c.brightness,
      primaryColor: c.brand,
      scaffoldBackgroundColor: c.canvas,
      barBackgroundColor: c.surface.withValues(alpha: 0.92),
      textTheme: CupertinoTextThemeData(
        textStyle: base.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.45,
        ),
        actionTextStyle: base.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: c.brandSoft,
        ),
        navTitleTextStyle: base.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        navLargeTitleTextStyle: base.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        tabLabelTextStyle: base.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        pickerTextStyle: base.copyWith(fontSize: 16),
        dateTimePickerTextStyle: base.copyWith(fontSize: 16),
      ),
      primaryContrastingColor: c.inkOnBrand,
    );
  }
}
