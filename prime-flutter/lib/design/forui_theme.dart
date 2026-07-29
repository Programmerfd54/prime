import 'package:forui/forui.dart';

import 'theme/prime_colors.dart';

/// Maps PRIME design tokens onto a Forui theme for the given [colors].
FThemeData primeForuiTheme([PrimeColors? colors]) {
  final c = colors ?? PrimeColors.dark();
  final base =
      c.isDark ? FTheme.neutral.dark.touch : FTheme.neutral.light.touch;
  return FThemeData(
    touch: true,
    debugLabel: c.isDark ? 'PRIME Dark Touch' : 'PRIME Light Touch',
    colors: base.colors.copyWith(
      brightness: c.brightness,
      background: c.canvas,
      foreground: c.ink,
      primary: c.brand,
      primaryForeground: c.inkOnBrand,
      secondary: c.brandContainer,
      secondaryForeground: c.ink,
      muted: c.surfaceElevated,
      mutedForeground: c.inkMuted,
      destructive: c.error,
      destructiveForeground: c.onError,
      error: c.error,
      errorForeground: c.onError,
      border: c.hairlineStrong,
      card: c.surface,
    ),
  );
}
