import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../tokens.dart';
import '../../typography.dart';

const _magenta = Color(0xFFD946EF);
const _editorialGold = Color(0xFFF0C14B);

enum PrimeLineChartStyle { neon, editorial }

/// Interactive line chart — neon (violet→magenta) or editorial (gold) stroke.
class PrimeNeonLineChart extends StatelessWidget {
  const PrimeNeonLineChart({
    super.key,
    required this.values,
    this.labels = const [],
    this.height = 100,
    this.style = PrimeLineChartStyle.neon,
  });

  final List<double> values;
  final List<String> labels;
  final double height;
  final PrimeLineChartStyle style;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(height: height);
    }

    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final span = (maxV - minV).abs() < 0.01 ? 1.0 : (maxV - minV);
    final spots = [
      for (var i = 0; i < values.length; i++)
        FlSpot(i.toDouble(), values[i]),
    ];

    final editorial = style == PrimeLineChartStyle.editorial;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minV - span * 0.12,
          maxY: maxV + span * 0.18,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: LineTouchData(
            enabled: true,
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => editorial
                  ? Colors.white
                  : AppColors.elevatedSurface.withValues(alpha: 0.95),
              tooltipBorder: BorderSide(
                color: editorial
                    ? Colors.transparent
                    : AppColors.primary.withValues(alpha: 0.55),
              ),
              getTooltipItems: (touched) {
                return touched.map((bar) {
                  final i = bar.x.toInt().clamp(0, values.length - 1);
                  final label = labels.isNotEmpty && i < labels.length
                      ? labels[i]
                      : '';
                  final value = values[i];
                  if (editorial) {
                    return LineTooltipItem(
                      '• ${value.toStringAsFixed(0)}',
                      AppTypography.caption.copyWith(
                        color: const Color(0xFF1A1A1F),
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }
                  return LineTooltipItem(
                    label.isEmpty
                        ? value.toStringAsFixed(2)
                        : '$label\n${value.toStringAsFixed(2)}',
                    AppTypography.caption.copyWith(
                      color: AppColors.primarySoft,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          color: AppColors.primary.withValues(alpha: 0.65),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  );
                }).toList();
              },
            ),
            getTouchedSpotIndicator: (barData, indexes) {
              return indexes.map((i) {
                final lineColor = editorial
                    ? _editorialGold.withValues(alpha: 0.55)
                    : _magenta.withValues(alpha: 0.55);
                final dotColor = editorial ? _editorialGold : _magenta;
                return TouchedSpotIndicatorData(
                  FlLine(color: lineColor, strokeWidth: 1.5),
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                      radius: 5,
                      color: dotColor,
                      strokeWidth: 2,
                      strokeColor: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                );
              }).toList();
            },
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: editorial ? 3.5 : 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              color: editorial ? _editorialGold : null,
              gradient: editorial
                  ? null
                  : LinearGradient(colors: [AppColors.primary, _magenta]),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: editorial
                      ? [
                          _editorialGold.withValues(alpha: 0.08),
                          _editorialGold.withValues(alpha: 0.0),
                        ]
                      : [
                          AppColors.primary.withValues(alpha: 0.28),
                          _magenta.withValues(alpha: 0.0),
                        ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
