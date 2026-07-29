import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../design/haptics.dart';
import '../../../design/liquid/liquid_glass.dart';
import '../../../design/motion.dart';
import '../../../design/shapes/prime_squircle.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../app_bottom_navigation.dart';

/// Floating liquid-glass navigation dock with a sliding lozenge indicator.
///
/// Prefer [PrimeBottomNavigation] via [AppBottomNavigation] for phone layouts.
@Deprecated('Use AppBottomNavigation / PrimeBottomNavigation instead.')
class PrimeLiquidDock extends StatefulWidget {
  const PrimeLiquidDock({
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
  State<PrimeLiquidDock> createState() => _PrimeLiquidDockState();
}

class _PrimeLiquidDockState extends State<PrimeLiquidDock>
    with TickerProviderStateMixin {
  late final AnimationController _lozenge;
  late final AnimationController _hide;
  final GlobalKey _rowKey = GlobalKey();
  final List<GlobalKey> _itemKeys = [];

  @override
  void initState() {
    super.initState();
    _lozenge = AnimationController.unbounded(
      vsync: this,
      value: widget.selectedIndex.toDouble(),
    );
    _hide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: widget.visible ? 0 : 1,
    );
    _ensureKeys(widget.items.length);
    WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
  }

  void _ensureKeys(int n) {
    while (_itemKeys.length < n) {
      _itemKeys.add(GlobalKey());
    }
    while (_itemKeys.length > n) {
      _itemKeys.removeLast();
    }
  }

  @override
  void didUpdateWidget(covariant PrimeLiquidDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureKeys(widget.items.length);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _animateLozenge(widget.selectedIndex.toDouble());
    }
    if (oldWidget.visible != widget.visible) {
      if (widget.visible) {
        _hide.animateTo(0, curve: AppMotion.easeOutQuint);
      } else {
        _hide.animateTo(1, curve: AppMotion.emphasized);
      }
    }
  }

  void _animateLozenge(double target) {
    if (AppMotion.reduce(context)) {
      _lozenge.value = target;
      return;
    }
    final sim = SpringSimulation(
      AppMotion.liquidSpring,
      _lozenge.value,
      target,
      _lozenge.velocity,
    );
    _lozenge.animateWith(sim);
  }

  @override
  void dispose() {
    _lozenge.dispose();
    _hide.dispose();
    super.dispose();
  }

  Rect? _slotRect(int index) {
    final rowCtx = _rowKey.currentContext;
    final itemCtx = index < _itemKeys.length
        ? _itemKeys[index].currentContext
        : null;
    if (rowCtx == null || itemCtx == null) return null;
    final rowBox = rowCtx.findRenderObject() as RenderBox?;
    final itemBox = itemCtx.findRenderObject() as RenderBox?;
    if (rowBox == null || itemBox == null || !rowBox.hasSize || !itemBox.hasSize) {
      return null;
    }
    final origin = rowBox.localToGlobal(Offset.zero);
    final itemOrigin = itemBox.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      itemOrigin.dx - origin.dx,
      itemOrigin.dy - origin.dy,
      itemBox.size.width,
      itemBox.size.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return AnimatedBuilder(
      animation: Listenable.merge([_lozenge, _hide]),
      builder: (context, _) {
        final hideT = _hide.value;
        return Transform.translate(
          offset: Offset(0, (64 + bottomInset + 24) * hideT),
          child: Opacity(
            opacity: (1 - hideT).clamp(0.0, 1.0),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm + (bottomInset > 0 ? 0 : AppSpacing.xs),
              ),
              child: LiquidGlass(
                allowBlurOnWeb: true,
                // No forceTier — respects reduce-motion / low-end flat fallback.
                padding: EdgeInsets.zero,
                radius: AppRadius.xl + 4,
                sigma: 24,
                fillOpacity: 0.17,
                glow: AppGlow.softDock()..addAll(AppGlow.violet(opacity: 0.10)),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: AppControlHeights.bottomNav,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      child: Stack(
                        key: _rowKey,
                        children: [
                          // Sliding lozenge
                          if (_slotRect(widget.selectedIndex) != null ||
                              _lozenge.value >= 0)
                            _buildLozenge(),
                          // Tab buttons
                          Row(
                            children: [
                              for (var i = 0; i < widget.items.length; i++)
                                Expanded(
                                  child: KeyedSubtree(
                                    key: _itemKeys[i],
                                    child: _DockTab(
                                      item: widget.items[i],
                                      selected: widget.selectedIndex == i,
                                      showBadge:
                                          widget.badgeIndices.contains(i),
                                      onTap: () {
                                        AppHaptics.selection();
                                        widget.onSelected(i);
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLozenge() {
    final n = widget.items.length;
    if (n == 0) return const SizedBox.shrink();

    // Interpolate between neighbouring slot rects for smooth travel.
    final t = _lozenge.value.clamp(0.0, (n - 1).toDouble());
    final i0 = t.floor().clamp(0, n - 1);
    final i1 = t.ceil().clamp(0, n - 1);
    final frac = t - i0;
    final r0 = _slotRect(i0);
    final r1 = _slotRect(i1);
    if (r0 == null && r1 == null) return const SizedBox.shrink();
    final a = r0 ?? r1!;
    final b = r1 ?? r0!;
    // Slight width overshoot mid-travel for liquid feel.
    final overshoot = (1 - (2 * frac - 1).abs()) * 6;
    final left = a.left + (b.left - a.left) * frac;
    final width = a.width + (b.width - a.width) * frac + overshoot;
    final top = a.top + (b.top - a.top) * frac + 6;
    final height = a.height - 12;

    return Positioned(
      left: left + 4,
      top: top,
      width: width - 8,
      height: height,
      child: DecoratedBox(
        // Stadium, not a squircle at radius 999 — a pill radius clamped to
        // min(w,h)/2 removes the straight edges and reads as a hexagon.
        decoration: ShapeDecoration(
          shape: StadiumBorder(
            side: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
          color: AppColors.primary.withValues(alpha: 0.24),
          shadows: AppGlow.violet(opacity: 0.34),
        ),
      ),
    );
  }
}

class _DockTab extends StatelessWidget {
  const _DockTab({
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
    final color = selected ? AppColors.primarySoft : AppColors.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: selected ? 1.08 : 1.0,
                  duration: AppMotion.duration(context, AppDurations.fast),
                  curve: AppMotion.easeOutQuint,
                  child: Icon(
                    selected ? item.selectedIcon : item.icon,
                    color: color,
                    size: AppIconSizes.md,
                  ),
                ),
                if (showBadge)
                  Positioned(
                    right: -4,
                    top: -3,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 320),
                      curve: AppMotion.easeOutQuint,
                      builder: (context, t, child) {
                        return Transform.scale(scale: t, child: child);
                      },
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: AppGlow.violet(opacity: 0.45),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            AnimatedSize(
              duration: AppMotion.duration(context, AppDurations.fast),
              curve: AppMotion.easeOutQuint,
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vertical liquid rail for tablet / wide layouts.
class PrimeLiquidRail extends StatelessWidget {
  const PrimeLiquidRail({
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
    return SizedBox(
      width: 92,
      child: LiquidGlass(
        allowBlurOnWeb: true,
        forceTier: LiquidTier.full,
        padding: EdgeInsets.zero,
        radius: 0,
        fillOpacity: 0.08,
        clip: false,
        child: SafeArea(
          right: false,
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              ClipOval(
                child: Image.asset(
                  'assets/logo.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final selected = selectedIndex == index;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          AppHaptics.selection();
                          onSelected(index);
                        },
                        child: AnimatedContainer(
                          duration:
                              AppMotion.duration(context, AppDurations.normal),
                          curve: AppMotion.easeOutQuint,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          decoration: PrimeSquircleDecoration(
                            radius: AppRadius.lg,
                            color: selected
                                ? AppColors.primaryContainer
                                    .withValues(alpha: 0.95)
                                : Colors.transparent,
                            border: selected
                                ? BorderSide(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.4),
                                  )
                                : null,
                            boxShadow: selected
                                ? AppGlow.violet(opacity: 0.2)
                                : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(
                                    selected
                                        ? item.selectedIcon
                                        : item.icon,
                                    color: selected
                                        ? AppColors.primarySoft
                                        : AppColors.textMuted,
                                    size: AppIconSizes.md,
                                  ),
                                  if (badgeIndices.contains(index))
                                    Positioned(
                                      right: -4,
                                      top: -2,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  color: selected
                                      ? AppColors.primarySoft
                                      : AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
