import 'package:flutter/material.dart';

import 'liquid/liquid_glass.dart';
import 'tokens.dart';

/// Platform-aware glass quality (legacy API — prefer [LiquidGlass]).
enum GlassTier {
  /// Full BackdropFilter blur.
  blur,

  /// Specular + rim without blur (maps to [LiquidTier.lite]).
  fallback,
}

/// Resolves blur vs lite. Prefer [resolveLiquidTier] for new code.
GlassTier resolveGlassTier(BuildContext context) {
  final tier = resolveLiquidTier(context);
  return switch (tier) {
    LiquidTier.full => GlassTier.blur,
    LiquidTier.lite || LiquidTier.flat => GlassTier.fallback,
  };
}

/// Glassmorphic surface — thin alias over [LiquidGlass] so existing call sites
/// pick up specular + rim light without a migration.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.width,
    this.height,
    this.onTap,
    this.glow,
    this.sigma = 16,
    this.fillOpacity = 0.06,
    this.forceTier,
    this.allowBlurOnWeb = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final List<BoxShadow>? glow;
  final double sigma;
  final double fillOpacity;
  final GlassTier? forceTier;
  final bool allowBlurOnWeb;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius?.topLeft.x ?? AppRadius.bentoOuter;
    final liquidForce = switch (forceTier) {
      GlassTier.blur => LiquidTier.full,
      GlassTier.fallback => LiquidTier.lite,
      null => null,
    };

    return LiquidGlass(
      padding: padding,
      margin: margin,
      radius: radius,
      width: width,
      height: height,
      onTap: onTap,
      glow: glow,
      sigma: sigma,
      fillOpacity: fillOpacity,
      forceTier: liquidForce,
      allowBlurOnWeb: allowBlurOnWeb,
      child: child,
    );
  }
}
