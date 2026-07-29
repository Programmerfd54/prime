import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

import 'tokens.dart';

/// Motion helpers that respect system "reduce motion" / disableAnimations.
abstract final class AppMotion {
  static bool reduce(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  static Duration duration(BuildContext context, Duration preferred) {
    if (reduce(context)) return AppDurations.zero;
    return preferred;
  }

  static Duration get press => AppDurations.press;
  static Duration get fast => AppDurations.fast;
  static Duration get normal => AppDurations.normal;
  static Duration get slow => AppDurations.slow;

  static Curve get standard => Curves.easeOutCubic;
  static Curve get emphasized => Curves.easeInOutCubic;

  /// Premium overshoot settle — preferred for docks, overlays, indicators.
  static Curve get easeOutQuint => Curves.easeOutQuint;

  /// Soft spring for selection indicators and floating chrome.
  static SpringDescription get softSpring => const SpringDescription(
        mass: 1,
        stiffness: 180,
        damping: 18,
      );

  /// Snappier spring for press / chip micro-interactions.
  static SpringDescription get pressSpring => const SpringDescription(
        mass: 0.8,
        stiffness: 320,
        damping: 22,
      );

  /// Lozenge dock indicator — slightly underdamped for liquid feel.
  static SpringDescription get liquidSpring => const SpringDescription(
        mass: 1,
        stiffness: 220,
        damping: 16,
      );
}

/// Drives a 0→1 (or custom) value with a real [SpringSimulation].
class PrimeSpringController extends ChangeNotifier {
  PrimeSpringController({
    TickerProvider? vsync,
    SpringDescription spring = const SpringDescription(
      mass: 1,
      stiffness: 180,
      damping: 18,
    ),
    double initial = 0,
  })  : _spring = spring,
        _value = initial {
    if (vsync != null) _attach(vsync);
  }

  SpringDescription _spring;
  double _value;
  double _velocity = 0;
  Ticker? _ticker;
  SpringSimulation? _sim;
  Duration _lastElapsed = Duration.zero;

  double get value => _value;
  double get velocity => _velocity;
  bool get isAnimating => _ticker?.isActive ?? false;

  void attach(TickerProvider vsync) {
    if (_ticker != null) return;
    _attach(vsync);
  }

  void _attach(TickerProvider vsync) {
    _ticker = vsync.createTicker(_onTick);
  }

  void updateSpring(SpringDescription spring) => _spring = spring;

  /// Animate toward [target] with the current spring.
  void animateTo(double target, {double? from, double velocity = 0}) {
    final start = from ?? _value;
    _sim = SpringSimulation(_spring, start, target, velocity);
    _lastElapsed = Duration.zero;
    _ticker?.start();
  }

  /// Snap immediately (no animation).
  void jumpTo(double target) {
    _ticker?.stop();
    _sim = null;
    if (_value == target) return;
    _value = target;
    _velocity = 0;
    notifyListeners();
  }

  void _onTick(Duration elapsed) {
    final sim = _sim;
    if (sim == null) {
      _ticker?.stop();
      return;
    }
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    final t = elapsed.inMicroseconds / 1e6;
    _value = sim.x(t);
    _velocity = sim.dx(t);
    notifyListeners();
    if (sim.isDone(t) || dt < 0) {
      _ticker?.stop();
      _sim = null;
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }
}

/// Listens to a [PrimeSpringController] and rebuilds.
class PrimeSpringBuilder extends StatelessWidget {
  const PrimeSpringBuilder({
    super.key,
    required this.controller,
    required this.builder,
  });

  final PrimeSpringController controller;
  final Widget Function(BuildContext context, double value) builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => builder(context, controller.value),
    );
  }
}

/// Staggered entrance for list children (fade + 12px up, 40ms cascade).
class PrimeStagger extends StatelessWidget {
  const PrimeStagger({
    super.key,
    required this.index,
    required this.child,
    this.delayStep = const Duration(milliseconds: 40),
    this.duration = const Duration(milliseconds: 420),
    this.offset = 12,
  });

  final int index;
  final Widget child;
  final Duration delayStep;
  final Duration duration;
  final double offset;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduce(context)) return child;
    final delay = delayStep * index;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Interval(
        delay.inMilliseconds / (duration + delay).inMilliseconds,
        1,
        curve: AppMotion.easeOutQuint,
      ),
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, offset * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Rolls a number from 0 (or [from]) up to [value] with tabular figures.
class PrimeAnimatedNumber extends StatelessWidget {
  const PrimeAnimatedNumber({
    super.key,
    required this.value,
    this.from,
    this.style,
    this.duration = const Duration(milliseconds: 700),
    this.prefix = '',
    this.suffix = '',
    this.fractionDigits = 0,
  });

  final num value;
  final num? from;
  final TextStyle? style;
  final Duration duration;
  final String prefix;
  final String suffix;
  final int fractionDigits;

  @override
  Widget build(BuildContext context) {
    final reduce = AppMotion.reduce(context);
    final begin = (from ?? 0).toDouble();
    final end = value.toDouble();
    if (reduce || begin == end) {
      return Text(
        '$prefix${end.toStringAsFixed(fractionDigits)}$suffix',
        style: style,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: begin, end: end),
      duration: duration,
      curve: AppMotion.easeOutQuint,
      builder: (context, v, _) {
        return Text(
          '$prefix${v.toStringAsFixed(fractionDigits)}$suffix',
          style: style,
        );
      },
    );
  }
}

/// Soft shimmer skeleton placeholder.
class PrimeShimmer extends StatefulWidget {
  const PrimeShimmer({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<PrimeShimmer> createState() => _PrimeShimmerState();
}

class _PrimeShimmerState extends State<PrimeShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.enabled) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant PrimeShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.enabled && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || AppMotion.reduce(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final t = _c.value;
            return LinearGradient(
              begin: Alignment(-1.5 + 3 * t, 0),
              end: Alignment(-0.5 + 3 * t, 0),
              colors: [
                AppColors.elevatedSurface,
                AppColors.surfaceSoft,
                AppColors.elevatedSurface,
              ],
              stops: const [0.25, 0.5, 0.75],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Shifts [child] by a fraction of [scrollOffset] for parallax heroes.
class PrimeParallax extends StatelessWidget {
  const PrimeParallax({
    super.key,
    required this.scrollOffset,
    required this.child,
    this.factor = 0.35,
    this.maxShift = 48,
  });

  final double scrollOffset;
  final Widget child;
  final double factor;
  final double maxShift;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduce(context)) return child;
    final dy = (scrollOffset * factor).clamp(-maxShift, maxShift);
    return Transform.translate(offset: Offset(0, dy), child: child);
  }
}
