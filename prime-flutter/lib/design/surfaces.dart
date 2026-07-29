import 'package:flutter/material.dart';

import 'glass.dart';
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

  Color get backgroundColor => switch (tone) {
        AppSurfaceTone.dark => AppColors.surface,
        AppSurfaceTone.tonal => AppColors.surfaceSoft,
        AppSurfaceTone.brand => AppColors.primaryContainer,
        AppSurfaceTone.glass => Colors.transparent,
      };

  Color get foregroundColor => AppColors.textPrimary;

  Color get mutedForegroundColor => AppColors.textSecondary;

  Color get borderColor => switch (tone) {
        AppSurfaceTone.brand => AppColors.primary.withValues(alpha: 0.35),
        AppSurfaceTone.glass => Colors.white.withValues(alpha: 0.10),
        _ => AppColors.border,
      };

  List<BoxShadow> get shadows => AppElevation.none;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.xl);
    final pad = padding ?? const EdgeInsets.all(AppSpacing.lg);

    Widget themed = DefaultTextStyle.merge(
      style: TextStyle(color: foregroundColor),
      child: IconTheme.merge(
        data: IconThemeData(color: mutedForegroundColor),
        child: child,
      ),
    );

    if (tone == AppSurfaceTone.glass && gradient == null) {
      return GlassContainer(
        width: width,
        height: height,
        margin: margin,
        padding: pad,
        borderRadius: radius,
        onTap: onTap,
        child: themed,
      );
    }

    final decoration = BoxDecoration(
      color: gradient == null ? backgroundColor : null,
      gradient: gradient,
      borderRadius: radius,
      border: Border.all(color: borderColor),
      boxShadow: shadows,
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
