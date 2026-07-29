import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../core/mood/mood_state.dart';
import '../../../design/motion.dart';
import '../../../design/tokens.dart';

/// Morphing blob character — shape and tint follow [MoodKind].
class MoodCreature extends StatefulWidget {
  const MoodCreature({
    super.key,
    required this.mood,
    this.size = 160,
  });

  final MoodKind mood;
  final double size;

  @override
  State<MoodCreature> createState() => _MoodCreatureState();
}

class _MoodCreatureState extends State<MoodCreature>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late MoodKind _fromMood;
  late MoodKind _toMood;

  @override
  void initState() {
    super.initState();
    _fromMood = widget.mood;
    _toMood = widget.mood;
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.slow,
    )..value = 1;
  }

  @override
  void didUpdateWidget(covariant MoodCreature oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      _fromMood = oldWidget.mood;
      _toMood = widget.mood;
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
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _BlobPainter(
              t: Curves.easeInOutCubic.transform(_controller.value),
              from: _fromMood,
              to: _toMood,
            ),
          );
        },
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter({
    required this.t,
    required this.from,
    required this.to,
  });

  final double t;
  final MoodKind from;
  final MoodKind to;

  static const _pointCount = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = size.shortestSide * 0.34;

    final fromRadii = _radiiFor(from);
    final toRadii = _radiiFor(to);
    final radii = List<double>.generate(
      _pointCount,
      (i) => lerpDouble(fromRadii[i], toRadii[i], t)!,
    );

    final color = Color.lerp(from.color, to.color, t)!;
    final glowColor = color.withValues(alpha: 0.35);

    final path = _blobPath(center, baseR, radii);

    canvas.drawPath(
      path,
      Paint()
        ..color = glowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.35),
          radius: 1.1,
          colors: [
            Color.lerp(Colors.white.withValues(alpha: 0.45), color, 0.35)!,
            color,
            Color.lerp(color, AppColors.primaryDeep, 0.35)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: baseR * 1.4)),
    );

    _drawFace(canvas, center, baseR, color);
  }

  List<double> _radiiFor(MoodKind mood) {
    return switch (mood) {
      MoodKind.drained => [
          0.72, 0.68, 0.64, 0.62, 0.66, 0.70, 0.65, 0.60, 0.63, 0.69,
        ],
      MoodKind.tense => [
          0.95, 0.72, 1.05, 0.68, 0.98, 0.70, 1.02, 0.66, 0.96, 0.74,
        ],
      MoodKind.calm => [
          0.88, 0.90, 0.89, 0.91, 0.90, 0.89, 0.90, 0.91, 0.89, 0.88,
        ],
      MoodKind.balanced => [
          0.92, 0.88, 0.94, 0.86, 0.93, 0.87, 0.95, 0.85, 0.91, 0.89,
        ],
      MoodKind.energized => [
          1.08, 0.82, 1.12, 0.78, 1.10, 0.80, 1.14, 0.76, 1.06, 0.84,
        ],
    };
  }

  Path _blobPath(Offset center, double baseR, List<double> radii) {
    final points = <Offset>[];
    for (var i = 0; i < _pointCount; i++) {
      final angle = (i / _pointCount) * math.pi * 2 - math.pi / 2;
      final r = baseR * radii[i];
      points.add(Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      ));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < _pointCount; i++) {
      final curr = points[i];
      final next = points[(i + 1) % _pointCount];
      final mid = Offset((curr.dx + next.dx) / 2, (curr.dy + next.dy) / 2);
      path.quadraticBezierTo(curr.dx, curr.dy, mid.dx, mid.dy);
    }
    path.close();
    return path;
  }

  void _drawFace(Canvas canvas, Offset center, double baseR, Color color) {
    final eyeY = center.dy - baseR * 0.08;
    final eyeOffset = baseR * 0.22;
    final eyeR = baseR * 0.07;

    final eyePaint = Paint()..color = AppColors.textPrimary.withValues(alpha: 0.85);
    canvas.drawCircle(Offset(center.dx - eyeOffset, eyeY), eyeR, eyePaint);
    canvas.drawCircle(Offset(center.dx + eyeOffset, eyeY), eyeR, eyePaint);

    final mouthPath = Path();
    final mouthY = center.dy + baseR * 0.18;
    mouthPath.moveTo(center.dx - baseR * 0.18, mouthY);
    mouthPath.quadraticBezierTo(
      center.dx,
      mouthY + baseR * (to == MoodKind.drained ? 0.02 : 0.12),
      center.dx + baseR * 0.18,
      mouthY,
    );
    canvas.drawPath(
      mouthPath,
      Paint()
        ..color = AppColors.textPrimary.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = baseR * 0.045
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.from != from ||
      oldDelegate.to != to;
}
