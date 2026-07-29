import 'package:flutter/material.dart';

import '../../../core/metrics/calendar_metrics.dart';
import '../../tokens.dart';
import '../../typography.dart';

/// 30-day cycle heatmap grid — empty cells stay as ghost outlines.
class PrimeHeatmap extends StatelessWidget {
  const PrimeHeatmap({
    super.key,
    required this.cells,
    this.columns = 10,
    this.cellSize = 14,
    this.gap = 4,
    this.title,
  });

  final List<HeatmapCell> cells;
  final int columns;
  final double cellSize;
  final double gap;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final list = cells.isEmpty
        ? List.generate(
            30,
            (i) => HeatmapCell(
              dayIndex: i,
              date: null,
              status: '',
              completed: false,
              reported: false,
              primeAwarded: false,
              isEmpty: true,
            ),
          )
        : cells;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title!, style: AppTypography.caption),
          const SizedBox(height: AppSpacing.xs),
        ],
        Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final cell in list) _Cell(cell: cell, size: cellSize),
          ],
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.cell, required this.size});

  final HeatmapCell cell;
  final double size;

  @override
  Widget build(BuildContext context) {
    Color fill;
    Color border;
    if (cell.isEmpty) {
      fill = Colors.transparent;
      border = AppColors.borderStrong;
    } else if (cell.primeAwarded || cell.completed) {
      fill = AppColors.success.withValues(alpha: 0.85);
      border = AppColors.success;
    } else if (cell.reported) {
      fill = AppColors.primary.withValues(alpha: 0.55);
      border = AppColors.primarySoft;
    } else if (cell.status == 'missed' || cell.status == 'failed') {
      fill = AppColors.error.withValues(alpha: 0.35);
      border = AppColors.error.withValues(alpha: 0.55);
    } else {
      fill = AppColors.elevatedSurface;
      border = AppColors.border;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: 1),
      ),
    );
  }
}
