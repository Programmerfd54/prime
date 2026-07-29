import 'package:flutter/material.dart';

import '../../design/glass.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../models/report.dart';
import 'dashboard_helpers.dart';

class MonthlyReportCalendar extends StatelessWidget {
  final CalendarOut? calendar;
  final DateTime visibleMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const MonthlyReportCalendar({
    super.key,
    required this.calendar,
    required this.visibleMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(visibleMonth.year, visibleMonth.month);
    final daysInMonth =
        DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    final leadingEmptyDays = firstDay.weekday - 1;
    final cellCount = leadingEmptyDays + daysInMonth;
    final rowCount = (cellCount / 7).ceil();
    final reportsByDate = {
      for (final day in calendar?.days ?? <CalendarDay>[])
        dashboardDateKey(day.date): day,
    };

    return GlassContainer(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      borderRadius: BorderRadius.circular(AppRadius.bentoOuter),
      fillOpacity: 0.05,
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Предыдущий месяц',
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left),
                color: AppColors.textSecondary,
              ),
              Expanded(
                child: Text(
                  '${dashboardMonthNames[visibleMonth.month]} ${visibleMonth.year}',
                  textAlign: TextAlign.center,
                  style: AppTypography.title2,
                ),
              ),
              IconButton(
                tooltip: 'Следующий месяц',
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right),
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final weekday in dashboardWeekdayNames)
                Expanded(
                  child: Center(
                    child: Text(
                      weekday,
                      style: AppTypography.caption.copyWith(fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Column(
            children: [
              for (var row = 0; row < rowCount; row++) ...[
                Row(
                  children: [
                    for (var column = 0; column < 7; column++)
                      Expanded(
                        child: _CalendarDayCell(
                          index: row * 7 + column,
                          leadingEmptyDays: leadingEmptyDays,
                          daysInMonth: daysInMonth,
                          visibleMonth: visibleMonth,
                          reportsByDate: reportsByDate,
                          calendarLoaded: calendar != null,
                          trackingStartDate: calendar?.trackingStartDate,
                        ),
                      ),
                  ],
                ),
                if (row != rowCount - 1) const SizedBox(height: AppSpacing.xs),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final int index;
  final int leadingEmptyDays;
  final int daysInMonth;
  final DateTime visibleMonth;
  final Map<String, CalendarDay> reportsByDate;
  final bool calendarLoaded;
  final DateTime? trackingStartDate;

  const _CalendarDayCell({
    required this.index,
    required this.leadingEmptyDays,
    required this.daysInMonth,
    required this.visibleMonth,
    required this.reportsByDate,
    required this.calendarLoaded,
    required this.trackingStartDate,
  });

  @override
  Widget build(BuildContext context) {
    final dayNumber = index - leadingEmptyDays + 1;
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 34);
    }
    final date = DateTime(
      visibleMonth.year,
      visibleMonth.month,
      dayNumber,
    );
    final report = reportsByDate[dashboardDateKey(date)];
    final hasReport = report != null && (report.reported || report.completed);
    final isPastOrToday = !date.isAfter(dashboardTodayDateOnly());
    final trackingStart = trackingStartDate == null
        ? null
        : DateTime(
            trackingStartDate!.year,
            trackingStartDate!.month,
            trackingStartDate!.day,
          );
    final trackingStarted =
        trackingStart != null && !date.isBefore(trackingStart);
    final showMissed =
        calendarLoaded && trackingStarted && isPastOrToday && !hasReport;
    final fillColor = hasReport
        ? AppColors.warningStrong.withValues(alpha: 0.85)
        : showMissed
            ? AppColors.warningDim
            : Colors.transparent;
    final borderColor = hasReport
        ? AppColors.warningSoft.withValues(alpha: 0.7)
        : showMissed
            ? AppColors.border
            : Colors.transparent;

    final dayCircle = AnimatedContainer(
      duration: AppMotion.duration(context, AppDurations.fast),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fillColor,
        border: Border.all(color: borderColor),
      ),
      alignment: Alignment.center,
      child: Text(
        '$dayNumber',
        style: AppTypography.caption.copyWith(
          color: hasReport || showMissed
              ? AppColors.textPrimary
              : AppColors.textSecondary,
          fontSize: 13,
          fontWeight:
              hasReport || showMissed ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );

    return SizedBox(
      height: 34,
      child: Center(
        child: hasReport || showMissed
            ? InkWell(
                onTap: () => _showCalendarDayDetails(
                  context,
                  date: date,
                  report: report,
                  missed: showMissed,
                ),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: dayCircle,
              )
            : dayCircle,
      ),
    );
  }

  void _showCalendarDayDetails(
    BuildContext context, {
    required DateTime date,
    required CalendarDay? report,
    required bool missed,
  }) {
    final reports = report?.reports ?? const <Map<String, dynamic>>[];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: GlassContainer(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.bentoOuter),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            fillOpacity: 0.08,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  dashboardCalendarDateLabel(date),
                  style: AppTypography.title1,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (missed)
                  _CalendarDayInfoCard(
                    icon: Icons.remove_circle_outline,
                    color: AppColors.textMuted,
                    title: 'Отчёта не было',
                    subtitle:
                        'Этот день уже был после входа в группу, но отчёт не отправлялся ни по одной привычке.',
                  )
                else ...[
                  _CalendarDayInfoCard(
                    icon: Icons.check_circle,
                    color: AppColors.warningStrong,
                    title: 'Отчёт отправлен',
                    subtitle: 'В этот день есть хотя бы один отчёт.',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final item in reports) _CalendarReportTile(report: item),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CalendarDayInfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _CalendarDayInfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.sm),
      borderRadius: BorderRadius.circular(AppRadius.bentoInner),
      fillOpacity: 0.04,
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.title2),
                const SizedBox(height: AppSpacing.xxs),
                Text(subtitle, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarReportTile extends StatelessWidget {
  final Map<String, dynamic> report;

  const _CalendarReportTile({required this.report});

  @override
  Widget build(BuildContext context) {
    final skillName = (report['skill_name'] ?? '').toString();
    final content = (report['content_text'] ?? '').toString().trim();
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      borderRadius: BorderRadius.circular(AppRadius.bentoInner),
      fillOpacity: 0.04,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.bolt,
            color: AppColors.warningStrong,
            size: AppIconSizes.sm,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skillName.isEmpty ? 'Привычка' : skillName,
                  style: AppTypography.title2,
                ),
                if (content.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption,
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
