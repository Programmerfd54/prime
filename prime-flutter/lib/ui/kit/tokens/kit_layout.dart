import 'package:flutter/material.dart';

import '../../../design/tokens.dart';

/// Layout constants for the visual reset kit.
abstract final class KitLayout {
  static const navHeight = 52.0;
  static const navSlotWidth = 50.0;
  static const navSlotGap = 5.0;
  static const navHPadding = 10.0;
  static const navPillWidth = 46.0;
  static const navPillHeight = 40.0;
  static const navInset = 16.0;
  static const navRadius = 26.0;
  static const navBottomClearance = 76.0;

  /// Compact floating dock width for [itemCount] icon slots.
  static double navWidthFor(int itemCount) =>
      navHPadding * 2 +
      itemCount * navSlotWidth +
      (itemCount - 1) * navSlotGap;

  static const listRowHeight = 72.0;
  static const listRowCompact = 68.0;
  static const segmentHeight = 42.0;
  static const composerHeight = 56.0;
  static const contextualBarMin = 72.0;

  static const headerAvatar = 40.0;
  static const heroAvatar = 44.0;

  static const scrollBottomInset = EdgeInsets.only(
    bottom: navBottomClearance + AppSpacing.md,
  );
}
