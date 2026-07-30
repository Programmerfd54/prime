import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../prime/prime_glass_v5.dart';
import '../liquid/liquid_glass.dart';
import '../theme/prime_colors.dart';
import '../theme/prime_theme_context.dart';
import '../tokens.dart';

/// V4 glass overlay variants — navigation, toolbar, sheet, context menu.
enum PrimeGlassVariant { navigation, toolbar, sheet, contextMenu }

/// Unified V4 glass surface (clip → blur → tint → rim → content).
///
/// Sheets use higher opacity so fields remain readable; navigation uses blur.
class PrimeGlassSurface extends StatelessWidget {
  const PrimeGlassSurface({
    super.key,
    required this.child,
    this.variant = PrimeGlassVariant.navigation,
    this.padding,
    this.margin,
    this.radius = AppRadius.xl,
    this.width,
    this.height,
    this.onTap,
  });

  final Widget child;
  final PrimeGlassVariant variant;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  static bool _reduceTransparency(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  @override
  Widget build(BuildContext context) {
    final prime = context.prime;
    final reduce = _reduceTransparency(context);

    if (reduce || (kIsWeb && variant == PrimeGlassVariant.sheet)) {
      return _OpaqueSurface(
        variant: variant,
        padding: padding,
        margin: margin,
        radius: radius,
        width: width,
        height: height,
        onTap: onTap,
        fill: _opaqueFill(prime, variant),
        child: child,
      );
    }

    final tier = switch (variant) {
      PrimeGlassVariant.navigation => LiquidTier.full,
      PrimeGlassVariant.toolbar => LiquidTier.full,
      PrimeGlassVariant.sheet => LiquidTier.lite,
      PrimeGlassVariant.contextMenu => LiquidTier.lite,
    };

    final fillOpacity = switch (variant) {
      PrimeGlassVariant.navigation => PrimeGlassV5.maxCanvasTintAlpha,
      PrimeGlassVariant.toolbar => 0.72,
      PrimeGlassVariant.sheet => 0.0,
      PrimeGlassVariant.contextMenu => 0.80,
    };

    final sigma = switch (variant) {
      PrimeGlassVariant.navigation => 40.0,
      PrimeGlassVariant.toolbar => 24.0,
      PrimeGlassVariant.sheet => 18.0,
      PrimeGlassVariant.contextMenu => 16.0,
    };

    return RepaintBoundary(
      child: LiquidGlass(
        allowBlurOnWeb: variant != PrimeGlassVariant.navigation,
        forceTier: tier,
        padding: padding ?? _defaultPadding(variant),
        margin: margin,
        radius: radius,
        width: width,
        height: height,
        sigma: sigma,
        fillOpacity: fillOpacity,
        variant: variant == PrimeGlassVariant.navigation
            ? LiquidGlassVariant.dock
            : LiquidGlassVariant.standard,
        onTap: onTap,
        child: variant == PrimeGlassVariant.sheet
            ? ColoredBox(
                color: _sheetTint(prime),
                child: child,
              )
            : child,
      ),
    );
  }

  static EdgeInsets _defaultPadding(PrimeGlassVariant variant) =>
      switch (variant) {
        PrimeGlassVariant.navigation => EdgeInsets.zero,
        PrimeGlassVariant.toolbar =>
          const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        PrimeGlassVariant.sheet => const EdgeInsets.all(AppSpacing.lg),
        PrimeGlassVariant.contextMenu => const EdgeInsets.symmetric(
            vertical: AppSpacing.xs,
          ),
      };

  static Color _opaqueFill(PrimeColors prime, PrimeGlassVariant variant) =>
      switch (variant) {
        PrimeGlassVariant.navigation =>
          prime.surfaceElevated.withValues(alpha: 0.94),
        PrimeGlassVariant.toolbar =>
          prime.surfaceElevated.withValues(alpha: 0.96),
        PrimeGlassVariant.sheet => prime.surfaceElevated,
        PrimeGlassVariant.contextMenu => prime.surfaceElevated,
      };

  static Color _sheetTint(PrimeColors prime) =>
      prime.surfaceElevated.withValues(alpha: prime.isDark ? 0.92 : 0.96);
}

class _OpaqueSurface extends StatelessWidget {
  const _OpaqueSurface({
    required this.variant,
    required this.padding,
    required this.margin,
    required this.radius,
    required this.width,
    required this.height,
    required this.onTap,
    required this.fill,
    required this.child,
  });

  final PrimeGlassVariant variant;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final Color fill;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final prime = context.prime;
    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: prime.hairline),
      ),
      child: Padding(
        padding: padding ?? PrimeGlassSurface._defaultPadding(variant),
        child: child,
      ),
    );

    if (margin != null) {
      surface = Padding(padding: margin!, child: surface);
    }
    if (width != null || height != null) {
      surface = SizedBox(width: width, height: height, child: surface);
    }
    if (onTap != null) {
      surface = GestureDetector(onTap: onTap, child: surface);
    }
    return RepaintBoundary(child: surface);
  }
}
