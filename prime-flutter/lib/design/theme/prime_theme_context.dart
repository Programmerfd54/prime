import 'package:flutter/material.dart';

import '../tokens.dart';
import 'prime_colors.dart';

/// Convenient accessor: `context.prime.brand`, `context.prime.ink`, etc.
extension PrimeThemeContext on BuildContext {
  PrimeColors get prime {
    final ext = Theme.of(this).extension<PrimeColors>();
    // Fall back to ThemeBinding brightness when extension is absent
    // (legacy tests / transitional screens).
    if (ext != null) return ext;
    return ThemeBinding.colors;
  }
}
