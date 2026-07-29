import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:prime/design/motion.dart';
import 'package:prime/design/tokens.dart';
import 'package:prime/design/typography.dart';

class PrimeRingTrioItem {
  const PrimeRingTrioItem({
    required this.label,
    required this.value,
    required this.display,
  });

  final String label;
  final double value;
  final String display;
}

/// Three mini progress rings — streak / primes / pace row.
class PrimeRingTrio extends StatelessWidget {
  const PrimeRingTrio({
    super.key,
    required this.items,
    this.size = 72,
    this.stroke = 5,
    this.color,
  })  : assert(items.length == 3, 'PrimeRingTrio expects exactly 3 items');

  PrimeRingTrio.metrics({
    super.key,
    required double streak,
    required String streakDisplay,
    required double primes,
    required String primesDisplay,
    required double pace,
    required String paceDisplay,
    this.size = 72,
    this.stroke = 5,
    this.color,
  }) : items = [
          PrimeRingTrioItem(
            label: 'Серия',
            value: streak,
            display: streakDisplay,
          ),
          PrimeRingTrioItem(
            label: 'Праймы',
            value: primes,
            display: primesDisplay,
          ),
          PrimeRingTrioItem(
            label: 'Темп',
            value: pace,
            display: paceDisplay,
          ),
        ];

  final List<PrimeRingTrioItem> items;
  final double size;
  final double stroke;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final item in items)
          Expanded(
            child: _RingCell(
              item: item,
              size: size,
              stroke: stroke,
              accent: accent,
            ),
          ),
      ],
    );
  }
}

class _RingCell extends StatelessWidget {
  const _RingCell({
    required this.item,
    required this.size,
    required this.stroke,
    required this.accent,
  });

  final PrimeRingTrioItem item;
  final double size;
  final double stroke;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final numeric = double.tryParse(item.display.replaceAll(',', '.'));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _MiniRingPainter(
              progress: item.value.clamp(0.0, 1.0),
              stroke: stroke,
              accent: accent,
            ),
            child: Center(
              child: numeric != null
                  ? PrimeAnimatedNumber(
                      value: numeric,
                      style: AppTypography.numeric.copyWith(
                        fontSize: size * 0.24,
                        height: 1,
                      ),
                      duration: AppDurations.slow,
                    )
                  : Text(
                      item.display,
                      style: AppTypography.numeric.copyWith(
                        fontSize: size * 0.22,
                        height: 1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          item.label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _MiniRingPainter extends CustomPainter {
  _MiniRingPainter({
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

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.primaryContainer.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    if (progress <= 0) return;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}
