import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../tokens.dart';
import '../../typography.dart';

/// Large arc progress — emotional carrier for pace / today status.
class PrimeRadialProgress extends StatefulWidget {
  const PrimeRadialProgress({
    super.key,
    required this.progress,
    required this.valueLabel,
    this.caption,
    this.size = 160,
    this.stroke = 14,
    this.color,
    this.trackColor,
    this.animate = true,
  });

  final double progress;
  final String valueLabel;
  final String? caption;
  final double size;
  final double stroke;
  final Color? color;
  final Color? trackColor;
  final bool animate;

  @override
  State<PrimeRadialProgress> createState() => _PrimeRadialProgressState();
}

class _PrimeRadialProgressState extends State<PrimeRadialProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant PrimeRadialProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress && widget.animate) {
      _controller.forward(from: 0);
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

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final p = clamped * _animation.value;
          return CustomPaint(
            painter: _ArcPainter(
              progress: p,
              stroke: widget.stroke,
              accent: accent,
              trackColor: widget.trackColor ??
                  AppColors.primaryContainer.withValues(alpha: 0.55),
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(widget.stroke + 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.valueLabel,
                        style: AppTypography.numeric.copyWith(
                          fontSize: widget.size * 0.22,
                          height: 1.05,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                      if (widget.caption != null && widget.size >= 96) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.caption!,
                          style: AppTypography.caption.copyWith(
                            fontSize: widget.size * 0.08,
                            height: 1.1,
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
          );
        },
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.progress,
    required this.stroke,
    required this.accent,
    required this.trackColor,
  });

  final double progress;
  final double stroke;
  final Color accent;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;
    const start = -math.pi * 0.75;
    const sweep = math.pi * 1.5;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      track,
    );

    if (progress <= 0) return;

    final arc = Paint()
      ..shader = SweepGradient(
        startAngle: start,
        endAngle: start + sweep,
        colors: [accent, accent.withValues(alpha: 0.65), AppColors.mint],
        stops: const [0.0, 0.7, 1.0],
        transform: const GradientRotation(start),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep * progress,
      false,
      arc,
    );

    // Glowing leading edge — soft bloom + sharp cap.
    final angle = start + sweep * progress;
    final tip = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );

    canvas.drawCircle(
      tip,
      stroke * 1.4,
      Paint()
        ..color = accent.withValues(alpha: 0.35)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      tip,
      stroke * 0.85,
      Paint()
        ..color = AppColors.mint.withValues(alpha: 0.45)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4),
    );
    canvas.drawCircle(tip, stroke * 0.55, Paint()..color = AppColors.textPrimary);
    canvas.drawCircle(tip, stroke * 0.32, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}
