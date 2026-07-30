import 'package:flutter/material.dart';

import '../../design/haptics.dart';
import '../../design/pressable.dart';
import '../../design/theme/prime_theme_context.dart';
import '../../design/tokens.dart';
import '../kit/tokens/kit_surfaces.dart';

/// Generic surface container for grouped content — solid V4 surface by default.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color,
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    final p = context.prime;

    final decoration = color != null || borderColor != null
        ? BoxDecoration(
            color: color ?? p.surfaceElevated,
            borderRadius: radius,
            border: Border.all(color: borderColor ?? p.hairline),
          )
        : kitSurfaceDecoration(
            context,
            PrimeSurfaceLevel.solid,
            radius: AppRadius.md,
            borderRadius: radius,
          );

    final body = Padding(padding: padding, child: child);

    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: body);
    }

    return PrimePressable(
      onTap: () {
        AppHaptics.selection();
        onTap!();
      },
      haptic: false,
      borderRadius: radius,
      child: DecoratedBox(decoration: decoration, child: body),
    );
  }
}
