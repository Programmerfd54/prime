// Diagnostic, not a test baseline.
//
// Renders the corner geometry so the chamfer fix can be checked by eye:
//   flutter test test/tools/shape_probe.dart
// Writes build/shape_probe.png
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:prime/design/shapes/prime_squircle.dart';

const _bg = ui.Color(0xFF12101A);
const _fill = ui.Color(0xFF2A2535);
const _brand = ui.Color(0xFF8B5CF6);
const _chord = ui.Color(0xFFE86F78);

void main() {
  test('render shape probe', () async {
    const w = 900.0;
    const h = 420.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, const ui.Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, w, h),
      ui.Paint()..color = _bg,
    );

    final fillPaint = ui.Paint()..color = _fill;
    final strokePaint = ui.Paint()
      ..color = _brand
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2;
    final chordPaint = ui.Paint()
      ..color = _chord
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1;

    // Row 1: radii sweep at default smoothing.
    const radii = [12.0, 16.0, 20.0, 24.0, 28.0, 32.0];
    for (var i = 0; i < radii.length; i++) {
      final rect = ui.Rect.fromLTWH(30 + i * 140, 40, 120, 120);
      final path = squirclePath(rect, radii[i]);
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);
      // Red line = where a chamfer would cut. The corner must bulge past it.
      final r = radii[i];
      canvas.drawLine(
        ui.Offset(rect.right - r, rect.top),
        ui.Offset(rect.right, rect.top + r),
        chordPaint,
      );
    }

    // Row 2: smoothing sweep at a fixed radius.
    const smoothings = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0];
    for (var i = 0; i < smoothings.length; i++) {
      final rect = ui.Rect.fromLTWH(30 + i * 140, 220, 120, 120);
      final path = squirclePath(rect, 28, smoothing: smoothings[i]);
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);
      canvas.drawLine(
        ui.Offset(rect.right - 28, rect.top),
        ui.Offset(rect.right, rect.top + 28),
        chordPaint,
      );
    }

    // Dock lozenge comparison: stadium vs the old pill-squircle.
    final lozenge = ui.Rect.fromLTWH(w - 200, 220, 56, 44);
    canvas.drawPath(
      squirclePath(lozenge, 999),
      ui.Paint()..color = _brand.withValues(alpha: 0.5),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.toInt(), h.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('build/shape_probe.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes!.buffer.asUint8List());

    // Sanity: the drawn corners really do clear the chord.
    final probeRect = const ui.Rect.fromLTWH(0, 0, 120, 120);
    const r = 28.0;
    final centre = ui.Offset(probeRect.right - r, probeRect.top + r);
    final unit = 1 / math.sqrt2;
    final probe = centre + ui.Offset(unit, -unit) * (r * 0.85);
    expect(squirclePath(probeRect, r).contains(probe), isTrue);

    // ignore: avoid_print
    print('wrote ${out.absolute.path}');
  });
}
