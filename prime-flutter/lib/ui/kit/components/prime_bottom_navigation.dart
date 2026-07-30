import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../design/haptics.dart';
import '../../../design/liquid/liquid_glass.dart';
import '../../../design/motion.dart';
import '../../../design/prime/prime_glass_v5.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../components/app_bottom_navigation.dart';
import '../tokens/kit_layout.dart';

/// Compact floating Liquid Glass tab bar — oval icon slots.
class PrimeBottomNavigation extends StatefulWidget {
  const PrimeBottomNavigation({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.badgeIndices = const {},
    this.visible = true,
  });

  final List<AppBottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Set<int> badgeIndices;
  final bool visible;

  @override
  State<PrimeBottomNavigation> createState() => _PrimeBottomNavigationState();
}

class _PrimeBottomNavigationState extends State<PrimeBottomNavigation>
    with TickerProviderStateMixin {
  static const _glassPulseBoost = 12.0;
  static const _pillOvershoot = 4.0;

  late final AnimationController _indicator;
  late final AnimationController _hide;
  late final AnimationController _glassPulse;

  @override
  void initState() {
    super.initState();
    _indicator = AnimationController.unbounded(
      vsync: this,
      value: widget.selectedIndex.toDouble(),
    );
    _hide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: widget.visible ? 0 : 1,
    );
    _glassPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void didUpdateWidget(covariant PrimeBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _animateIndicator(widget.selectedIndex.toDouble());
      _pulseGlass();
    } else if (_indicator.value.round() != widget.selectedIndex) {
      _indicator.value = widget.selectedIndex.toDouble();
    }
    if (oldWidget.visible != widget.visible) {
      _hide.animateTo(
        widget.visible ? 0 : 1,
        curve: widget.visible ? AppMotion.easeOutQuint : AppMotion.emphasized,
      );
    }
  }

  void _animateIndicator(double target) {
    if (AppMotion.reduce(context)) {
      _indicator.value = target;
      return;
    }
    final sim = SpringSimulation(
      AppMotion.liquidSpring,
      _indicator.value,
      target,
      _indicator.velocity,
    );
    _indicator.animateWith(sim);
  }

  void _pulseGlass() {
    if (AppMotion.reduce(context)) return;
    _glassPulse.forward(from: 0).then((_) {
      if (mounted) _glassPulse.reverse();
    });
  }

  double _slotCenterX(int index) =>
      KitLayout.navHPadding +
      index * (KitLayout.navSlotWidth + KitLayout.navSlotGap) +
      KitLayout.navSlotWidth / 2;

  @override
  void dispose() {
    _indicator.dispose();
    _hide.dispose();
    _glassPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return AnimatedBuilder(
      animation: Listenable.merge([_indicator, _hide, _glassPulse]),
      builder: (context, _) {
        final hideT = _hide.value;
        final n = widget.items.length;
        final pulseT = AppMotion.easeOutQuint.transform(_glassPulse.value);
        final dockSigma =
            LiquidGlassDockPreset.sigma + pulseT * _glassPulseBoost;

        final t = n == 0 ? 0.0 : _indicator.value.clamp(0.0, (n - 1).toDouble());
        final i0 = t.floor().clamp(0, n > 0 ? n - 1 : 0);
        final i1 = t.ceil().clamp(0, n > 0 ? n - 1 : 0);
        final frac = t - i0;
        final centerX =
            _slotCenterX(i0) + (_slotCenterX(i1) - _slotCenterX(i0)) * frac;
        final travelBulge = n > 1 ? (1 - (2 * frac - 1).abs()) * _pillOvershoot : 0.0;
        final pillW = KitLayout.navPillWidth + travelBulge;
        final pillH = KitLayout.navPillHeight;
        final pillLeft = centerX - pillW / 2;

        return Transform.translate(
          offset: Offset(
            0,
            hideT * (KitLayout.navHeight + bottom + 24),
          ),
          child: Opacity(
            opacity: (1 - hideT).clamp(0.0, 1.0),
            child: Padding(
              padding: EdgeInsets.only(
                left: KitLayout.navInset,
                right: KitLayout.navInset,
                bottom: bottom + AppSpacing.sm,
              ),
              child: Center(
                child: LiquidGlassDock(
                  radius: KitLayout.navRadius,
                  height: KitLayout.navHeight,
                  width: KitLayout.navWidthFor(n),
                  sigma: dockSigma,
                  child: n == 0
                      ? const SizedBox.shrink()
                      : Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              left: pillLeft,
                              width: pillW,
                              height: pillH,
                              child: const _SelectionPill(),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: KitLayout.navHPadding,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 0; i < n; i++) ...[
                                    if (i > 0)
                                      const SizedBox(width: KitLayout.navSlotGap),
                                    _NavTab(
                                      item: widget.items[i],
                                      selected: i == widget.selectedIndex,
                                      showBadge:
                                          widget.badgeIndices.contains(i),
                                      onTap: () {
                                        AppHaptics.selection();
                                        widget.onSelected(i);
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SelectionPill extends StatelessWidget {
  const _SelectionPill();

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final radius = KitLayout.navPillHeight / 2;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PrimeGlassV5.dockSelectionFill(p.brand, isDark: p.isDark),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: PrimeGlassV5.dockSelectionBorder(p.brand, isDark: p.isDark),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            ...AppGlow.violet(opacity: 0.12),
          ],
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.item,
    required this.selected,
    required this.showBadge,
    required this.onTap,
  });

  final AppBottomNavItem item;
  final bool selected;
  final bool showBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final activeColor = p.brandStrong;
    final inactiveColor = p.ink.withValues(alpha: 0.58);
    final radius = KitLayout.navPillHeight / 2;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          splashColor: p.brand.withValues(alpha: 0.12),
          highlightColor: p.brand.withValues(alpha: 0.06),
          child: SizedBox(
            width: KitLayout.navSlotWidth,
            height: KitLayout.navPillHeight,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: selected ? 1.08 : 1.0,
                    duration: AppMotion.duration(context, AppDurations.fast),
                    curve: AppMotion.easeOutQuint,
                    child: Icon(
                      selected ? item.selectedIcon : item.icon,
                      color: selected ? activeColor : inactiveColor,
                      size: 24,
                    ),
                  ),
                  if (showBadge)
                    Positioned(
                      right: 8,
                      top: 4,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: p.coral,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: p.surfaceElevated,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scroll padding helper — keeps last item above the floating nav.
class PrimeNavScrollPadding {
  static EdgeInsets screen(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return EdgeInsets.only(bottom: KitLayout.navBottomClearance + bottom);
  }
}
