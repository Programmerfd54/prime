import 'package:flutter/material.dart';
import 'package:prime/config/theme.dart';
import 'package:prime/design/tokens.dart';

/// Shared golden/widget test harness with theme binding.
Widget primeTestApp({
  required Widget home,
  Brightness brightness = Brightness.dark,
  Size size = const Size(390, 844),
  bool disableAnimations = true,
}) {
  ThemeBinding.bind(brightness);
  final theme = brightness == Brightness.dark ? AppTheme.dark : AppTheme.light;
  return MediaQuery(
    data: MediaQueryData(size: size, disableAnimations: disableAnimations),
    child: MaterialApp(
      theme: theme,
      home: home,
    ),
  );
}
