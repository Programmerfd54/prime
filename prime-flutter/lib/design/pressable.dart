import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'haptics.dart';
import 'motion.dart';

/// Micro-scale press feedback via real spring physics + optional haptic.
class PrimePressable extends StatefulWidget {
  const PrimePressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.haptic = true,
    this.scale = 0.96,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final bool haptic;
  final double scale;
  final BorderRadius? borderRadius;

  @override
  State<PrimePressable> createState() => _PrimePressableState();
}

class _PrimePressableState extends State<PrimePressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: 1);
    _scale = _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    if (AppMotion.reduce(context)) {
      _controller.value = target;
      return;
    }
    final sim = SpringSimulation(
      AppMotion.pressSpring,
      _controller.value,
      target,
      _controller.velocity,
    );
    _controller.animateWith(sim);
  }

  void _down() {
    if (!widget.enabled || widget.onTap == null) return;
    _animateTo(widget.scale);
  }

  void _up() {
    if (!widget.enabled || widget.onTap == null) return;
    _animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _down(),
      onTapCancel: _up,
      onTapUp: (_) => _up(),
      onTap: widget.enabled && widget.onTap != null
          ? () {
              if (widget.haptic) AppHaptics.selection();
              widget.onTap!();
            }
          : null,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(scale: _scale.value, child: child);
        },
        child: widget.child,
      ),
    );
  }
}
