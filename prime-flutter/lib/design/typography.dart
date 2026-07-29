import 'dart:ui';

import 'package:flutter/material.dart';

/// PRIME Liquid type scale.
///
/// - **Playfair Display** — editorial serif headlines (roman + italic accents)
/// - **Manrope** — UI body, captions, buttons
/// - **Unbounded** — tabular numeric metrics only
///
/// Styles are **colorless** so ink resolves from [TextTheme] / [DefaultTextStyle]
/// and adapts to light/dark via [PrimeTheme]. Use `.copyWith(color: …)` for
/// on-brand / on-glass / explicit overrides.
abstract final class AppTypography {
  static const String _ui = 'Poppins';
  static const String _uiLegacy = 'Manrope';
  static const String _serif = 'PlayfairDisplay';
  static const String _numeric = 'Unbounded';

  /// Fallback chain: Manrope then system sans if Poppins fails to load.
  static const List<String> _uiFallback = [_uiLegacy, 'sans-serif'];
  static const List<String> _serifFallback = [_ui, _uiLegacy];

  // ── Editorial serif ──────────────────────────────────────────────────────

  static const TextStyle displayHero = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: _serifFallback,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
    height: 1.08,
    fontSize: 48,
  );

  static const TextStyle display = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: _serifFallback,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.14,
    fontSize: 34,
  );

  static const TextStyle displaySerif = display;

  static const TextStyle heroSerif = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: _serifFallback,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.8,
    height: 1.12,
    fontSize: 40,
  );

  static const TextStyle titleSerif = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: _serifFallback,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.22,
    fontSize: 22,
  );

  /// Italic accent words inside serif headlines.
  static const TextStyle serifItalic = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: _serifFallback,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    height: 1.2,
    fontSize: 22,
  );

  // ── Sans UI ──────────────────────────────────────────────────────────────

  static const TextStyle largeTitle = TextStyle(
    fontFamily: _ui,
    fontFamilyFallback: _uiFallback,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.18,
    fontSize: 28,
  );

  static const TextStyle titleXL = TextStyle(
    fontFamily: _ui,
    fontFamilyFallback: _uiFallback,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.2,
    fontSize: 24,
  );

  static const TextStyle title1 = TextStyle(
    fontFamily: _ui,
    fontFamilyFallback: _uiFallback,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.25,
    fontSize: 20,
  );

  static const TextStyle title2 = TextStyle(
    fontFamily: _ui,
    fontFamilyFallback: _uiFallback,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.3,
    fontSize: 17,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _ui,
    fontFamilyFallback: _uiFallback,
    fontWeight: FontWeight.w400,
    fontSize: 15,
    height: 1.45,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontFamily: _ui,
    fontFamilyFallback: _uiFallback,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.45,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _ui,
    fontFamilyFallback: _uiFallback,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    height: 1.3,
  );

  static const TextStyle button = TextStyle(
    fontFamily: _ui,
    fontFamilyFallback: _uiFallback,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 1.2,
  );

  // ── Numeric (Unbounded only) ─────────────────────────────────────────────

  static const TextStyle numeric = TextStyle(
    fontFamily: _numeric,
    fontWeight: FontWeight.w700,
    fontSize: 32,
    height: 1.1,
    letterSpacing: -0.6,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle numericSm = TextStyle(
    fontFamily: _numeric,
    fontWeight: FontWeight.w600,
    fontSize: 20,
    height: 1.15,
    letterSpacing: -0.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Spec names for metric styles.
  static const TextStyle metricLarge = numeric;
  static const TextStyle metricCompact = numericSm;

  // Backward-compatible aliases
  static const TextStyle headline = largeTitle;
  static const TextStyle title = title2;
  static const TextStyle bodyMuted = bodySecondary;
  static const TextStyle label = caption;

  /// Parses `*italic spans*` into a [TextSpan] tree.
  ///
  /// Example: `accent('Не знаешь, *с чего* начать?', style: heroSerif)`
  static TextSpan accent(
    String source, {
    TextStyle? style,
    TextStyle? italicStyle,
  }) {
    final base = style ?? heroSerif;
    final italic = (italicStyle ?? serifItalic).copyWith(
      fontSize: base.fontSize,
      color: base.color,
      height: base.height,
      letterSpacing: base.letterSpacing,
    );

    final children = <InlineSpan>[];
    final re = RegExp(r'\*([^*]+)\*');
    var cursor = 0;
    for (final match in re.allMatches(source)) {
      if (match.start > cursor) {
        children.add(TextSpan(
          text: source.substring(cursor, match.start),
          style: base,
        ));
      }
      children.add(TextSpan(text: match.group(1), style: italic));
      cursor = match.end;
    }
    if (cursor < source.length) {
      children.add(TextSpan(text: source.substring(cursor), style: base));
    }
    if (children.isEmpty) {
      return TextSpan(text: source, style: base);
    }
    return TextSpan(style: base, children: children);
  }

  /// Convenience widget wrapping [accent].
  static Widget accentText(
    String source, {
    TextStyle? style,
    TextStyle? italicStyle,
    TextAlign textAlign = TextAlign.start,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return Text.rich(
      accent(source, style: style, italicStyle: italicStyle),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  /// Builds a [TextTheme] tinted with [ink] / [inkSecondary] / [inkMuted].
  static TextTheme textTheme({
    Color? ink,
    Color? inkSecondary,
    Color? inkMuted,
    Color? inkOnBrand,
  }) {
    TextStyle tint(TextStyle base, Color? color) =>
        color == null ? base : base.copyWith(color: color);

    return TextTheme(
      displayLarge: tint(displayHero, ink),
      displayMedium: tint(display, ink),
      displaySmall: tint(display.copyWith(fontSize: 30), ink),
      headlineLarge: tint(largeTitle, ink),
      headlineMedium: tint(titleXL, ink),
      headlineSmall: tint(title1, ink),
      titleLarge: tint(title1, ink),
      titleMedium: tint(title2, ink),
      titleSmall: tint(
        title2.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        ink,
      ),
      bodyLarge: tint(body, ink),
      bodyMedium: tint(bodySecondary, inkSecondary ?? ink),
      bodySmall: tint(caption, inkMuted ?? inkSecondary),
      labelLarge: tint(button, inkOnBrand ?? ink),
      labelMedium: tint(
        caption.copyWith(fontWeight: FontWeight.w600),
        inkMuted ?? inkSecondary,
      ),
      labelSmall: tint(
        caption.copyWith(fontSize: 11),
        inkMuted ?? inkSecondary,
      ),
    );
  }
}
