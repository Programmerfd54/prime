import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:prime/design/tokens.dart';
import 'package:prime/design/typography.dart';

typedef PrimeRadarAxis = ({String label, double progress});

/// Simple radar / spider chart for milestone-style team progress.
class PrimeRadarMilestones extends StatelessWidget {
  const PrimeRadarMilestones({
    super.key,
    required this.axes,
    this.size = 200,
    this.color,
    this.showLabels = true,
  });

  final List<PrimeRadarAxis> axes;
  final double size;
  final Color? color;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    if (axes.isEmpty) return const SizedBox.shrink();
    final accent = color ?? AppColors.primary;
    final labelPad = showLabels ? 28.0 : 0.0;
    final canvasSize = size + labelPad * 2;

    return SizedBox(
      width: canvasSize,
      height: canvasSize,
      child: CustomPaint(
        painter: _RadarPainter(
          axes: axes,
          accent: accent,
          showLabels: showLabels,
          labelPad: labelPad,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.axes,
    required this.accent,
    required this.showLabels,
    required this.labelPad,
  });

  final List<PrimeRadarAxis> axes;
  final Color accent;
  final bool showLabels;
  final double labelPad;

  @override
  void paint(Canvas canvas, Size size) {
    final n = axes.length;
    if (n < 3) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - labelPad;
    final angleStep = math.pi * 2 / n;
    const startAngle = -math.pi / 2;

    for (var ring = 1; ring <= 4; ring++) {
      final r = radius * ring / 4;
      final ringPath = Path();
      for (var i = 0; i < n; i++) {
        final angle = startAngle + i * angleStep;
        final pt = Offset(
          center.dx + r * math.cos(angle),
          center.dy + r * math.sin(angle),
        );
        if (i == 0) {
          ringPath.moveTo(pt.dx, pt.dy);
        } else {
          ringPath.lineTo(pt.dx, pt.dy);
        }
      }
      ringPath.close();
      canvas.drawPath(
        ringPath,
        Paint()
          ..color = AppColors.borderStrong.withValues(alpha: ring == 4 ? 0.35 : 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    for (var i = 0; i < n; i++) {
      final angle = startAngle + i * angleStep;
      final end = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(
        center,
        end,
        Paint()
          ..color = AppColors.borderStrong.withValues(alpha: 0.22)
          ..strokeWidth = 1,
      );
    }

    final dataPath = Path();
    for (var i = 0; i < n; i++) {
      final angle = startAngle + i * angleStep;
      final p = axes[i].progress.clamp(0.0, 1.0);
      final pt = Offset(
        center.dx + radius * p * math.cos(angle),
        center.dy + radius * p * math.sin(angle),
      );
      if (i == 0) {
        dataPath.moveTo(pt.dx, pt.dy);
      } else {
        dataPath.lineTo(pt.dx, pt.dy);
      }
    }
    dataPath.close();

    canvas.drawPath(
      dataPath,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          [
            accent.withValues(alpha: 0.35),
            accent.withValues(alpha: 0.12),
          ],
        ),
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = accent.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    for (var i = 0; i < n; i++) {
      final angle = startAngle + i * angleStep;
      final p = axes[i].progress.clamp(0.0, 1.0);
      final pt = Offset(
        center.dx + radius * p * math.cos(angle),
        center.dy + radius * p * math.sin(angle),
      );
      canvas.drawCircle(pt, 3.5, Paint()..color = accent);
      canvas.drawCircle(pt, 2, Paint()..color = AppColors.textPrimary);

      if (showLabels) {
        final labelPt = Offset(
          center.dx + (radius + 16) * math.cos(angle),
          center.dy + (radius + 16) * math.sin(angle),
        );
        _drawLabel(canvas, axes[i].label, labelPt, angle);
      }
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset anchor, double angle) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: AppTypography.caption.copyWith(
          fontSize: 10,
          color: AppColors.textMuted,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 72);

    var dx = anchor.dx - tp.width / 2;
    var dy = anchor.dy - tp.height / 2;
    if (angle.abs() < 0.2) {
      dy -= tp.height * 0.2;
    } else if ((angle - math.pi).abs() < 0.2 || (angle + math.pi).abs() < 0.2) {
      dy += tp.height * 0.2;
    }

    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.axes != axes || oldDelegate.accent != accent;
}
