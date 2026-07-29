import 'package:flutter/material.dart';

import '../../../core/mood/mood_state.dart';
import '../../../design/liquid/liquid_glass.dart';
import '../../../design/motion.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../models/report.dart';

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Mood vs completion overlay — shows when the user tends to slip.
class MoodCompletionChart extends StatelessWidget {
  const MoodCompletionChart({
    super.key,
    required this.moodLog,
    this.calendar,
    this.days = 14,
  });

  final List<MoodLogEntry> moodLog;
  final CalendarOut? calendar;
  final int days;

  @override
  Widget build(BuildContext context) {
    if (moodLog.isEmpty) {
      return LiquidGlass(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          'Отмечайте настроение — здесь появится связь с выполнением.',
          style: AppTypography.bodySecondary,
        ),
      );
    }

    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: days - 1));
    final byDate = <String, MoodKind>{
      for (final e in moodLog) e.date: e.kind,
    };
    final completed = <String>{};
    if (calendar != null) {
      for (final d in calendar!.days) {
        if (d.completed) completed.add(_dayKey(d.date));
      }
    }

    return LiquidGlass(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Настроение и ритм', style: AppTypography.titleSerif),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Цвет — настроение дня. Точка сверху — день выполнен.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 72,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < days; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final day = start.add(Duration(days: i));
                        final key = _dayKey(day);
                        return _DayColumn(
                          kind: byDate[key],
                          done: completed.contains(key),
                        );
                      },
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

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.kind, required this.done});

  final MoodKind? kind;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = kind?.color ?? AppColors.elevatedSurface;
    final h = kind == null ? 18.0 : 28.0 + kind!.index * 8.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (done)
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              boxShadow: AppGlow.violet(opacity: 0.2),
            ),
          )
        else
          const SizedBox(height: 9),
        AnimatedContainer(
          duration: AppMotion.duration(context, AppDurations.normal),
          height: h,
          decoration: BoxDecoration(
            color: color.withValues(alpha: kind == null ? 0.35 : 0.85),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ],
    );
  }
}

/// Async wrapper that loads mood log and renders [MoodCompletionChart].
class MoodCompletionChartLoader extends StatefulWidget {
  const MoodCompletionChartLoader({super.key, this.calendar});

  final CalendarOut? calendar;

  @override
  State<MoodCompletionChartLoader> createState() =>
      _MoodCompletionChartLoaderState();
}

class _MoodCompletionChartLoaderState extends State<MoodCompletionChartLoader> {
  List<MoodLogEntry> _log = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final log = await MoodState.loadLog();
    if (!mounted) return;
    setState(() => _log = log);
  }

  @override
  Widget build(BuildContext context) {
    return MoodCompletionChart(moodLog: _log, calendar: widget.calendar);
  }
}
