import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:prime/design/motion.dart';
import 'package:prime/design/tokens.dart';
import 'package:prime/design/typography.dart';

/// Semi-circular segmented arc — nutrition-style calorie ring.
class PrimeSegmentedArc extends StatefulWidget {
  const PrimeSegmentedArc({
    super.key,
    required this.progress,
    required this.valueLabel,
    this.caption,
    this.segments = 24,
    this.size = 160,
    this.color,
  });

  final double progress;
  final String valueLabel;
  final String? caption;
  final int segments;
  final double size;
  final Color? color;

  @override
  State<PrimeSegmentedArc> createState() => _PrimeSegmentedArcState();
}

class _PrimeSegmentedArcState extends State<PrimeSegmentedArc>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.slow,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.standard,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (AppMotion.reduce(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void didUpdateWidget(covariant PrimeSegmentedArc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      if (AppMotion.reduce(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.color ?? AppColors.primary;
    final clamped = widget.progress.clamp(0.0, 1.0);
    final arcHeight = widget.size * 0.58;

    return SizedBox(
      width: widget.size,
      height: arcHeight + (widget.caption != null ? 8 : 0),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          return CustomPaint(
            painter: _SegmentedArcPainter(
              progress: clamped * _animation.value,
              segments: widget.segments,
              accent: accent,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: arcHeight * 0.72,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: widget.size * 0.08),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.valueLabel,
                              style: AppTypography.numeric.copyWith(
                                fontSize: widget.size * 0.2,
                                height: 1.05,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                            ),
                            if (widget.caption != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.caption!,
                                style: AppTypography.caption.copyWith(
                                  fontSize: widget.size * 0.075,
                                  color: AppColors.textMuted,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SegmentedArcPainter extends CustomPainter {
  _SegmentedArcPainter({
    required this.progress,
    required this.segments,
    required this.accent,
  });

  final double progress;
  final int segments;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.92);
    final radius = size.width * 0.38;
    const start = math.pi;
    const sweep = math.pi;
    final filledCount = (segments * progress).floor();
    final partial = segments * progress - filledCount;

    final gap = 0.06;
    final segSweep = (sweep - gap * segments) / segments;
    const stroke = 10.0;

    for (var i = 0; i < segments; i++) {
      final angle = start + i * (segSweep + gap);
      final isFilled = i < filledCount;
      final isPartial = i == filledCount && partial > 0;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;

      if (isFilled) {
        paint.color = accent;
      } else if (isPartial) {
        paint.color = accent.withValues(alpha: 0.35 + partial * 0.65);
      } else {
        paint.color = AppColors.primaryContainer.withValues(alpha: 0.45);
      }

      final segAngle = isPartial ? segSweep * partial : segSweep;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        segAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentedArcPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.segments != segments ||
      oldDelegate.accent != accent;
}
