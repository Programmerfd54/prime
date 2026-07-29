import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../tokens.dart';
import '../../typography.dart';

/// Soft decline / trend sparkline for onboarding problem step.
class PrimeSparkline extends StatelessWidget {
  const PrimeSparkline({
    super.key,
    this.values = const [1.0, 0.85, 0.55, 0.28],
    this.labels = const ['День 1', 'День 2', 'День 3', 'Спад'],
    this.height = 120,
    this.color,
  });

  final List<double> values;
  final List<String> labels;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.coral;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _SparkPainter(values: values, color: accent),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final label in labels)
              Text(label, style: AppTypography.caption),
          ],
        ),
      ],
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1);
      final y = size.height * (1 - values[i].clamp(0.0, 1.0)) * 0.85 +
          size.height * 0.08;
      pts.add(Offset(x, y));
    }

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final curr = pts[i];
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);

    final fill = Path.from(path)
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
            color.withValues(alpha: 0.35),
            color.withValues(alpha: 0.0),
          ],
        ),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (final p in pts) {
      canvas.drawCircle(p, 5, Paint()..color = AppColors.textPrimary);
      canvas.drawCircle(p, 3.2, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      oldDelegate.values != values;
}
