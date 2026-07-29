import 'package:flutter/material.dart';
import 'package:prime/design/tokens.dart';
import 'package:prime/design/typography.dart';

enum PrimeBarPairAxis { horizontal, vertical }

/// Filled vs remainder bar with diagonal hatch on the unfilled portion.
class PrimeBarPair extends StatelessWidget {
  const PrimeBarPair({
    super.key,
    required this.filled,
    required this.total,
    required this.label,
    this.height = 12,
    this.color,
    this.axis = PrimeBarPairAxis.horizontal,
  });

  final double filled;
  final double total;
  final String label;
  final double height;
  final Color? color;
  final PrimeBarPairAxis axis;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary;
    final ratio = total <= 0 ? 0.0 : (filled / total).clamp(0.0, 1.0);
    final isHorizontal = axis == PrimeBarPairAxis.horizontal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${filled.toStringAsFixed(filled.truncateToDouble() == filled ? 0 : 1)}'
              ' / ${total.toStringAsFixed(total.truncateToDouble() == total ? 0 : 1)}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        SizedBox(
          width: isHorizontal ? double.infinity : height,
          height: isHorizontal ? height : 120,
          child: CustomPaint(
            painter: _BarPairPainter(
              ratio: ratio,
              accent: accent,
              horizontal: isHorizontal,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _BarPairPainter extends CustomPainter {
  _BarPairPainter({
    required this.ratio,
    required this.accent,
    required this.horizontal,
  });

  final double ratio;
  final Color accent;
  final bool horizontal;

  @override
  void paint(Canvas canvas, Size size) {
    final r = AppRadius.sm;
    final track = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(r),
    );

    canvas.drawRRect(
      track,
      Paint()..color = AppColors.elevatedSurface.withValues(alpha: 0.55),
    );

    final filledRect = horizontal
        ? Rect.fromLTWH(0, 0, size.width * ratio, size.height)
        : Rect.fromLTWH(
            0,
            size.height * (1 - ratio),
            size.width,
            size.height * ratio,
          );

    if (ratio > 0) {
      canvas.save();
      canvas.clipRRect(track);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          filledRect,
          Radius.circular(r),
        ),
        Paint()
          ..shader = LinearGradient(
            begin: horizontal ? Alignment.centerLeft : Alignment.bottomCenter,
            end: horizontal ? Alignment.centerRight : Alignment.topCenter,
            colors: [
              accent.withValues(alpha: 0.65),
              accent,
            ],
          ).createShader(filledRect),
      );
      canvas.restore();
    }

    final remainder = horizontal
        ? Rect.fromLTWH(
            size.width * ratio,
            0,
            size.width * (1 - ratio),
            size.height,
          )
        : Rect.fromLTWH(
            0,
            0,
            size.width,
            size.height * (1 - ratio),
          );

    if (remainder.width > 1 && remainder.height > 1) {
      canvas.save();
      canvas.clipRRect(track);
      _drawDiagonalHatch(
        canvas,
        remainder,
        AppColors.borderStrong.withValues(alpha: 0.55),
      );
      canvas.restore();
    }

    canvas.drawRRect(
      track,
      Paint()
        ..color = AppColors.borderStrong.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _BarPairPainter oldDelegate) =>
      oldDelegate.ratio != ratio || oldDelegate.accent != accent;
}

void drawPrimeDiagonalHatch(
  Canvas canvas,
  Rect rect,
  Color color, {
  double spacing = 4.5,
  double strokeWidth = 1,
}) {
  _drawDiagonalHatch(canvas, rect, color, spacing: spacing, strokeWidth: strokeWidth);
}

void _drawDiagonalHatch(
  Canvas canvas,
  Rect rect,
  Color color, {
  double spacing = 4.5,
  double strokeWidth = 1,
}) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth;

  canvas.save();
  canvas.clipRect(rect);
  for (var d = -rect.height; d < rect.width + rect.height; d += spacing) {
    canvas.drawLine(
      Offset(rect.left + d, rect.top),
      Offset(rect.left + d + rect.height, rect.bottom),
      paint,
    );
  }
  canvas.restore();
}
