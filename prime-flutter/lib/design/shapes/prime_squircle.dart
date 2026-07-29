import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';

/// Continuous iOS-style superellipse (squircle) shape.
///
/// Unlike [BorderRadius.circular], curvature is continuous at the corners —
/// the visual hallmark of Apple's rounded rectangles.
class PrimeSquircleBorder extends ShapeBorder {
  const PrimeSquircleBorder({
    this.radius = 24,
    this.side = BorderSide.none,
    this.smoothing = 0.6,
  });

  /// Corner radius in logical pixels.
  final double radius;

  /// Optional stroke.
  final BorderSide side;

  /// Corner smoothness 0–1. Apple-like default is ~0.6.
  final double smoothing;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) => PrimeSquircleBorder(
        radius: radius * t,
        side: side.scale(t),
        smoothing: smoothing,
      );

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return squirclePath(rect.deflate(side.width), radius, smoothing: smoothing);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return squirclePath(rect, radius, smoothing: smoothing);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width <= 0) return;
    final path = getOuterPath(rect, textDirection: textDirection);
    canvas.drawPath(path, side.toPaint());
  }
}

/// Cubic control-point offset from a corner arc endpoint, along the tangent.
///
/// A quarter-circle needs `0.5523 * r` — below that the cubic collapses onto
/// the straight chord between the arc endpoints and the corner renders as a
/// 45-degree chamfer. Above it, the corner flattens toward the continuous
/// curvature of Apple's superellipse.
double cornerControlOffset(double r, double smoothing) {
  const circular = 0.5523;
  const superellipse = 0.75;
  final k = circular + (superellipse - circular) * smoothing.clamp(0.0, 1.0);
  return (r * k).clamp(0.0, r);
}

/// Builds a continuous-corner path approximating Apple's squircle.
Path squirclePath(Rect rect, double radius, {double smoothing = 0.6}) {
  final w = rect.width;
  final h = rect.height;
  if (w <= 0 || h <= 0) return Path()..addRect(rect);

  final r = math.min(radius, math.min(w, h) / 2);
  if (r <= 0.5) {
    return Path()..addRect(rect);
  }

  final s = cornerControlOffset(r, smoothing);
  final left = rect.left;
  final top = rect.top;
  final right = rect.right;
  final bottom = rect.bottom;

  final path = Path();
  path.moveTo(left + r, top);

  path.lineTo(right - r, top);
  path.cubicTo(
    right - r + s,
    top,
    right,
    top + r - s,
    right,
    top + r,
  );

  path.lineTo(right, bottom - r);
  path.cubicTo(
    right,
    bottom - r + s,
    right - r + s,
    bottom,
    right - r,
    bottom,
  );

  path.lineTo(left + r, bottom);
  path.cubicTo(
    left + r - s,
    bottom,
    left,
    bottom - r + s,
    left,
    bottom - r,
  );

  path.lineTo(left, top + r);
  path.cubicTo(
    left,
    top + r - s,
    left + r - s,
    top,
    left + r,
    top,
  );

  path.close();
  return path;
}

/// Convenience decoration wrapping [PrimeSquircleBorder].
class PrimeSquircleDecoration extends Decoration {
  const PrimeSquircleDecoration({
    this.color,
    this.gradient,
    this.border,
    this.boxShadow,
    this.radius = 24,
    this.smoothing = 0.6,
  });

  final Color? color;
  final Gradient? gradient;
  final BorderSide? border;
  final List<BoxShadow>? boxShadow;
  final double radius;
  final double smoothing;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _PrimeSquirclePainter(this, onChanged);
  }

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) {
    return squirclePath(rect, radius, smoothing: smoothing);
  }

  @override
  bool hitTest(Size size, Offset position, {TextDirection? textDirection}) {
    return squirclePath(
      Offset.zero & size,
      radius,
      smoothing: smoothing,
    ).contains(position);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PrimeSquircleDecoration &&
        other.color == color &&
        other.gradient == gradient &&
        other.border == border &&
        listEquals(other.boxShadow, boxShadow) &&
        other.radius == radius &&
        other.smoothing == smoothing;
  }

  @override
  int get hashCode => Object.hash(
        color,
        gradient,
        border,
        boxShadow == null ? null : Object.hashAll(boxShadow!),
        radius,
        smoothing,
      );
}

class _PrimeSquirclePainter extends BoxPainter {
  _PrimeSquirclePainter(this.decoration, super.onChanged);

  final PrimeSquircleDecoration decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = offset & size;
    final path = squirclePath(
      rect,
      decoration.radius,
      smoothing: decoration.smoothing,
    );

    if (decoration.boxShadow != null) {
      for (final shadow in decoration.boxShadow!) {
        canvas.drawPath(path.shift(shadow.offset), shadow.toPaint());
      }
    }

    final fill = Paint()..style = PaintingStyle.fill;
    if (decoration.gradient != null) {
      fill.shader = decoration.gradient!.createShader(rect);
    } else if (decoration.color != null) {
      fill.color = decoration.color!;
    } else {
      fill.color = const Color(0x00000000);
    }
    canvas.drawPath(path, fill);

    final side = decoration.border;
    if (side != null && side.style != BorderStyle.none && side.width > 0) {
      canvas.drawPath(path, side.toPaint());
    }
  }
}

/// Clips [child] to a continuous squircle.
class PrimeSquircleClip extends StatelessWidget {
  const PrimeSquircleClip({
    super.key,
    required this.child,
    this.radius = 24,
    this.smoothing = 0.6,
  });

  final Widget child;
  final double radius;
  final double smoothing;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _PrimeSquircleClipper(radius: radius, smoothing: smoothing),
      child: child,
    );
  }
}

class _PrimeSquircleClipper extends CustomClipper<Path> {
  _PrimeSquircleClipper({required this.radius, required this.smoothing});

  final double radius;
  final double smoothing;

  @override
  Path getClip(Size size) =>
      squirclePath(Offset.zero & size, radius, smoothing: smoothing);

  @override
  bool shouldReclip(covariant _PrimeSquircleClipper old) =>
      old.radius != radius || old.smoothing != smoothing;
}
