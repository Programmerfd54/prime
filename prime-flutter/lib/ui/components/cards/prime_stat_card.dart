import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:prime/design/motion.dart';
import 'package:prime/design/tokens.dart';
import 'package:prime/design/typography.dart';
import 'package:prime/ui/kit/tokens/kit_surfaces.dart';

/// Metric card with animated value, optional sparkline, and delta pill.
class PrimeStatCard extends StatelessWidget {
  const PrimeStatCard({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.sparkline,
    this.onTap,
    this.suffix = '',
    this.fractionDigits = 0,
  });

  final String label;
  final num value;
  final num? delta;
  final List<double>? sparkline;
  final VoidCallback? onTap;
  final String suffix;
  final int fractionDigits;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: kitSurfaceDecoration(context, PrimeSurfaceLevel.solid,
          radius: AppRadius.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: PrimeAnimatedNumber(
                  value: value,
                  suffix: suffix,
                  fractionDigits: fractionDigits,
                  style: AppTypography.numeric,
                ),
              ),
              if (delta != null) _DeltaPill(delta: delta!),
            ],
          ),
          if (sparkline != null && sparkline!.length >= 2) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 36,
              child: _MicroSparkline(values: sparkline!),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: body,
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.delta});

  final num delta;

  @override
  Widget build(BuildContext context) {
    final positive = delta >= 0;
    final color = positive ? AppColors.success : AppColors.coral;
    final arrow = positive ? '↑' : '↓';
    final text = '«$arrow${delta.abs().toStringAsFixed(1)}%»';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontFeatures: const [ui.FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _MicroSparkline extends StatelessWidget {
  const _MicroSparkline({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MicroSparklinePainter(values: values),
      child: const SizedBox.expand(),
    );
  }
}

class _MicroSparklinePainter extends CustomPainter {
  _MicroSparklinePainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 0.0001 ? 1.0 : (maxV - minV);

    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final norm = (values[i] - minV) / range;
      final y = size.height * (1 - norm) * 0.82 + size.height * 0.1;
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

    final accent = values.last >= values.first
        ? AppColors.success
        : AppColors.coral;

    final fill = Path.from(path)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(0, size.height),
          [
            accent.withValues(alpha: 0.28),
            accent.withValues(alpha: 0.0),
          ],
        ),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MicroSparklinePainter oldDelegate) =>
      oldDelegate.values != values;
}
