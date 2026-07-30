import 'package:flutter/material.dart';

import 'theme/prime_colors.dart';
import 'theme/prime_palette.dart';

/// Binds [AppColors] getters to the active [Brightness].
///
/// Updated from [MaterialApp.builder] so legacy `AppColors.*` call sites
/// follow light/dark without a full rewrite. Prefer `context.prime` for new code.
abstract final class ThemeBinding {
  static Brightness _brightness = Brightness.dark;

  static Brightness get brightness => _brightness;

  static void bind(Brightness brightness) {
    _brightness = brightness;
  }

  static PrimeColors get colors =>
      _brightness == Brightness.dark ? PrimeColors.dark() : PrimeColors.light();
}

/// Semantic design tokens. Prefer `context.prime` over these getters.
///
/// Values resolve from [ThemeBinding] so light/dark both work during migration.
abstract final class AppColors {
  static PrimeColors get _c => ThemeBinding.colors;
  static bool get _dark => ThemeBinding.brightness == Brightness.dark;

  // Background levels
  static Color get background => _c.canvas;
  static Color get backgroundElevated => _c.canvasSubtle;
  static Color get surface => _c.surface;
  static Color get surfaceSoft => _c.surfaceSoft;
  static Color get elevatedSurface => _c.surfaceElevated;
  static Color get deepSurface => _c.deepSurface;
  static Color get selectedSurface => _c.surfaceSelected;
  static Color get accentSurface => _c.accentSurface;
  static Color get heroSurfaceStart => _c.heroGradientStart;
  static Color get heroSurfaceEnd => _c.heroGradientEnd;

  // Brand purple
  static Color get primary => _c.brand;
  static Color get primaryBright => _c.brandBright;
  static Color get primaryDeep => _c.brandStrong;
  static Color get primarySoft => _c.brandSoft;
  static Color get primaryContainer => _c.brandContainer;
  static Color get lavender => _c.lavender;
  static Color get mutedViolet => PrimePalette.mutedViolet;
  static Color get purpleGrey => PrimePalette.purpleGrey;
  static Color get softLilac => PrimePalette.softLilac;
  static Color get premiumDarkViolet => _c.premiumDarkViolet;

  // Habit illustration accents
  static Color get skillGradientStart =>
      _dark ? const Color(0xFF1A1524) : PrimePalette.mist;
  static Color get skillGradientEnd =>
      _dark ? const Color(0xFF121018) : PrimePalette.softLilac;
  static Color get habitSleep => PrimePalette.habitSleep;
  static Color get habitCharge => PrimePalette.habitCharge;
  static Color get habitRead => PrimePalette.habitRead;
  static Color get habitFocus => PrimePalette.habitFocus;
  static Color get habitSocial => PrimePalette.habitSocial;
  static Color get habitDetox => PrimePalette.habitDetox;

  // Text
  static Color get textPrimary => _c.ink;
  static Color get textSecondary => _c.inkSecondary;
  static Color get textMuted => _c.inkMuted;
  static Color get textOnPrimary => _c.inkOnBrand;

  // Borders
  static Color get border => _c.hairline;
  static Color get borderStrong => _c.hairlineStrong;

  // Supporting accents
  static Color get mint => _c.mint;
  static Color get focusBlue => _c.focusBlue;
  static Color get achievementAmber => _c.achievementAmber;
  static Color get coral => _c.coral;

  // Semantic
  static Color get success => _c.success;
  static Color get warning => _c.warning;
  static Color get warningStrong =>
      _dark ? const Color(0xFFFF8A00) : const Color(0xFFE8910F);
  static Color get warningSoft =>
      _dark ? const Color(0xFFFFB24C) : const Color(0xFFF0C36A);
  static Color get warningDim => _c.warningContainer;
  static Color get error => _c.error;
  static Color get disabled => _c.disabled;
  static Color get information => _c.info;

  // Rare achievement gold
  static Color get gold => _c.gold;
  static Color get goldBright => PrimePalette.goldBright;
  static Color get goldDeep => PrimePalette.goldDeep;
  static Color get goldSoft => const Color(0xFFD4B24A);
  static Color get goldAccent => const Color(0xFFD4B24A);
  static Color get goldGlow => PrimePalette.gold;
  static Color get goldHighlight => const Color(0xFFF5E6A8);
  static Color get goldGradientA =>
      _dark ? const Color(0xFF171006) : const Color(0xFFFBF5E6);
  static Color get goldGradientB =>
      _dark ? const Color(0xFF2E220C) : const Color(0xFFF5E6A8);
  static Color get goldGradientC =>
      _dark ? const Color(0xFF4A3810) : const Color(0xFFE4C56A);
  static Color get goldGradientD =>
      _dark ? const Color(0xFF1F1608) : const Color(0xFFF0D78A);

  // Legacy light-island tokens (now map to light surfaces)
  static Color get surfaceLight => PrimePalette.lightSurface;
  static Color get surfaceLightWarm => PrimePalette.lightSurfaceSoft;
  static Color get textOnLight => PrimePalette.lightInk;
  static Color get textOnLightMuted => PrimePalette.lightInkSecondary;
  static Color get borderOnLight => PrimePalette.lightHairline;

  // Chat
  static Color get bubbleOutbound => _c.bubbleOutbound;
  static Color get bubbleInbound => _c.bubbleInbound;
}

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const mdPlus = 20.0;
  static const lg = 24.0;
  static const sectionSm = 28.0;
  static const xl = 32.0;
  static const sectionMd = 36.0;
  static const sectionLg = 40.0;
  static const xxl = 48.0;
  static const bottomNavClearance = 96.0;
}

abstract final class AppRadius {
  static const sm = 12.0;
  /// V6 default button / field corner (§7.1, §7.3).
  static const button = 14.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const hero = 28.0;
  static const sheet = 32.0;
  static const pill = 999.0;
  static const bentoOuter = 28.0;
  static const bentoInner = 14.0;
}

abstract final class AppControlHeights {
  static const button = 52.0;
  static const buttonCompact = 40.0;
  static const field = 52.0;
  static const iconButton = 48.0;
  static const bottomNav = 68.0;
}

abstract final class AppDurations {
  static const press = Duration(milliseconds: 100);
  static const fast = Duration(milliseconds: 180);
  static const micro = Duration(milliseconds: 200);
  static const normal = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 340);
  static const zero = Duration.zero;
}

abstract final class AppBreakpoints {
  static const compact = 390.0;
  static const phoneShell = 700.0;
  static const maxContentWidth = 520.0;
  static const tablet = 840.0;
}

abstract final class AppIconSizes {
  static const xs = 16.0;
  static const sm = 20.0;
  static const md = 24.0;
  static const lg = 28.0;
  static const xl = 32.0;
}

/// Depth via surface levels; shadows are rare and soft.
abstract final class AppElevation {
  static const List<BoxShadow> none = [];

  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> lifted = [
    BoxShadow(
      color: Color(0x29000000),
      blurRadius: 28,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
}

/// Theme-aware ambient elevation.
abstract final class PrimeElevation {
  static List<BoxShadow> soft(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const [
        BoxShadow(
          color: Color(0x40000000),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ];
    }
    return const [
      BoxShadow(
        color: Color(0x14000000),
        blurRadius: 16,
        offset: Offset(0, 6),
      ),
      BoxShadow(
        color: Color(0x0A000000),
        blurRadius: 4,
        offset: Offset(0, 1),
      ),
    ];
  }

  static List<BoxShadow> lifted(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return AppElevation.lifted;
    }
    return const [
      BoxShadow(
        color: Color(0x1A000000),
        blurRadius: 24,
        offset: Offset(0, 10),
      ),
      BoxShadow(
        color: Color(0x0D000000),
        blurRadius: 6,
        offset: Offset(0, 2),
      ),
    ];
  }
}

/// Emissive colored glows — replace harsh drop shadows on neon accents.
abstract final class AppGlow {
  static List<BoxShadow> violet({double opacity = 0.25}) => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: opacity),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> magenta({double opacity = 0.22}) => [
        BoxShadow(
          color: const Color(0xFFD946EF).withValues(alpha: opacity),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> mint({double opacity = 0.35}) => [
        BoxShadow(
          color: AppColors.mint.withValues(alpha: opacity),
          blurRadius: 16,
          offset: Offset.zero,
        ),
      ];

  static List<BoxShadow> softDock() => [
        BoxShadow(
          color: AppColors.premiumDarkViolet.withValues(alpha: 0.35),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.12),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}
