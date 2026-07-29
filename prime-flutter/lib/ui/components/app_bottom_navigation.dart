import 'package:flutter/material.dart';

import 'package:prime/ui/kit/prime_kit.dart';

export 'nav/prime_liquid_dock.dart' show PrimeLiquidDock, PrimeLiquidRail;

class AppBottomNavItem {
  const AppBottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.assetPath,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? assetPath;
}

/// Floating Liquid Glass navigation dock.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.badgeIndex,
    this.badgeIndices = const {},
    this.visible = true,
  });

  final List<AppBottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int? badgeIndex;
  final Set<int> badgeIndices;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final badges = {
      ...badgeIndices,
      if (badgeIndex != null) badgeIndex!,
    };
    return PrimeBottomNavigation(
      items: items,
      selectedIndex: selectedIndex,
      onSelected: onSelected,
      badgeIndices: badges,
      visible: visible,
    );
  }
}
