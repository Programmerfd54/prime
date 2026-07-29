import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:prime/design/tokens.dart';

/// Smooth filled area / wave chart with gradient fill and stroke.
class PrimeAreaWave extends StatelessWidget {
  const PrimeAreaWave({
    super.key,
    required this.values,
    this.height = 72,
    this.color,
  });

  final List<double> values;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary;
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _AreaWavePainter(values: values, color: accent),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _AreaWavePainter extends CustomPainter {
  _AreaWavePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final pts = _catmullRomPoints(values, size);
    if (pts.length < 2) return;

    final line = _catmullRomPath(pts);
    final fill = Path.from(line)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, size.height),
          [
            color.withValues(alpha: 0.42),
            color.withValues(alpha: 0.06),
          ],
        ),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  List<Offset> _catmullRomPoints(List<double> data, Size size) {
    final pts = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final x = data.length == 1
          ? size.width / 2
          : size.width * i / (data.length - 1);
      final y = size.height * (1 - data[i].clamp(0.0, 1.0)) * 0.82 +
          size.height * 0.1;
      pts.add(Offset(x, y));
    }
    return pts;
  }

  Path _catmullRomPath(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    if (pts.length == 2) {
      path.lineTo(pts.last.dx, pts.last.dy);
      return path;
    }

    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = i > 0 ? pts[i - 1] : pts[i];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i + 2 < pts.length ? pts[i + 2] : pts[i + 1];

      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _AreaWavePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
