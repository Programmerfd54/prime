import 'package:flutter/material.dart';

import '../../../design/glass.dart';
import '../../../design/tokens.dart';
import '../tokens/kit_surfaces.dart';

/// Standard text card — solid surface, no glass rim.
class PrimeContentCard extends StatelessWidget {
  const PrimeContentCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.margin,
    this.glass = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final body = glass
        ? GlassContainer(
            margin: margin,
            padding: padding ?? const EdgeInsets.all(AppSpacing.md),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            fillOpacity: 0.10,
            glow: AppGlow.violet(opacity: 0.10),
            child: child,
          )
        : Container(
            margin: margin,
            padding: padding ?? const EdgeInsets.all(AppSpacing.md),
            decoration: kitSurfaceDecoration(context, PrimeSurfaceLevel.solid),
            child: child,
          );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: body,
      ),
    );
  }
}
