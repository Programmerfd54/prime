import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/api_client.dart';

enum PendingReportKind { report, checkIn }

/// A single queued report/check-in submission awaiting a reconnect.
class ReportQueueItem {
  const ReportQueueItem({
    required this.idempotencyKey,
    required this.kind,
    required this.payload,
    required this.createdAt,
  });

  /// Client-generated uuid — identifies this submission across retries so a
  /// partially-flushed queue never confuses two attempts for one report.
  final String idempotencyKey;
  final PendingReportKind kind;

  /// For [PendingReportKind.report]: the body sent to `POST /reports`.
  /// For [PendingReportKind.checkIn]: `{'group_id': ..., 'kind': ...}`.
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'idempotency_key': idempotencyKey,
        'kind': kind.name,
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
      };

  static ReportQueueItem? fromJson(Map<String, dynamic> json) {
    final kindName = json['kind'] as String?;
    PendingReportKind? kind;
    for (final candidate in PendingReportKind.values) {
      if (candidate.name == kindName) {
        kind = candidate;
        break;
      }
    }
    final idempotencyKey = json['idempotency_key'] as String?;
    final payload = json['payload'];
    if (kind == null || idempotencyKey == null || payload is! Map) return null;
    final createdAtRaw = json['created_at'] as String?;
    return ReportQueueItem(
      idempotencyKey: idempotencyKey,
      kind: kind,
      payload: Map<String, dynamic>.from(payload),
      createdAt: createdAtRaw != null
          ? (DateTime.tryParse(createdAtRaw) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

/// SharedPreferences-backed offline queue for report / check-in submissions.
///
/// On network failure, callers enqueue the submission instead of losing it.
/// The next successful [flush] (typically triggered when a screen loads and
/// detects it's back online) resends every queued item exactly once per
/// call; items that fail again due to network issues stay queued for the
/// next reconnect, while non-network failures are dropped (already invalid).
class ReportQueue {
  ReportQueue._();

  static final ReportQueue instance = ReportQueue._();

  static const _prefsKey = 'prime_pending_reports_v1';

  bool _flushing = false;

  String _generateIdempotencyKey() {
    final rand = Random();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    // RFC4122-ish v4 formatting — good enough as a client-local dedupe key.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int start, int end) =>
        bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  Future<List<ReportQueueItem>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    final items = <ReportQueueItem>[];
    for (final entry in raw) {
      try {
        final decoded = jsonDecode(entry);
        if (decoded is Map<String, dynamic>) {
          final item = ReportQueueItem.fromJson(decoded);
          if (item != null) items.add(item);
        }
      } catch (_) {
        // Drop unparsable entries rather than blocking the whole queue.
      }
    }
    return items;
  }

  Future<void> _writeAll(List<ReportQueueItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    if (items.isEmpty) {
      await prefs.remove(_prefsKey);
      return;
    }
    await prefs.setStringList(
      _prefsKey,
      items.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  /// Number of submissions currently waiting for a reconnect.
  Future<int> pendingCount() async => (await _readAll()).length;

  /// Queues a `/reports` submission. [payload] should match the body used
  /// with [ApiClient.createReport].
  Future<String> enqueueReport(Map<String, dynamic> payload) async {
    final key = _generateIdempotencyKey();
    final items = await _readAll();
    items.add(
      ReportQueueItem(
        idempotencyKey: key,
        kind: PendingReportKind.report,
        payload: payload,
        createdAt: DateTime.now(),
      ),
    );
    await _writeAll(items);
    return key;
  }

  /// Queues a group check-in submission.
  Future<String> enqueueCheckIn({
    required String groupId,
    required String kind,
  }) async {
    final key = _generateIdempotencyKey();
    final items = await _readAll();
    items.add(
      ReportQueueItem(
        idempotencyKey: key,
        kind: PendingReportKind.checkIn,
        payload: {'group_id': groupId, 'kind': kind},
        createdAt: DateTime.now(),
      ),
    );
    await _writeAll(items);
    return key;
  }

  /// Attempts to resend every queued item once. Safe to call opportunistically
  /// (e.g. on screen load) — a concurrent flush in progress is a no-op.
  Future<void> flush(ApiClient api) async {
    if (_flushing) return;
    _flushing = true;
    try {
      final items = await _readAll();
      if (items.isEmpty) return;
      final remaining = <ReportQueueItem>[];
      var networkDown = false;
      for (final item in items) {
        if (networkDown) {
          remaining.add(item);
          continue;
        }
        try {
          await _submit(api, item);
        } catch (e) {
          if (ApiClient.isNetworkError(e)) {
            networkDown = true;
            remaining.add(item);
          }
          // Non-network failure (validation, group no longer active, etc.):
          // drop it — retrying forever would never succeed.
        }
      }
      await _writeAll(remaining);
    } finally {
      _flushing = false;
    }
  }

  Future<void> _submit(ApiClient api, ReportQueueItem item) async {
    switch (item.kind) {
      case PendingReportKind.report:
        await api.createReport(item.payload);
      case PendingReportKind.checkIn:
        final groupId = item.payload['group_id'] as String? ?? '';
        final kind = item.payload['kind'] as String? ?? '';
        await api.groupCheckIn(groupId, kind);
    }
  }
}
