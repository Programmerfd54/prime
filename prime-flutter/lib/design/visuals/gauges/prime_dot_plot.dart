import 'package:flutter/material.dart';
import 'package:prime/design/tokens.dart';

/// 30-day dot grid with accent curve overlay — fitness "Steps" style.
class PrimeDotPlot extends StatelessWidget {
  const PrimeDotPlot({
    super.key,
    required this.values,
    this.height = 88,
    this.color,
    this.showCurve = true,
  });

  /// Normalized daily values (0–1), up to 30 entries.
  final List<double> values;
  final double height;
  final Color? color;

  /// Draw a polyline through peak dots.
  final bool showCurve;

  static const _columns = 10;
  static const _rows = 3;
  static const _maxDays = 30;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary;
    final data = values.take(_maxDays).map((v) => v.clamp(0.0, 1.0)).toList();

    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _DotPlotPainter(
          values: data,
          color: accent,
          showCurve: showCurve,
          columns: _columns,
          rows: _rows,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DotPlotPainter extends CustomPainter {
  _DotPlotPainter({
    required this.values,
    required this.color,
    required this.showCurve,
    required this.columns,
    required this.rows,
  });

  final List<double> values;
  final Color color;
  final bool showCurve;
  final int columns;
  final int rows;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const hPad = 2.0;
    const vPad = 4.0;
    final cellW = (size.width - hPad * 2) / columns;
    final cellH = (size.height - vPad * 2) / rows;
    const dotR = 3.2;

    final centers = <Offset>[];
    for (var i = 0; i < values.length && i < columns * rows; i++) {
      final col = i % columns;
      final row = i ~/ columns;
      final cx = hPad + cellW * col + cellW / 2;
      final cy = vPad + cellH * row + cellH / 2;
      centers.add(Offset(cx, cy));

      final v = values[i];
      final alpha = 0.18 + v * 0.82;
      canvas.drawCircle(
        Offset(cx, cy),
        dotR,
        Paint()..color = AppColors.borderStrong.withValues(alpha: 0.35),
      );
      if (v > 0.02) {
        canvas.drawCircle(
          Offset(cx, cy),
          dotR + v * 1.2,
          Paint()..color = color.withValues(alpha: alpha * 0.25),
        );
        canvas.drawCircle(
          Offset(cx, cy),
          dotR,
          Paint()..color = color.withValues(alpha: alpha),
        );
      }
    }

    if (!showCurve || centers.length < 2) return;

    final peakIndices = <int>[];
    for (var i = 0; i < values.length; i++) {
      if (values[i] >= 0.35) peakIndices.add(i);
    }
    if (peakIndices.length < 2) {
      peakIndices.clear();
      for (var i = 0; i < values.length; i++) {
        if (values[i] > 0) peakIndices.add(i);
      }
    }
    if (peakIndices.length < 2) return;

    final pts = peakIndices.map((i) => centers[i]).toList();
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final curr = pts[i];
      final cp1 = Offset(prev.dx + (curr.dx - prev.dx) * 0.45, prev.dy);
      final cp2 = Offset(curr.dx - (curr.dx - prev.dx) * 0.45, curr.dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, curr.dx, curr.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );

    for (final i in peakIndices) {
      final p = centers[i];
      canvas.drawCircle(
        p,
        dotR + 1.5,
        Paint()..color = color.withValues(alpha: 0.3),
      );
      canvas.drawCircle(p, dotR + 0.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _DotPlotPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
