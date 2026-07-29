import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';

/// Soft ambient orbs — editorial dark wellness backdrop.
class AmbientCanvas extends StatelessWidget {
  const AmbientCanvas({
    super.key,
    required this.child,
    this.intensity = 1,
  });

  final Widget child;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _AmbientPainter(intensity: intensity),
          size: Size.infinite,
        ),
        child,
      ],
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({required this.intensity});

  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    void orb(Offset c, double r, Color color) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.16 * intensity),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, paint);
    }

    final base = Paint()..color = AppColors.background;
    canvas.drawRect(Offset.zero & size, base);

    orb(Offset(size.width * 0.85, size.height * 0.08), size.width * 0.45,
        AppColors.premiumDarkViolet);
    orb(Offset(size.width * 0.12, size.height * 0.22), size.width * 0.32,
        AppColors.primaryDeep);
    orb(Offset(size.width * 0.7, size.height * 0.55), size.width * 0.28,
        AppColors.mutedViolet);
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) =>
      oldDelegate.intensity != intensity;
}

/// Radial progress — premium wellness module.
class AppProgressRing extends StatelessWidget {
  const AppProgressRing({
    super.key,
    required this.progress,
    required this.label,
    this.subtitle,
    this.size = 88,
    this.stroke = 7,
    this.color,
    this.center,
  });

  final double progress;
  final String label;
  final String? subtitle;
  final double size;
  final double stroke;
  final Color? color;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary;
    final clamped = progress.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
              progress: clamped,
              stroke: stroke,
              accent: accent,
            ),
          ),
          if (center != null)
            center!
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: size * 0.22,
                      height: 1,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: size * 0.11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.stroke,
    required this.accent,
  });

  final double progress;
  final double stroke;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;
    final track = Paint()
      ..color = AppColors.primaryContainer.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final arc = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [accent, accent.withValues(alpha: 0.55)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
