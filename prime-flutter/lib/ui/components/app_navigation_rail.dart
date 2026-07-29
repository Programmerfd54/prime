import 'package:flutter/material.dart';

import 'app_bottom_navigation.dart';
import 'nav/prime_liquid_dock.dart';

/// Premium side navigation for tablet / wide layouts — liquid glass rail.
class AppNavigationRail extends StatelessWidget {
  const AppNavigationRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.badgeIndices = const {},
  });

  final List<AppBottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Set<int> badgeIndices;

  @override
  Widget build(BuildContext context) {
    return PrimeLiquidRail(
      items: items,
      selectedIndex: selectedIndex,
      onSelected: onSelected,
      badgeIndices: badgeIndices,
    );
  }
}
