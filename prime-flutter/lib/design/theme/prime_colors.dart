import 'package:flutter/material.dart';

import 'prime_palette.dart';

/// Semantic color roles for PRIME. Resolved from [ThemeData.extensions].
///
/// Access via `context.prime` ([PrimeThemeContext]).
@immutable
class PrimeColors extends ThemeExtension<PrimeColors> {
  const PrimeColors({
    required this.brightness,
    required this.canvas,
    required this.canvasSubtle,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceSoft,
    required this.surfaceSelected,
    required this.brandWash,
    required this.deepSurface,
    required this.hairline,
    required this.hairlineStrong,
    required this.ink,
    required this.inkSecondary,
    required this.inkMuted,
    required this.inkOnBrand,
    required this.brand,
    required this.brandStrong,
    required this.brandSoft,
    required this.brandBright,
    required this.brandContainer,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.disabled,
    required this.glassTint,
    required this.glassBorder,
    required this.glassHighlight,
    required this.heroGradientStart,
    required this.heroGradientEnd,
    required this.bubbleOutbound,
    required this.bubbleInbound,
    required this.mint,
    required this.focusBlue,
    required this.achievementAmber,
    required this.coral,
    required this.gold,
    required this.lavender,
    required this.premiumDarkViolet,
    required this.accentSurface,
  });

  final Brightness brightness;

  final Color canvas;
  final Color canvasSubtle;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceSoft;
  final Color surfaceSelected;
  final Color brandWash;
  final Color deepSurface;

  final Color hairline;
  final Color hairlineStrong;

  final Color ink;
  final Color inkSecondary;
  final Color inkMuted;
  final Color inkOnBrand;

  final Color brand;
  final Color brandStrong;
  final Color brandSoft;
  final Color brandBright;
  final Color brandContainer;

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color info;
  final Color onInfo;
  final Color infoContainer;

  final Color disabled;

  final Color glassTint;
  final Color glassBorder;
  final Color glassHighlight;

  final Color heroGradientStart;
  final Color heroGradientEnd;

  final Color bubbleOutbound;
  final Color bubbleInbound;

  final Color mint;
  final Color focusBlue;
  final Color achievementAmber;
  final Color coral;
  final Color gold;
  final Color lavender;
  final Color premiumDarkViolet;
  final Color accentSurface;

  bool get isDark => brightness == Brightness.dark;

  // ── AppColors-compatible aliases (migration helpers) ─────────────────────
  Color get background => canvas;
  Color get backgroundElevated => canvasSubtle;
  Color get elevatedSurface => surfaceElevated;
  Color get selectedSurface => surfaceSelected;
  Color get primary => brand;
  Color get primaryBright => brandBright;
  Color get primaryDeep => brandStrong;
  Color get primarySoft => brandSoft;
  Color get primaryContainer => brandContainer;
  Color get textPrimary => ink;
  Color get textSecondary => inkSecondary;
  Color get textMuted => inkMuted;
  Color get textOnPrimary => inkOnBrand;
  Color get border => hairline;
  Color get borderStrong => hairlineStrong;
  Color get information => info;
  Color get heroSurfaceStart => heroGradientStart;
  Color get heroSurfaceEnd => heroGradientEnd;

  LinearGradient get heroGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [heroGradientStart, heroGradientEnd],
      );

  LinearGradient get brandGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [PrimePalette.brand, PrimePalette.brandDeep],
      );

  /// Dark theme — refined existing PRIME dark palette.
  factory PrimeColors.dark() => const PrimeColors(
        brightness: Brightness.dark,
        canvas: PrimePalette.darkCanvas,
        canvasSubtle: PrimePalette.darkCanvasSubtle,
        surface: PrimePalette.darkSurface,
        surfaceElevated: PrimePalette.darkSurfaceElevated,
        surfaceSoft: PrimePalette.darkSurfaceSoft,
        surfaceSelected: PrimePalette.darkSurfaceSelected,
        brandWash: Color(0xFF332548),
        deepSurface: PrimePalette.darkDeep,
        hairline: PrimePalette.darkHairline,
        hairlineStrong: PrimePalette.darkHairlineStrong,
        ink: PrimePalette.darkInk,
        inkSecondary: PrimePalette.darkInkSecondary,
        inkMuted: PrimePalette.darkInkMuted,
        inkOnBrand: PrimePalette.inkOnBrand,
        brand: PrimePalette.brand,
        brandStrong: PrimePalette.brandDeep,
        brandSoft: PrimePalette.brandSoft,
        brandBright: PrimePalette.brandBright,
        brandContainer: PrimePalette.brandContainerDark,
        success: PrimePalette.success,
        onSuccess: PrimePalette.darkCanvas,
        successContainer: Color(0xFF1A3A30),
        warning: PrimePalette.warning,
        onWarning: PrimePalette.darkCanvas,
        warningContainer: Color(0xFF3A3218),
        error: PrimePalette.error,
        onError: PrimePalette.inkOnBrand,
        errorContainer: Color(0xFF3A1A22),
        info: PrimePalette.info,
        onInfo: PrimePalette.darkCanvas,
        infoContainer: Color(0xFF1A2A3A),
        disabled: PrimePalette.disabled,
        glassTint: Color(0x44351F66),
        glassBorder: Color(0x45FFFFFF),
        glassHighlight: Color(0x32FFFFFF),
        heroGradientStart: PrimePalette.darkHeroStart,
        heroGradientEnd: PrimePalette.darkHeroEnd,
        bubbleOutbound: PrimePalette.darkBubbleOut,
        bubbleInbound: PrimePalette.darkBubbleIn,
        mint: PrimePalette.mint,
        focusBlue: PrimePalette.focusBlue,
        achievementAmber: PrimePalette.achievementAmber,
        coral: PrimePalette.coral,
        gold: PrimePalette.gold,
        lavender: PrimePalette.lavender,
        premiumDarkViolet: PrimePalette.premiumDarkViolet,
        accentSurface: Color(0xFF332548),
      );

  /// Light theme — designed independently (warm canvas, true white surfaces).
  factory PrimeColors.light() => const PrimeColors(
        brightness: Brightness.light,
        canvas: PrimePalette.lightCanvas,
        canvasSubtle: PrimePalette.lightCanvasSubtle,
        surface: PrimePalette.lightSurface,
        surfaceElevated: PrimePalette.lightSurfaceElevated,
        surfaceSoft: PrimePalette.lightSurfaceSoft,
        surfaceSelected: PrimePalette.lightSurfaceSelected,
        brandWash: PrimePalette.mist,
        deepSurface: PrimePalette.lightCanvasSubtle,
        hairline: PrimePalette.lightHairline,
        hairlineStrong: PrimePalette.lightHairlineStrong,
        ink: PrimePalette.lightInk,
        inkSecondary: PrimePalette.lightInkSecondary,
        inkMuted: PrimePalette.lightInkMuted,
        inkOnBrand: PrimePalette.inkOnBrand,
        brand: PrimePalette.brand,
        brandStrong: PrimePalette.brandDeep,
        brandSoft: PrimePalette.brandDeep,
        brandBright: PrimePalette.brandBright,
        brandContainer: PrimePalette.brandContainerLight,
        success: PrimePalette.successMuted,
        onSuccess: Color(0xFFFFFFFF),
        successContainer: Color(0xFFE4F5EE),
        warning: PrimePalette.warningMuted,
        onWarning: PrimePalette.lightInk,
        warningContainer: Color(0xFFFBF3E0),
        error: PrimePalette.errorMuted,
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFCE8EA),
        info: PrimePalette.infoMuted,
        onInfo: Color(0xFFFFFFFF),
        infoContainer: Color(0xFFE8F0FC),
        disabled: PrimePalette.disabled,
        glassTint: Color(0xCCFFFFFF),
        glassBorder: Color(0x29FFFFFF),
        glassHighlight: Color(0x66FFFFFF),
        heroGradientStart: PrimePalette.mist,
        heroGradientEnd: PrimePalette.softLilac,
        bubbleOutbound: PrimePalette.lightBubbleOut,
        bubbleInbound: PrimePalette.lightBubbleIn,
        mint: PrimePalette.mint,
        focusBlue: PrimePalette.focusBlue,
        achievementAmber: PrimePalette.achievementAmber,
        coral: PrimePalette.coral,
        gold: PrimePalette.goldDeep,
        lavender: PrimePalette.lavender,
        premiumDarkViolet: PrimePalette.premiumDarkViolet,
        accentSurface: PrimePalette.mist,
      );

  @override
  PrimeColors copyWith({
    Brightness? brightness,
    Color? canvas,
    Color? canvasSubtle,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceSoft,
    Color? surfaceSelected,
    Color? brandWash,
    Color? deepSurface,
    Color? hairline,
    Color? hairlineStrong,
    Color? ink,
    Color? inkSecondary,
    Color? inkMuted,
    Color? inkOnBrand,
    Color? brand,
    Color? brandStrong,
    Color? brandSoft,
    Color? brandBright,
    Color? brandContainer,
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? error,
    Color? onError,
    Color? errorContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? disabled,
    Color? glassTint,
    Color? glassBorder,
    Color? glassHighlight,
    Color? heroGradientStart,
    Color? heroGradientEnd,
    Color? bubbleOutbound,
    Color? bubbleInbound,
    Color? mint,
    Color? focusBlue,
    Color? achievementAmber,
    Color? coral,
    Color? gold,
    Color? lavender,
    Color? premiumDarkViolet,
    Color? accentSurface,
  }) {
    return PrimeColors(
      brightness: brightness ?? this.brightness,
      canvas: canvas ?? this.canvas,
      canvasSubtle: canvasSubtle ?? this.canvasSubtle,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      surfaceSelected: surfaceSelected ?? this.surfaceSelected,
      brandWash: brandWash ?? this.brandWash,
      deepSurface: deepSurface ?? this.deepSurface,
      hairline: hairline ?? this.hairline,
      hairlineStrong: hairlineStrong ?? this.hairlineStrong,
      ink: ink ?? this.ink,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkMuted: inkMuted ?? this.inkMuted,
      inkOnBrand: inkOnBrand ?? this.inkOnBrand,
      brand: brand ?? this.brand,
      brandStrong: brandStrong ?? this.brandStrong,
      brandSoft: brandSoft ?? this.brandSoft,
      brandBright: brandBright ?? this.brandBright,
      brandContainer: brandContainer ?? this.brandContainer,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      errorContainer: errorContainer ?? this.errorContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      disabled: disabled ?? this.disabled,
      glassTint: glassTint ?? this.glassTint,
      glassBorder: glassBorder ?? this.glassBorder,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      heroGradientStart: heroGradientStart ?? this.heroGradientStart,
      heroGradientEnd: heroGradientEnd ?? this.heroGradientEnd,
      bubbleOutbound: bubbleOutbound ?? this.bubbleOutbound,
      bubbleInbound: bubbleInbound ?? this.bubbleInbound,
      mint: mint ?? this.mint,
      focusBlue: focusBlue ?? this.focusBlue,
      achievementAmber: achievementAmber ?? this.achievementAmber,
      coral: coral ?? this.coral,
      gold: gold ?? this.gold,
      lavender: lavender ?? this.lavender,
      premiumDarkViolet: premiumDarkViolet ?? this.premiumDarkViolet,
      accentSurface: accentSurface ?? this.accentSurface,
    );
  }

  @override
  PrimeColors lerp(ThemeExtension<PrimeColors>? other, double t) {
    if (other is! PrimeColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return PrimeColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      canvas: l(canvas, other.canvas),
      canvasSubtle: l(canvasSubtle, other.canvasSubtle),
      surface: l(surface, other.surface),
      surfaceElevated: l(surfaceElevated, other.surfaceElevated),
      surfaceSoft: l(surfaceSoft, other.surfaceSoft),
      surfaceSelected: l(surfaceSelected, other.surfaceSelected),
      brandWash: l(brandWash, other.brandWash),
      deepSurface: l(deepSurface, other.deepSurface),
      hairline: l(hairline, other.hairline),
      hairlineStrong: l(hairlineStrong, other.hairlineStrong),
      ink: l(ink, other.ink),
      inkSecondary: l(inkSecondary, other.inkSecondary),
      inkMuted: l(inkMuted, other.inkMuted),
      inkOnBrand: l(inkOnBrand, other.inkOnBrand),
      brand: l(brand, other.brand),
      brandStrong: l(brandStrong, other.brandStrong),
      brandSoft: l(brandSoft, other.brandSoft),
      brandBright: l(brandBright, other.brandBright),
      brandContainer: l(brandContainer, other.brandContainer),
      success: l(success, other.success),
      onSuccess: l(onSuccess, other.onSuccess),
      successContainer: l(successContainer, other.successContainer),
      warning: l(warning, other.warning),
      onWarning: l(onWarning, other.onWarning),
      warningContainer: l(warningContainer, other.warningContainer),
      error: l(error, other.error),
      onError: l(onError, other.onError),
      errorContainer: l(errorContainer, other.errorContainer),
      info: l(info, other.info),
      onInfo: l(onInfo, other.onInfo),
      infoContainer: l(infoContainer, other.infoContainer),
      disabled: l(disabled, other.disabled),
      glassTint: l(glassTint, other.glassTint),
      glassBorder: l(glassBorder, other.glassBorder),
      glassHighlight: l(glassHighlight, other.glassHighlight),
      heroGradientStart: l(heroGradientStart, other.heroGradientStart),
      heroGradientEnd: l(heroGradientEnd, other.heroGradientEnd),
      bubbleOutbound: l(bubbleOutbound, other.bubbleOutbound),
      bubbleInbound: l(bubbleInbound, other.bubbleInbound),
      mint: l(mint, other.mint),
      focusBlue: l(focusBlue, other.focusBlue),
      achievementAmber: l(achievementAmber, other.achievementAmber),
      coral: l(coral, other.coral),
      gold: l(gold, other.gold),
      lavender: l(lavender, other.lavender),
      premiumDarkViolet: l(premiumDarkViolet, other.premiumDarkViolet),
      accentSurface: l(accentSurface, other.accentSurface),
    );
  }
}
