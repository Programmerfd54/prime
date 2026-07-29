import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../tokens.dart';
import '../../../ui/components/profile/app_avatar.dart';

enum AvatarRingMode { none, online, progress, team }

/// Avatar with gradient ring for online / progress / team status.
class PrimeAvatarRing extends StatelessWidget {
  const PrimeAvatarRing({
    super.key,
    required this.photoUrl,
    this.name,
    this.radius = 28,
    this.mode = AvatarRingMode.none,
    this.progress = 0,
    this.onTap,
  });

  final String? photoUrl;
  final String? name;
  final double radius;
  final AvatarRingMode mode;
  final double progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ringWidth = math.max(2.5, radius * 0.12);
    final outer = radius + ringWidth + 2;

    Widget child = AppAvatar(
      photoUrl: photoUrl,
      name: name,
      radius: radius,
      onTap: onTap,
    );

    if (mode == AvatarRingMode.none) return child;

    return SizedBox(
      width: outer * 2,
      height: outer * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(outer * 2),
            painter: _RingPainter(
              mode: mode,
              progress: progress.clamp(0.0, 1.0),
              stroke: ringWidth,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.mode,
    required this.progress,
    required this.stroke,
  });

  final AvatarRingMode mode;
  final double progress;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = (size.shortestSide - stroke) / 2;

    final track = Paint()
      ..color = AppColors.primaryContainer.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(c, r, track);

    final colors = switch (mode) {
      AvatarRingMode.online => [AppColors.mint, AppColors.success],
      AvatarRingMode.progress => [AppColors.primary, AppColors.primaryBright],
      AvatarRingMode.team => [AppColors.primarySoft, AppColors.coral],
      AvatarRingMode.none => [AppColors.primary, AppColors.primary],
    };

    final sweep = mode == AvatarRingMode.online
        ? 2 * math.pi
        : 2 * math.pi * (progress <= 0 ? 0.08 : progress);

    final paint = Paint()
      ..shader = SweepGradient(
        colors: colors,
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
      ).createShader(Rect.fromCircle(center: c, radius: r))
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      sweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.mode != mode;
}
