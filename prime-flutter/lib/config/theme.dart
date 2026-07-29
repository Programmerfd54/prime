import 'package:flutter/material.dart';

import '../design/theme/prime_theme.dart';
import '../design/tokens.dart';

/// Legacy facade — prefer [PrimeTheme.dark] / [PrimeTheme.light].
class AppTheme {
  static Color get primary => AppColors.background;
  static Color get accent => AppColors.primaryDeep;
  static Color get neon => AppColors.primary;
  static Color get background => AppColors.background;
  static Color get surface => AppColors.surface;
  static Color get surfaceHigh => AppColors.elevatedSurface;
  static Color get muted => AppColors.textSecondary;
  static Color get border => AppColors.border;

  static LinearGradient get primaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primary, AppColors.primaryDeep],
      );

  static ThemeData get dark => PrimeTheme.dark();

  static ThemeData get light => PrimeTheme.light();
}
