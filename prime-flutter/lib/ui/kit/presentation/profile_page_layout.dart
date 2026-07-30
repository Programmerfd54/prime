import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import 'profile_editorial_widgets.dart';
import 'profile_icons.dart';
import 'profile_states.dart';
import 'profile_typography.dart';

/// Scroll target for expanded profile navigation rail (TZ §16).
class ProfileRailDestination {
  const ProfileRailDestination({
    required this.icon,
    required this.label,
    required this.key,
  });

  final IconData icon;
  final String label;
  final GlobalKey key;
}

/// Responsive profile dashboard layout (TZ §16).
class ProfilePageLayout extends StatelessWidget {
  const ProfilePageLayout({
    super.key,
    required this.hero,
    required this.sections,
    this.expandedMaxWidth = 1200,
    this.railDestinations = const [],
    this.scrollController,
  });

  final Widget hero;
  final Widget sections;
  final double expandedMaxWidth;
  final List<ProfileRailDestination> railDestinations;
  final ScrollController? scrollController;

  static const mediumBreakpoint = 600.0;
  static const expandedBreakpoint = 1024.0;

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final body = _bodyForWidth(width);

        if (width >= expandedBreakpoint && railDestinations.isNotEmpty) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: expandedMaxWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileNavigationRail(
                      destinations: railDestinations,
                      onSelected: _scrollTo,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: body),
                  ],
                ),
              ),
            ),
          );
        }

        return body;
      },
    );
  }

  Widget _bodyForWidth(double width) {
    if (width >= expandedBreakpoint) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 11, child: hero),
            const SizedBox(width: AppSpacing.lg),
            Expanded(flex: 9, child: sections),
          ],
        ),
      );
    }
    if (width >= mediumBreakpoint) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ProfileHeroCard.maxContentWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              hero,
              sections,
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        hero,
        sections,
      ],
    );
  }
}

class _ProfileNavigationRail extends StatefulWidget {
  const _ProfileNavigationRail({
    required this.destinations,
    required this.onSelected,
  });

  final List<ProfileRailDestination> destinations;
  final ValueChanged<GlobalKey> onSelected;

  @override
  State<_ProfileNavigationRail> createState() => _ProfileNavigationRailState();
}

class _ProfileNavigationRailState extends State<_ProfileNavigationRail> {
  var _selected = 0;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: _selected,
      extended: false,
      minWidth: 72,
      backgroundColor: ProfilePalette.charcoal.withValues(alpha: 0.72),
      indicatorColor: ProfilePalette.primaryAction.withValues(alpha: 0.22),
      selectedIconTheme: IconThemeData(
        color: ProfilePalette.brandSoft,
        size: 22,
      ),
      unselectedIconTheme: IconThemeData(
        color: ProfilePalette.coolGrey.withValues(alpha: 0.75),
        size: 22,
      ),
      labelType: NavigationRailLabelType.none,
      onDestinationSelected: (index) {
        setState(() => _selected = index);
        widget.onSelected(widget.destinations[index].key);
      },
      destinations: [
        for (final d in widget.destinations)
          NavigationRailDestination(
            icon: ProfileHoverable(
              borderRadius: 14,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: ProfileIcon(d.icon, size: 22),
              ),
            ),
            label: Text(d.label, style: ProfileTypography.metricLabel),
          ),
      ],
    );
  }
}

/// Shown when participant hid most profile fields (TZ §14).
class ProfileRestrictedBanner extends StatelessWidget {
  const ProfileRestrictedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ProfilePalette.charcoal,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ProfilePalette.brandSoft.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility_off_outlined,
            color: ProfilePalette.brandSoft,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Участник ограничил видимость профиля',
              style: ProfileTypography.secondary.copyWith(
                color: ProfilePalette.offWhite.withValues(alpha: 0.88),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
