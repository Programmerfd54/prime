import 'package:flutter/material.dart';

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
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final body = Container(
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
