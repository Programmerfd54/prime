import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../prime/prime_glass_v5.dart';
import '../shapes/prime_squircle.dart';
import '../theme/prime_theme_context.dart';
import '../tokens.dart';

/// Glass quality tier for [LiquidGlass].
///
/// - [full] — BackdropFilter blur + specular + rim light (small surfaces only)
/// - [lite] — no blur; specular + rim light + translucent fill (lists/cards)
/// - [flat] — solid translucent fill only (reduce-motion / low-end)
enum LiquidTier { full, lite, flat }

/// Visual recipe for [LiquidGlass] surfaces.
enum LiquidGlassVariant { standard, dock }

/// Preset tuned for floating navigation docks — stronger blur, tint, and rim.
abstract final class LiquidGlassDockPreset {
  static const sigma = 56.0;
  static const fillOpacityDark = PrimeGlassV5.dockFillOpacityDark;
  static const fillOpacityLight = PrimeGlassV5.dockFillOpacityLight;

  static double fillOpacityFor(BuildContext context) =>
      context.prime.isDark ? fillOpacityDark : fillOpacityLight;

  static List<BoxShadow> glow(BuildContext context) {
    final p = context.prime;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.38),
        blurRadius: 36,
        offset: const Offset(0, 14),
      ),
      BoxShadow(
        color: p.brand.withValues(alpha: 0.14),
        blurRadius: 24,
        offset: const Offset(0, 4),
      ),
    ];
  }
}

/// Floating dock shell — Liquid Glass material tuned for tab bars.
class LiquidGlassDock extends StatelessWidget {
  const LiquidGlassDock({
    super.key,
    required this.child,
    required this.radius,
    this.height,
    this.width,
    this.glow,
    this.sigma,
  });

  final Widget child;
  final double radius;
  final double? height;
  final double? width;
  final List<BoxShadow>? glow;
  final double? sigma;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      allowBlurOnWeb: true,
      forceTier: LiquidTier.full,
      padding: EdgeInsets.zero,
      radius: radius,
      height: height,
      width: width,
      sigma: sigma ?? LiquidGlassDockPreset.sigma,
      fillOpacity: LiquidGlassDockPreset.fillOpacityFor(context),
      variant: LiquidGlassVariant.dock,
      glow: glow ?? LiquidGlassDockPreset.glow(context),
      child: child,
    );
  }
}

/// Resolves the best tier for the current platform and surface size.
///
/// On web, [LiquidTier.full] is only allowed when [allowBlurOnWeb] is true
/// (docks, sheets, sticky headers). Cards and lists get [LiquidTier.lite].
///
/// Reduced-motion / disableAnimations always yields [LiquidTier.flat],
/// even when [force] is set — low-end and a11y fallback must win.
LiquidTier resolveLiquidTier(
  BuildContext context, {
  bool allowBlurOnWeb = false,
  LiquidTier? force,
}) {
  if (MediaQuery.disableAnimationsOf(context)) return LiquidTier.flat;
  if (force != null) return force;
  if (kIsWeb && !allowBlurOnWeb) return LiquidTier.lite;
  return LiquidTier.full;
}

/// Six-layer liquid glass surface — the PRIME Liquid visual language.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = AppRadius.xl,
    this.width,
    this.height,
    this.onTap,
    this.glow,
    this.sigma = 18,
    this.fillOpacity = 0.16,
    this.forceTier,
    this.allowBlurOnWeb = false,
    this.clip = true,
    this.variant = LiquidGlassVariant.standard,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final List<BoxShadow>? glow;
  final double sigma;
  final double fillOpacity;
  final LiquidTier? forceTier;
  final bool allowBlurOnWeb;
  final bool clip;
  final LiquidGlassVariant variant;

  @override
  Widget build(BuildContext context) {
    final tier = resolveLiquidTier(
      context,
      allowBlurOnWeb: allowBlurOnWeb,
      force: forceTier,
    );

    Widget surface = _LiquidLayers(
      tier: tier,
      radius: radius,
      sigma: sigma,
      fillOpacity: fillOpacity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      variant: variant,
      child: child,
    );

    if (clip) {
      surface = PrimeSquircleClip(radius: radius, child: surface);
    }

    if (glow != null && glow!.isNotEmpty) {
      surface = DecoratedBox(
        decoration: PrimeSquircleDecoration(
          radius: radius,
          boxShadow: glow,
        ),
        child: surface,
      );
    } else if (tier != LiquidTier.flat) {
      surface = DecoratedBox(
        decoration: PrimeSquircleDecoration(
          radius: radius,
          boxShadow: AppGlow.violet(opacity: 0.08),
        ),
        child: surface,
      );
    }

    if (margin != null) {
      surface = Padding(padding: margin!, child: surface);
    }

    if (width != null || height != null) {
      surface = SizedBox(width: width, height: height, child: surface);
    }

    if (onTap != null) {
      surface = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: surface,
      );
    }

    return surface;
  }
}

class _LiquidLayers extends StatelessWidget {
  const _LiquidLayers({
    required this.tier,
    required this.radius,
    required this.sigma,
    required this.fillOpacity,
    required this.padding,
    required this.variant,
    required this.child,
  });

  final LiquidTier tier;
  final double radius;
  final double sigma;
  final double fillOpacity;
  final EdgeInsetsGeometry padding;
  final LiquidGlassVariant variant;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final prime = context.prime;
    final surfaceColor = prime.surface;
    final highlight = prime.glassHighlight;
    final isDark = prime.isDark;

    final fill = switch (tier) {
      LiquidTier.full =>
        prime.surfaceElevated.withValues(alpha: isDark ? 0.55 : 0.72),
      LiquidTier.lite => surfaceColor.withValues(alpha: isDark ? 0.78 : 0.88),
      LiquidTier.flat => surfaceColor.withValues(alpha: isDark ? 0.94 : 0.96),
    };

    final liteFill = Color.alphaBlend(
      (isDark ? Colors.white : prime.brand)
          .withValues(alpha: isDark ? 0.08 : 0.04),
      surfaceColor.withValues(alpha: isDark ? 0.78 : 0.88),
    );

    final isDock = variant == LiquidGlassVariant.dock;

    final baseColor = switch ((isDock, tier)) {
      (true, LiquidTier.full) => Color.alphaBlend(
          prime.brandContainer.withValues(alpha: isDark ? 0.10 : 0.06),
          prime.surfaceElevated.withValues(alpha: isDark ? 0.58 : 0.72),
        ),
      (true, LiquidTier.lite) =>
        surfaceColor.withValues(alpha: isDark ? 0.62 : 0.78),
      (true, LiquidTier.flat) =>
        surfaceColor.withValues(alpha: isDark ? 0.86 : 0.92),
      _ => tier == LiquidTier.lite
          ? Color.alphaBlend(prime.glassTint, liteFill)
          : Color.alphaBlend(prime.glassTint, fill),
    };
    final topSpecular =
        isDock ? PrimeGlassV5.dockTopSpecular : 0.35;
    final dockVignette = isDark ? 0.14 : 0.08;

    Widget content = Padding(padding: padding, child: child);

    content = Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(child: ColoredBox(color: baseColor)),
        if (tier != LiquidTier.flat)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      highlight.withValues(alpha: topSpecular * 0.55),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.22],
                  ),
                ),
              ),
            ),
          ),
        if (tier != LiquidTier.flat)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(
                        alpha: isDock ? dockVignette : (isDark ? 0.18 : 0.04),
                      ),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.12],
                  ),
                ),
              ),
            ),
          ),
        content,
        if (tier != LiquidTier.flat)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RimLightPainter(
                  radius: radius,
                  borderColor: prime.glassBorder,
                  isDark: isDark,
                  strong: isDock,
                ),
              ),
            ),
          ),
      ],
    );

    if (tier == LiquidTier.full) {
      // BackdropFilter must wrap the layered surface itself. Flutter applies
      // the filter to pixels already painted behind this subtree while the
      // translucent fill, specular light and child content stay crisp above it.
      final blur = ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
      final filter = isDock
          ? ImageFilter.compose(
              outer: blur,
              inner: ImageFilter.matrix(
                Float64List.fromList(_saturationMatrix4x4(1.35)),
              ),
            )
          : blur;
      content = BackdropFilter(
        filter: filter,
        child: content,
      );
    }

    return content;
  }
}

/// Luminance-preserving saturation boost for dock frosted glass (4×4).
List<double> _saturationMatrix4x4(double saturation) {
  const lumR = 0.2126;
  const lumG = 0.7152;
  const lumB = 0.0722;
  final inv = 1 - saturation;
  final sr = inv * lumR;
  final sg = inv * lumG;
  final sb = inv * lumB;
  return [
    sr + saturation, sg, sb, 0,
    sr, sg + saturation, sb, 0,
    sr, sg, sb + saturation, 0,
    0, 0, 0, 1,
  ];
}

class _RimLightPainter extends CustomPainter {
  _RimLightPainter({
    required this.radius,
    required this.borderColor,
    required this.isDark,
    this.strong = false,
  });

  final double radius;
  final Color borderColor;
  final bool isDark;
  final bool strong;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = squirclePath(rect.deflate(0.5), radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          (strong && isDark
                  ? Colors.white
                  : borderColor)
              .withValues(
            alpha: strong
                ? (isDark ? 0.12 : PrimeGlassV5.maxTopRimAlpha)
                : (isDark ? 0.28 : 0.35),
          ),
          borderColor.withValues(alpha: isDark ? 0.06 : 0.12),
          borderColor.withValues(alpha: isDark ? 0.02 : 0.04),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RimLightPainter old) =>
      old.radius != radius ||
      old.borderColor != borderColor ||
      old.isDark != isDark ||
      old.strong != strong;
}
