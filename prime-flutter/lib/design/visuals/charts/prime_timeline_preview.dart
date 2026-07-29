import 'package:flutter/material.dart';

import '../../tokens.dart';
import '../../typography.dart';

class TimelineStep {
  const TimelineStep({
    required this.time,
    required this.label,
    this.accent = false,
  });

  final String time;
  final String label;
  final bool accent;
}

/// Mini day timeline: 09:00 → action → 20:00 → report → +Primes.
class PrimeTimelinePreview extends StatelessWidget {
  const PrimeTimelinePreview({
    super.key,
    this.steps = const [
      TimelineStep(time: '09:00', label: 'Действие'),
      TimelineStep(time: '20:00', label: 'Отчёт'),
      TimelineStep(time: '+', label: 'Праймы', accent: true),
    ],
  });

  final List<TimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: AppColors.elevatedSurface.withValues(alpha: 0.55),
        border: Border.all(color: AppColors.border),
      ),
      child: largeText
          ? Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final step in steps) _Node(step: step, compact: true),
              ],
            )
          : FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: CustomPaint(
                          size: const Size(28, 2),
                          painter: _DashLinePainter(),
                        ),
                      ),
                    _Node(step: steps[i]),
                  ],
                ],
              ),
            ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.step, this.compact = false});

  final TimelineStep step;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = step.accent ? AppColors.achievementAmber : AppColors.primarySoft;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 22 : 28,
          height: compact ? 22 : 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Center(
            child: Text(
              step.time.length <= 2 ? step.time : '•',
              style: AppTypography.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: compact ? 9 : 11,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          step.time.length > 2 ? step.time : '',
          style: AppTypography.caption.copyWith(fontSize: compact ? 9 : 10),
        ),
        Text(
          step.label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: compact ? 9 : 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DashLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.borderStrong
      ..strokeWidth = 1.5;
    const dash = 4.0;
    const gap = 3.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(mathMin(x + dash, size.width), y), paint);
      x += dash + gap;
    }
  }

  double mathMin(double a, double b) => a < b ? a : b;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
