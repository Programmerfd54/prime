import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:prime/design/shapes/prime_squircle.dart';

/// Probe point on the corner diagonal, at [fraction] of the radius from the
/// corner arc's centre of curvature, heading toward the corner itself.
///
/// The straight chord between the two arc endpoints sits at `1/sqrt(2)`
/// (~0.707). Anything beyond that is inside a curved corner but outside a
/// chamfer, which makes it a clean discriminator between the two.
Offset _topRightProbe(Rect rect, double r, double fraction) {
  final centre = Offset(rect.right - r, rect.top + r);
  final unit = 1 / math.sqrt2;
  return centre + Offset(unit, -unit) * (r * fraction);
}

void main() {
  const r = 40.0;
  final rect = const Rect.fromLTWH(0, 0, 200, 200);
  final chordFraction = 1 / math.sqrt2;

  group('cornerControlOffset', () {
    test('reproduces a circular arc at smoothing 0', () {
      expect(cornerControlOffset(r, 0), closeTo(r * 0.5523, 0.001));
    });

    test('never falls below the circular constant', () {
      for (final s in [0.0, 0.25, 0.5, 0.6, 0.75, 1.0]) {
        expect(
          cornerControlOffset(r, s),
          greaterThanOrEqualTo(r * 0.5523 - 0.001),
          reason: 'smoothing $s collapses the corner toward a chamfer',
        );
      }
    });

    test('grows with smoothing but stays within the radius', () {
      expect(cornerControlOffset(r, 1), greaterThan(cornerControlOffset(r, 0)));
      expect(cornerControlOffset(r, 1), lessThanOrEqualTo(r));
    });
  });

  group('squirclePath corner curvature', () {
    test('bulges past the chamfer chord', () {
      final path = squirclePath(rect, r);
      // 0.85r is inside a circular corner (<1.0) and outside the chord
      // (>0.707), so a chamfered corner cannot contain it.
      final probe = _topRightProbe(rect, r, 0.85);
      expect(
        path.contains(probe),
        isTrue,
        reason: 'corner is flatter than a circular arc — rendering as a bevel',
      );
    });

    test('holds at every smoothing value', () {
      for (final s in [0.0, 0.3, 0.6, 1.0]) {
        final path = squirclePath(rect, r, smoothing: s);
        expect(
          path.contains(_topRightProbe(rect, r, 0.8)),
          isTrue,
          reason: 'smoothing $s produced a chamfered corner',
        );
      }
    });

    test('still excludes the sharp corner point', () {
      final path = squirclePath(rect, r);
      expect(path.contains(Offset(rect.right, rect.top)), isFalse);
    });

    test('chord midpoint stays inside, confirming the probe is meaningful', () {
      final path = squirclePath(rect, r);
      // Just inside the chord — true for both a chamfer and a curve, so this
      // guards the probe geometry rather than the corner shape.
      expect(
        path.contains(_topRightProbe(rect, r, chordFraction - 0.05)),
        isTrue,
      );
    });

    test('applies to all four corners', () {
      final path = squirclePath(rect, r);
      final unit = 1 / math.sqrt2;
      final probes = <Offset>[
        Offset(rect.left + r, rect.top + r) + Offset(-unit, -unit) * (r * 0.85),
        Offset(rect.right - r, rect.top + r) + Offset(unit, -unit) * (r * 0.85),
        Offset(rect.right - r, rect.bottom - r) +
            Offset(unit, unit) * (r * 0.85),
        Offset(rect.left + r, rect.bottom - r) +
            Offset(-unit, unit) * (r * 0.85),
      ];
      for (final probe in probes) {
        expect(path.contains(probe), isTrue, reason: 'chamfer at $probe');
      }
    });

    test('degenerates to a rect only at a negligible radius', () {
      final path = squirclePath(rect, 0.4);
      expect(path.contains(Offset(rect.right, rect.top)), isTrue);
    });

    test('an actual bevel fails the probe, so the probe is not vacuous', () {
      // Straight cuts across all four corners — what the broken control-point
      // offset used to render. If this ever contains the probe, the assertions
      // above prove nothing.
      final bevel = Path()
        ..moveTo(rect.left + r, rect.top)
        ..lineTo(rect.right - r, rect.top)
        ..lineTo(rect.right, rect.top + r)
        ..lineTo(rect.right, rect.bottom - r)
        ..lineTo(rect.right - r, rect.bottom)
        ..lineTo(rect.left + r, rect.bottom)
        ..lineTo(rect.left, rect.bottom - r)
        ..lineTo(rect.left, rect.top + r)
        ..close();
      expect(bevel.contains(_topRightProbe(rect, r, 0.85)), isFalse);
      expect(squirclePath(rect, r).contains(_topRightProbe(rect, r, 0.85)),
          isTrue);
    });
  });
}
