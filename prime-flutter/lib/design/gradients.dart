import 'package:flutter/material.dart';

import 'theme/prime_palette.dart';
import 'tokens.dart';

/// Per-tab hero temperature. Purple stays the brand glue.
abstract final class AppGradients {
  static LinearGradient get home => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: ThemeBinding.brightness == Brightness.dark
            ? const [
                Color(0xFF3D2A5C),
                Color(0xFF2A1F3D),
                Color(0xFF1A1528),
              ]
            : const [
                PrimePalette.mist,
                PrimePalette.softLilac,
                Color(0xFFF8F7FA),
              ],
      );

  static LinearGradient get habits => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: ThemeBinding.brightness == Brightness.dark
            ? const [
                Color(0xFF1E2A4A),
                Color(0xFF243048),
                Color(0xFF1A2230),
              ]
            : const [
                Color(0xFFE8EEF8),
                Color(0xFFF1EFF5),
                Color(0xFFF8F7FA),
              ],
      );

  static LinearGradient get groups => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: ThemeBinding.brightness == Brightness.dark
            ? const [
                Color(0xFF3D2440),
                Color(0xFF2E1F38),
                Color(0xFF1A1528),
              ]
            : const [
                Color(0xFFF3E8F5),
                PrimePalette.mist,
                Color(0xFFF8F7FA),
              ],
      );

  static LinearGradient get chats => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: ThemeBinding.brightness == Brightness.dark
            ? const [
                Color(0xFF242038),
                Color(0xFF1C1830),
                Color(0xFF14121E),
              ]
            : const [
                Color(0xFFEDEAF5),
                Color(0xFFF1EFF5),
                Color(0xFFF8F7FA),
              ],
      );

  static LinearGradient get profile => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: ThemeBinding.brightness == Brightness.dark
            ? const [
                Color(0xFF3A2E1F),
                Color(0xFF2E2440),
                Color(0xFF1A1528),
              ]
            : const [
                Color(0xFFF5EFE6),
                PrimePalette.mist,
                Color(0xFFF8F7FA),
              ],
      );

  static LinearGradient get authBackdrop => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          ThemeBinding.brightness == Brightness.dark
              ? const Color(0xFF3D2A5C)
              : PrimePalette.mist,
          AppColors.background,
          ThemeBinding.brightness == Brightness.dark
              ? const Color(0xFF0E0C14)
              : PrimePalette.lightCanvas,
        ],
      );

  static LinearGradient get brandWash => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primary, AppColors.primaryDeep],
      );

  static LinearGradient get onboardingPromise => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          ThemeBinding.brightness == Brightness.dark
              ? const Color(0xFF2A1F3D)
              : PrimePalette.mist,
          AppColors.background,
        ],
      );

  static LinearGradient get onboardingProblem => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: ThemeBinding.brightness == Brightness.dark
            ? const [Color(0xFF1A1822), Color(0xFF12101A)]
            : const [Color(0xFFE8E6ED), Color(0xFFF8F7FA)],
      );

  static LinearGradient get onboardingTeam => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: ThemeBinding.brightness == Brightness.dark
            ? const [Color(0xFF3D2A50), Color(0xFF1A1528)]
            : const [PrimePalette.softLilac, Color(0xFFF8F7FA)],
      );

  static LinearGradient get onboardingProgress => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: ThemeBinding.brightness == Brightness.dark
            ? const [Color(0xFF1A2E2A), Color(0xFF12101A)]
            : const [Color(0xFFE4F5EE), Color(0xFFF8F7FA)],
      );

  static LinearGradient forTab(int index) => switch (index) {
        0 => habits,
        1 => groups,
        2 => home,
        3 => chats,
        4 => profile,
        _ => home,
      };
}
