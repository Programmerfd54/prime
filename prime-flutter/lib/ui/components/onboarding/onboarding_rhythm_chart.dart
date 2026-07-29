import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../../../design/typography.dart';

/// Dual-line rhythm chart: decline without system vs. stable with PRIME.
///
/// Curves react to [quitCount] (break day + depth) and [attemptCount]
/// (ghost past-attempt curves).
class OnboardingRhythmChart extends StatefulWidget {
  const OnboardingRhythmChart({
    super.key,
    this.quitCount = '2',
    this.attemptCount = '2-3',
    this.height = 148,
  });

  final String quitCount;
  final String attemptCount;
  final double height;

  /// Day where solo habit usually breaks (1-indexed).
  static int breakDayFor(String quitCount) => switch (quitCount) {
        '1' => 12,
        '3+' => 5,
        _ => 8,
      };

  /// Floor value at day 30 without a system.
  static double floorFor(String quitCount) => switch (quitCount) {
        '1' => 0.45,
        '3+' => 0.08,
        _ => 0.25,
      };

  /// How many ghost "past attempt" curves to draw.
  static int ghostCountFor(String attemptCount) => switch (attemptCount) {
        '1' => 1,
        '4+' => 4,
        _ => 2,
      };

  static List<double> declineCurve({
    required int breakDay,
    required double floor,
    int points = 30,
  }) {
    final values = <double>[];
    for (var i = 0; i < points; i++) {
      final day = i + 1;
      if (day <= breakDay) {
        // Soft decline before the drop.
        final t = (day - 1) / math.max(1, breakDay - 1);
        values.add(1.0 - 0.12 * t);
      } else {
        final t = (day - breakDay) / math.max(1, points - breakDay);
        final eased = Curves.easeInCubic.transform(t.clamp(0.0, 1.0));
        values.add(0.88 - (0.88 - floor) * eased);
      }
    }
    return values;
  }

  static List<double> primeCurve({int points = 30}) {
    final values = <double>[];
    for (var i = 0; i < points; i++) {
      final day = i + 1;
      // Slight dip around days 5–7 then recovery — shows the team effect.
      if (day < 5) {
        values.add(1.0 - 0.02 * ((day - 1) / 4));
      } else if (day <= 8) {
        final t = (day - 5) / 3;
        values.add(0.98 - 0.08 * math.sin(t * math.pi / 2));
      } else {
        final t = (day - 8) / math.max(1, points - 8);
        values.add(0.90 + 0.06 * Curves.easeOut.transform(t.clamp(0.0, 1.0)));
      }
    }
    return values;
  }

  /// Ghost curves that break early — visualise past failed attempts.
  static List<List<double>> ghostCurves({
    required int count,
    required int breakDay,
    int points = 30,
  }) {
    if (count <= 0) return const [];
    final ghosts = <List<double>>[];
    for (var g = 0; g < count; g++) {
      final ghostBreak = math.max(3, breakDay - 2 - g);
      final values = <double>[];
      for (var i = 0; i < points; i++) {
        final day = i + 1;
        if (day > ghostBreak + 3) {
          values.add(double.nan); // truncated
          continue;
        }
        if (day <= ghostBreak) {
          final t = (day - 1) / math.max(1, ghostBreak - 1);
          values.add(1.0 - 0.15 * t - 0.04 * g);
        } else {
          final t = (day - ghostBreak) / 3;
          values.add((0.85 - 0.04 * g) * (1 - Curves.easeIn.transform(t)));
        }
      }
      ghosts.add(values);
    }
    return ghosts;
  }

  @override
  State<OnboardingRhythmChart> createState() => _OnboardingRhythmChartState();
}

class _OnboardingRhythmChartState extends State<OnboardingRhythmChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  int get _breakDay => OnboardingRhythmChart.breakDayFor(widget.quitCount);
  double get _floor => OnboardingRhythmChart.floorFor(widget.quitCount);
  int get _ghostCount =>
      OnboardingRhythmChart.ghostCountFor(widget.attemptCount);

  List<double> get _without => OnboardingRhythmChart.declineCurve(
        breakDay: _breakDay,
        floor: _floor,
      );

  List<double> get _withPrime => OnboardingRhythmChart.primeCurve();

  List<List<double>> get _ghosts => OnboardingRhythmChart.ghostCurves(
        count: _ghostCount,
        breakDay: _breakDay,
      );

  String get _readout {
    final pct = (_floor * 100).round();
    return 'Срыв обычно на $_breakDay-й день · дошли бы до $pct%';
  }

  static const _labels = ['День 1', 'День 7', 'День 14', 'День 30'];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant OnboardingRhythmChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quitCount != widget.quitCount ||
        oldWidget.attemptCount != widget.attemptCount) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.heroSurfaceStart.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ритм без системы vs с ПРАЙМ',
            style: AppTypography.caption.copyWith(color: AppColors.primarySoft),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _readout,
            key: const ValueKey('rhythm-readout'),
            style: AppTypography.bodySecondary.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: widget.height,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _RhythmPainter(
                    without: _without,
                    withPrime: _withPrime,
                    ghosts: _ghosts,
                    breakDay: _breakDay,
                    progress: Curves.easeOutCubic.transform(_controller.value),
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final label in _labels)
                Text(label, style: AppTypography.caption),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xxs,
            children: [
              _Legend(
                color: AppColors.coral,
                label: 'Без системы',
                dashed: true,
              ),
              _Legend(color: AppColors.primary, label: 'С ПРАЙМ'),
              if (_ghostCount > 0)
                _Legend(
                  color: AppColors.textSecondary,
                  label: _ghostCount == 1
                      ? 'Прошлая попытка'
                      : 'Прошлые попытки ($_ghostCount)',
                  dashed: true,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Обычно ритм ломается на $_breakDay-й день — там и нужна команда',
            style: AppTypography.bodySecondary,
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(18, 4),
          painter: _LegendLinePainter(color: color, dashed: dashed),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}

class _LegendLinePainter extends CustomPainter {
  _LegendLinePainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    if (!dashed) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
      return;
    }
    const dash = 3.0;
    const gap = 2.5;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dash, size.width), y),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _LegendLinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashed != dashed;
}

class _RhythmPainter extends CustomPainter {
  _RhythmPainter({
    required this.without,
    required this.withPrime,
    required this.ghosts,
    required this.breakDay,
    required this.progress,
  });

  final List<double> without;
  final List<double> withPrime;
  final List<List<double>> ghosts;
  final int breakDay;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final ghost in ghosts) {
      final pts = _points(ghost, size);
      if (pts.length < 2) continue;
      _drawLine(
        canvas,
        size,
        pts,
        AppColors.textSecondary.withValues(alpha: 0.45),
        dashed: true,
        strokeWidth: 1.6,
        drawDots: false,
      );
    }

    final withoutPts = _points(without, size);
    final withPts = _points(withPrime, size);

    _drawLine(
      canvas,
      size,
      withoutPts,
      AppColors.coral,
      dashed: true,
      fill: true,
    );
    _drawLine(
      canvas,
      size,
      withPts,
      AppColors.primary,
      glow: true,
    );

    // Drop marker at breakDay (1-indexed → index breakDay-1).
    final dropIndex = (breakDay - 1).clamp(0, withoutPts.length - 1);
    if (progress > 0.35 && withoutPts.isNotEmpty) {
      final drop = withoutPts[dropIndex];
      final markerPaint = Paint()
        ..color = AppColors.coral.withValues(alpha: 0.9);
      canvas.drawCircle(drop, 5.5, markerPaint);
      canvas.drawCircle(drop, 3.2, Paint()..color = AppColors.textPrimary);

      final tp = TextPainter(
        text: TextSpan(
          text: 'здесь чаще бросают',
          style: AppTypography.caption.copyWith(
            color: AppColors.coral,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width * 0.5);
      final labelX = (drop.dx - tp.width / 2).clamp(0.0, size.width - tp.width);
      final labelY = (drop.dy - 22).clamp(0.0, size.height - tp.height);
      tp.paint(canvas, Offset(labelX, labelY));
    }
  }

  List<Offset> _points(List<double> values, Size size) {
    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v.isNaN) break;
      final x = values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1);
      final y =
          size.height * (1 - v.clamp(0.0, 1.0)) * 0.82 + size.height * 0.1;
      pts.add(Offset(x, y));
    }
    return pts;
  }

  Path _smoothPath(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final curr = pts[i];
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }

  void _drawLine(
    Canvas canvas,
    Size size,
    List<Offset> pts,
    Color color, {
    bool dashed = false,
    bool glow = false,
    bool fill = false,
    bool drawDots = true,
    double strokeWidth = 3,
  }) {
    if (pts.length < 2) return;
    final full = _smoothPath(pts);

    // CanvasKit PathMetrics.extractPath can stack-overflow on web Beziers —
    // reveal the curve via a width clip instead.
    if (kIsWeb) {
      final t = progress.clamp(0.0, 1.0);
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width * t, size.height));
      if (fill && t > 0.1) {
        final fillPath = Path.from(full)
          ..lineTo(pts.last.dx, size.height)
          ..lineTo(pts.first.dx, size.height)
          ..close();
        canvas.drawPath(
          fillPath,
          Paint()
            ..shader = ui.Gradient.linear(
              const Offset(0, 0),
              Offset(0, size.height),
              [
                color.withValues(alpha: 0.22),
                color.withValues(alpha: 0.0),
              ],
            ),
        );
      }
      if (glow) {
        canvas.drawPath(
          full,
          Paint()
            ..color = color.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      canvas.drawPath(
        full,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.restore();
      return;
    }

    final metrics = full.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final total = metrics.fold<double>(0, (s, m) => s + m.length);
    final visible = total * progress.clamp(0.0, 1.0);

    final visiblePath = Path();
    var remaining = visible;
    for (final metric in metrics) {
      if (remaining <= 0) break;
      final extract = math.min(remaining, metric.length);
      visiblePath.addPath(metric.extractPath(0, extract), Offset.zero);
      remaining -= extract;
    }

    if (fill && progress > 0.1) {
      final endIndex = math.max(
        0,
        math.min(pts.length - 1, (pts.length * progress).ceil() - 1),
      );
      final fillPath = Path.from(visiblePath)
        ..lineTo(pts[endIndex].dx, size.height)
        ..lineTo(pts.first.dx, size.height)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(0, 0),
            Offset(0, size.height),
            [
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.0),
            ],
          ),
      );
    }

    if (glow) {
      canvas.drawPath(
        visiblePath,
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (dashed) {
      for (final metric in metrics) {
        var d = 0.0;
        const dash = 7.0;
        const gap = 5.0;
        final maxLen = math.min(metric.length, visible);
        while (d < maxLen) {
          final end = math.min(d + dash, maxLen);
          canvas.drawPath(metric.extractPath(d, end), stroke);
          d += dash + gap;
        }
      }
    } else {
      canvas.drawPath(visiblePath, stroke);
    }

    if (!drawDots) return;
    // Only a few end markers — not all 30.
    final markers = {0, pts.length ~/ 3, (pts.length * 2) ~/ 3, pts.length - 1};
    for (final i in markers) {
      if (i < 0 || i >= pts.length) continue;
      final threshold = i / (pts.length - 1);
      if (progress < threshold) continue;
      canvas.drawCircle(pts[i], 4.5, Paint()..color = AppColors.textPrimary);
      canvas.drawCircle(pts[i], 2.8, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _RhythmPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.breakDay != breakDay ||
      !listEquals(oldDelegate.without, without) ||
      !listEquals(oldDelegate.withPrime, withPrime) ||
      oldDelegate.ghosts.length != ghosts.length;
}
