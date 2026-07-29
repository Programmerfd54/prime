import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';
import '../typography.dart';
import 'prime_colors.dart';

/// Builds [ThemeData] for PRIME from [PrimeColors].
///
/// Prefer [PrimeTheme.dark] / [PrimeTheme.light] over legacy [AppTheme].
abstract final class PrimeTheme {
  static ThemeData dark() => _build(PrimeColors.dark());

  static ThemeData light() => _build(PrimeColors.light());

  static ThemeData _build(PrimeColors c) {
    final isDark = c.isDark;
    final colorScheme = ColorScheme(
      brightness: c.brightness,
      primary: c.brand,
      onPrimary: c.inkOnBrand,
      secondary: c.brandSoft,
      onSecondary: isDark ? c.canvas : c.inkOnBrand,
      surface: c.surface,
      onSurface: c.ink,
      error: c.error,
      onError: c.onError,
      outline: c.hairline,
      surfaceContainerHighest: c.surfaceElevated,
    );

    final textTheme = AppTypography.textTheme(
      ink: c.ink,
      inkSecondary: c.inkSecondary,
      inkMuted: c.inkMuted,
      inkOnBrand: c.inkOnBrand,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.canvas,
      dividerColor: c.hairline,
      splashFactory: InkSparkle.splashFactory,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.canvas,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: AppTypography.title2.copyWith(color: c.ink),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: c.hairline),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.inkOnBrand,
          disabledBackgroundColor: c.disabled.withValues(alpha: 0.35),
          disabledForegroundColor: c.inkMuted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.lg,
          ),
          minimumSize: const Size.fromHeight(AppControlHeights.button),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.button.copyWith(color: c.inkOnBrand),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          backgroundColor: c.surfaceElevated,
          side: BorderSide(color: c.hairlineStrong),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          minimumSize: const Size.fromHeight(AppControlHeights.button),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.button.copyWith(color: c.ink),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.brandSoft,
          textStyle: AppTypography.button.copyWith(
            color: c.brandSoft,
            fontSize: 15,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceElevated,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: c.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: c.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: c.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: c.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: c.error, width: 1.5),
        ),
        labelStyle: AppTypography.bodySecondary.copyWith(color: c.inkSecondary),
        floatingLabelStyle: AppTypography.caption.copyWith(
          color: c.brandSoft,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: AppTypography.bodySecondary.copyWith(color: c.inkMuted),
        helperStyle: AppTypography.caption.copyWith(color: c.inkMuted),
        errorStyle: AppTypography.caption.copyWith(color: c.error),
        errorMaxLines: 2,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: c.brand,
        unselectedItemColor: c.inkMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppControlHeights.bottomNav,
        backgroundColor: c.surface,
        indicatorColor: c.brandContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTypography.caption.copyWith(
            color: selected ? c.brandSoft : c.inkMuted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: AppIconSizes.md,
            color: selected ? c.brand : c.inkMuted,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceElevated,
        contentTextStyle: AppTypography.body.copyWith(color: c.ink),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: c.hairline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: AppTypography.title1.copyWith(color: c.ink),
        contentTextStyle:
            AppTypography.bodySecondary.copyWith(color: c.inkSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: c.inkMuted,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.brand,
        linearTrackColor: c.brandContainer,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.brand;
          return Colors.transparent;
        }),
        side: BorderSide(color: c.hairlineStrong, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceSoft,
        selectedColor: c.brandContainer,
        labelStyle: AppTypography.caption.copyWith(color: c.ink),
        side: BorderSide(color: c.hairline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }
}
