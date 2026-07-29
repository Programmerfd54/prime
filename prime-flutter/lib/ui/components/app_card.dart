import 'package:flutter/material.dart';

import '../../design/glass.dart';
import '../../design/haptics.dart';
import '../../design/pressable.dart';
import '../../design/tokens.dart';

/// Generic surface container for grouped content — glass by default.
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

    // Custom solid color path keeps legacy call-site overrides working.
    if (color != null || borderColor != null) {
      final decoration = BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? AppColors.border),
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

    final glass = GlassContainer(
      padding: padding,
      borderRadius: radius,
      child: child,
    );

    if (onTap == null) return glass;

    return PrimePressable(
      onTap: () {
        AppHaptics.selection();
        onTap!();
      },
      haptic: false,
      borderRadius: radius,
      child: glass,
    );
  }
}
