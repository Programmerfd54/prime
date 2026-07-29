import 'package:flutter/material.dart';

import '../../../core/metrics/calendar_metrics.dart';
import '../../tokens.dart';
import '../../typography.dart';

/// Seven weekday bars — empty days show tall ghost bars + baseline.
///
/// Uses [GestureDetector] (not [InkWell]) so cells work inside custom
/// surfaces that are not Material ancestors.
class PrimeWeeklyBars extends StatelessWidget {
  const PrimeWeeklyBars({
    super.key,
    required this.buckets,
    this.height = 88,
    this.color,
    this.showLabels = true,
    this.showLegend = false,
    this.onDayTap,
  });

  final List<WeekDayBucket> buckets;
  final double height;
  final Color? color;
  final bool showLabels;
  final bool showLegend;
  final ValueChanged<WeekDayBucket>? onDayTap;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary;
    final items = buckets.isEmpty
        ? List.generate(
            7,
            (i) => WeekDayBucket(
              date: DateTime.now().subtract(Duration(days: 6 - i)),
              label: const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'][i],
              completed: false,
              reported: false,
              isToday: i == 6,
              isFuture: false,
            ),
          )
        : buckets;
    final isEmpty = items.every((b) => b.intensity <= 0);
    final chartHeight = height + (showLabels ? 22 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: chartHeight,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: showLabels ? 22 : 0,
                child: Container(
                  height: 1,
                  color: AppColors.borderStrong.withValues(alpha: 0.55),
                ),
              ),
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final b in items)
                      Expanded(
                        child: _DayCell(
                          bucket: b,
                          accent: accent,
                          barMaxHeight: height,
                          emptyMode: isEmpty,
                          showLabel: showLabels,
                          onTap: onDayTap == null ? null : () => onDayTap!(b),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showLegend) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              _LegendDot(color: accent, label: 'Готово'),
              _LegendDot(
                color: accent.withValues(alpha: 0.45),
                label: 'Отчёт',
              ),
              _LegendDot(
                color: AppColors.borderStrong,
                label: 'Пусто',
                outlined: true,
              ),
            ],
          ),
        ],
        if (isEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Нажмите на день — здесь появится ваш ритм после первого отчёта',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.bucket,
    required this.accent,
    required this.barMaxHeight,
    required this.emptyMode,
    required this.showLabel,
    this.onTap,
  });

  final WeekDayBucket bucket;
  final Color accent;
  final double barMaxHeight;
  final bool emptyMode;
  final bool showLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _Bar(
                  intensity: bucket.intensity,
                  reportedOnly: bucket.reported && !bucket.completed,
                  isToday: bucket.isToday,
                  isFuture: bucket.isFuture,
                  accent: accent,
                  maxHeight: barMaxHeight,
                  emptyMode: emptyMode,
                ),
              ),
            ),
            if (showLabel) ...[
              const SizedBox(height: 6),
              Text(
                bucket.label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: AppTypography.caption.copyWith(
                  color: bucket.isToday
                      ? AppColors.primarySoft
                      : AppColors.textMuted,
                  fontWeight:
                      bucket.isToday ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    this.outlined = false,
  });

  final Color color;
  final String label;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: outlined ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color, width: 1.2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.intensity,
    required this.reportedOnly,
    required this.isToday,
    required this.isFuture,
    required this.accent,
    required this.maxHeight,
    required this.emptyMode,
  });

  final double intensity;
  final bool reportedOnly;
  final bool isToday;
  final bool isFuture;
  final Color accent;
  final double maxHeight;
  final bool emptyMode;

  @override
  Widget build(BuildContext context) {
    // Ghost bars fill ~45% of chart height so empty week doesn't look blank.
    final h = intensity <= 0
        ? (emptyMode ? maxHeight * 0.42 : 14.0)
        : (14.0 + intensity * (maxHeight - 22)).clamp(14.0, maxHeight);

    if (intensity <= 0) {
      return Container(
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isToday
                ? AppColors.primary.withValues(alpha: 0.7)
                : AppColors.borderStrong,
            width: isToday ? 1.5 : 1,
          ),
          color: isFuture
              ? Colors.transparent
              : AppColors.elevatedSurface
                  .withValues(alpha: emptyMode ? 0.22 : 0.4),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SizedBox(
        height: h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    accent.withValues(alpha: 0.55 + intensity * 0.35),
                    accent,
                  ],
                ),
                boxShadow: isToday
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            ),
            if (reportedOnly)
              CustomPaint(
                painter: _ReportedHatchPainter(
                  color: AppColors.borderStrong.withValues(alpha: 0.65),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReportedHatchPainter extends CustomPainter {
  const _ReportedHatchPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const spacing = 4.5;
    for (var d = -size.height; d < size.width + size.height; d += spacing) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ReportedHatchPainter oldDelegate) =>
      oldDelegate.color != color;
}
