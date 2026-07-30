import 'package:flutter/material.dart';

import '../../../design/tokens.dart';

/// Layout constants for the visual reset kit.
abstract final class KitLayout {
  static const navHeight = 68.0;
  static const navSlotWidth = 50.0;
  static const navSlotGap = 5.0;
  static const navHPadding = 10.0;
  static const navPillWidth = 46.0;
  static const navPillHeight = 40.0;
  static const navInset = 16.0;
  static const navRadius = 26.0;
  static const navBottomClearance = 120.0;

  /// Max readable width for main-tab scroll content on tablet / web rail.
  static const tabExpandedMaxWidth = 720.0;

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

  /// True when [MainShell] shows the side rail instead of the bottom dock.
  static bool usesNavigationRail(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;

  /// Bottom scroll padding: dock clearance on phone, safe area only on rail/web.
  static double scrollBottomFor(BuildContext context) {
    final safe = MediaQuery.paddingOf(context).bottom;
    if (usesNavigationRail(context)) return safe + AppSpacing.lg;
    return navBottomClearance + safe;
  }

  /// In-content tail spacer — clears floating dock on tab screens.
  static double dockScrollTail(BuildContext context) =>
      navBottomClearance + MediaQuery.paddingOf(context).bottom + AppSpacing.md;

  /// Standard tab-screen sliver/list padding with responsive bottom inset.
  static EdgeInsets tabScrollPadding(
    BuildContext context, {
    double left = AppSpacing.md,
    double top = AppSpacing.md,
    double right = AppSpacing.md,
  }) {
    return EdgeInsets.fromLTRB(left, top, right, scrollBottomFor(context));
  }
}

/// Centers tab content on tablet/web while keeping phone layouts edge-to-edge.
class PrimeTabContentFrame extends StatelessWidget {
  const PrimeTabContentFrame({
    super.key,
    required this.child,
    this.maxWidth = KitLayout.tabExpandedMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (!KitLayout.usesNavigationRail(context)) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
