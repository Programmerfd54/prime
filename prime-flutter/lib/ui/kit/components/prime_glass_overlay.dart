import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../tokens/kit_surfaces.dart';

/// Frosted overlay for hero controls and contextual bars only.
class PrimeGlassOverlay extends StatelessWidget {
  const PrimeGlassOverlay({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.blur = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final r = borderRadius ?? BorderRadius.circular(AppRadius.lg);
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: kitSurfaceDecoration(
            context,
            PrimeSurfaceLevel.glass,
            borderRadius: r,
          ),
          child: child,
        ),
      ),
    );
  }
}
