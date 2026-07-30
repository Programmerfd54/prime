import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import 'profile_editorial_widgets.dart';
import 'profile_surfaces.dart';
import 'profile_typography.dart';

/// Own profile tabs (TZ §36).
enum OwnProfileTab { overview, progress, habits, achievements }

/// Public profile tabs (TZ §36).
enum PublicProfileTab { overview, compatibility, habits, achievements }

/// Segmented editorial tab control for profile screens.
class ProfileTabBar extends StatelessWidget {
  const ProfileTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(4),
      decoration: ProfileSurfaces.cardDecoration(
        fill: ProfileSurfaces.surfaceElevated,
        radius: 16,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              _SegmentTab(
                label: tabs[i],
                selected: i == selectedIndex,
                onTap: () => onSelected(i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? ProfilePalette.primaryAction
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: ProfilePalette.primaryAction
                          .withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: ProfileTypography.cta.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected
                  ? ProfilePalette.offWhite
                  : ProfilePalette.coolGrey.withValues(alpha: 0.78),
            ),
          ),
        ),
      ),
    );
  }
}
