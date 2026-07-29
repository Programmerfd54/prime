import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/errors/failure_mapper.dart';
import '../data/api_client.dart';
import '../design/glass.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../design/visuals/charts/charts.dart';
import '../providers/auth_provider.dart';
import '../ui/components/app_header.dart';
import '../ui/states/app_loading_state.dart';
import '../widgets/async_error_view.dart';

class PrimeHistoryScreen extends StatefulWidget {
  const PrimeHistoryScreen({super.key});

  @override
  State<PrimeHistoryScreen> createState() => _PrimeHistoryScreenState();
}

class _PrimeHistoryScreenState extends State<PrimeHistoryScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await context.read<ApiClient>().listPrimeEvents();
      _events = raw.cast<Map<String, dynamic>>();
    } catch (e) {
      _error = FailureMapper.from(e).message;
    }
    if (mounted) setState(() => _loading = false);
  }

  DateTime _weekStart(DateTime date) {
    final local = date.toLocal();
    final weekday = local.weekday;
    return DateTime(local.year, local.month, local.day)
        .subtract(Duration(days: weekday - 1));
  }

  String _weekLabel(DateTime start) {
    final end = start.add(const Duration(days: 6));
    return '${start.day}.${start.month.toString().padLeft(2, '0')} — '
        '${end.day}.${end.month.toString().padLeft(2, '0')}';
  }

  Map<DateTime, List<Map<String, dynamic>>> _groupByWeek() {
    final grouped = <DateTime, List<Map<String, dynamic>>>{};
    for (final event in _events) {
      final created = DateTime.tryParse(event['created_at'] as String? ?? '');
      if (created == null) continue;
      final key = _weekStart(created);
      grouped.putIfAbsent(key, () => []).add(event);
    }
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in keys) k: grouped[k]!};
  }

  List<double> _cumulativeSparkline() {
    if (_events.isEmpty) return const [];
    final sorted = [..._events]
      ..sort((a, b) {
        final da = DateTime.tryParse(a['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final db = DateTime.tryParse(b['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return da.compareTo(db);
      });
    var total = 0;
    final values = <double>[];
    for (final event in sorted) {
      total += event['amount'] as int? ?? 0;
      values.add(total.toDouble());
    }
    if (values.length > 12) {
      return values.sublist(values.length - 12);
    }
    return values;
  }

  List<MapEntry<String, int>> _reasonBreakdown() {
    final counts = <String, int>{};
    for (final event in _events) {
      final reason = (event['reason'] as String? ?? 'Начисление').trim();
      counts[reason] = (counts[reason] ?? 0) + (event['amount'] as int? ?? 0);
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final balance = context.watch<AuthProvider>().user?.primePoints ?? 0;
    final grouped = _groupByWeek();
    final sparkline = _cumulativeSparkline();
    final breakdown = _reasonBreakdown();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildAppBackBar(context, title: 'История Праймов'),
      body: AmbientCanvas(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Баланс: ', style: AppTypography.bodySecondary),
                  PrimeAnimatedNumber(
                    value: balance,
                    style: AppTypography.bodySecondary.copyWith(
                      color: AppColors.primarySoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    ' · начисляются за засчитанные отчёты',
                    style: AppTypography.bodySecondary,
                  ),
                ],
              ),
            ),
            if (sparkline.length >= 2) ...[
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: GlassContainer(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  borderRadius: BorderRadius.circular(AppRadius.bentoOuter),
                  fillOpacity: 0.05,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Накопление', style: AppTypography.titleSerif),
                      const SizedBox(height: AppSpacing.xs),
                      PrimeNeonLineChart(
                        values: sparkline
                            .map((v) =>
                                v / sparkline.last.clamp(1, double.infinity))
                            .toList(),
                        height: 72,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (breakdown.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: GlassContainer(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  fillOpacity: 0.04,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('За что чаще', style: AppTypography.titleSerif),
                      const SizedBox(height: AppSpacing.xs),
                      for (final entry in breakdown)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.xxs),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: AppTypography.bodySecondary,
                                ),
                              ),
                              Text(
                                '+${entry.value}',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.primarySoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: _loading
                  ? const AppLoadingState(label: 'Загрузка…')
                  : _error != null
                      ? AsyncErrorView(message: _error!, onRetry: _load)
                      : _events.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: GlassContainer(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xl,
                                    vertical: AppSpacing.lg,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.bentoOuter,
                                  ),
                                  fillOpacity: 0.05,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.auto_awesome_outlined,
                                        size: 48,
                                        color: AppColors.primarySoft,
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      Text(
                                        'Пока нет начислений',
                                        textAlign: TextAlign.center,
                                        style: AppTypography.titleSerif,
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        'Отправьте первый отчёт в группе.',
                                        textAlign: TextAlign.center,
                                        style: AppTypography.bodySecondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              children: [
                                for (final week in grouped.entries) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.sm,
                                    ),
                                    child: Text(
                                      'Неделя ${_weekLabel(week.key)}',
                                      style: AppTypography.titleSerif,
                                    ),
                                  ),
                                  for (final e in week.value) ...[
                                    _EventTile(
                                      event: e,
                                      formatDate: _formatEventDate,
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                  ],
                                  const SizedBox(height: AppSpacing.sm),
                                ],
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatEventDate(DateTime date) {
    final local = date.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day}.${local.month.toString().padLeft(2, '0')} · $hh:$mm';
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.formatDate,
  });

  final Map<String, dynamic> event;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    final amount = event['amount'] as int? ?? 0;
    final reason = event['reason'] as String? ?? 'Начисление';
    final created = event['created_at'] as String? ?? '';
    final date = DateTime.tryParse(created);
    final prefix = amount >= 0 ? '+' : '';

    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      fillOpacity: 0.04,
      child: Row(
        children: [
          Text(
            '$prefix$amount',
            style: AppTypography.title2.copyWith(
              color: amount >= 0
                  ? AppColors.primarySoft
                  : AppColors.coral,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reason, style: AppTypography.body),
                if (date != null)
                  Text(
                    formatDate(date),
                    style: AppTypography.caption,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
