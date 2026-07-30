import 'package:flutter/material.dart';

import '../ui/kit/tokens/kit_surfaces.dart';
import 'theme/prime_theme_context.dart';
import 'tokens.dart';

enum AppSurfaceTone { dark, tonal, brand, glass }

/// Self-styling surface — picks fill, text, border and shadow from tone.
class PrimeSurface extends StatelessWidget {
  const PrimeSurface({
    super.key,
    required this.child,
    this.tone = AppSurfaceTone.dark,
    this.padding,
    this.margin,
    this.borderRadius,
    this.width,
    this.height,
    this.onTap,
    this.gradient,
  });

  final Widget child;
  final AppSurfaceTone tone;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final Gradient? gradient;

  PrimeSurfaceLevel get _level => switch (tone) {
        AppSurfaceTone.glass => PrimeSurfaceLevel.glass,
        AppSurfaceTone.brand => PrimeSurfaceLevel.accent,
        AppSurfaceTone.tonal => PrimeSurfaceLevel.solid,
        AppSurfaceTone.dark => PrimeSurfaceLevel.solid,
      };

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.xl);
    final pad = padding ?? const EdgeInsets.all(AppSpacing.lg);

    final themed = DefaultTextStyle.merge(
      style: TextStyle(color: p.ink),
      child: IconTheme.merge(
        data: IconThemeData(color: p.inkSecondary),
        child: child,
      ),
    );

    final decoration = gradient == null
        ? kitSurfaceDecoration(
            context,
            _level,
            borderRadius: radius,
          )
        : BoxDecoration(
            gradient: gradient,
            borderRadius: radius,
            border: Border.all(color: p.hairline),
          );

    Widget content = Container(
      width: width,
      height: height,
      margin: margin,
      padding: pad,
      decoration: decoration,
      child: themed,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: content,
        ),
      );
    }

    return content;
  }
}
