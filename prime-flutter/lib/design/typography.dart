import 'dart:ui';

import 'package:flutter/material.dart';

/// PRIME type scale — Manrope only (V2 TZ §4).
abstract final class AppTypography {
  static const String family = 'Manrope';
  static const List<String> fallback = ['sans-serif'];

  static const TextStyle displayHero = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    height: 1.08,
    fontSize: 48,
  );

  static const TextStyle display = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.14,
    fontSize: 34,
  );

  static const TextStyle displaySerif = display;

  static const TextStyle heroSerif = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.12,
    fontSize: 40,
  );

  static const TextStyle titleSerif = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.22,
    fontSize: 22,
  );

  static const TextStyle serifItalic = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    height: 1.2,
    fontSize: 22,
  );

  static const TextStyle largeTitle = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.18,
    fontSize: 28,
  );

  static const TextStyle titleXL = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.2,
    fontSize: 24,
  );

  static const TextStyle title1 = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.25,
    fontSize: 20,
  );

  static const TextStyle title2 = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.3,
    fontSize: 17,
  );

  /// V5 unified scale — single source for Kit + Profile forwarders.
  static const TextStyle pageTitle = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.12,
    fontSize: 32,
  );

  static const TextStyle sectionTitle = titleSerif;

  static const TextStyle cardTitle = title2;

  static const TextStyle listTitle = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 1.25,
  );

  static const TextStyle listSubtitle = bodySecondary;

  static const TextStyle chip = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    height: 1.2,
  );

  static const TextStyle metricMedium = numericSm;

  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w400,
    fontSize: 15,
    height: 1.45,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.45,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    height: 1.3,
  );

  static const TextStyle button = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 1.2,
  );

  static const TextStyle numeric = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w600,
    fontSize: 32,
    height: 1.1,
    letterSpacing: -0.4,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle numericSm = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w600,
    fontSize: 20,
    height: 1.15,
    letterSpacing: -0.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle metricLarge = numeric;
  static const TextStyle metricCompact = numericSm;

  static const TextStyle headline = largeTitle;
  static const TextStyle title = title2;
  static const TextStyle bodyMuted = bodySecondary;
  static const TextStyle label = caption;

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
