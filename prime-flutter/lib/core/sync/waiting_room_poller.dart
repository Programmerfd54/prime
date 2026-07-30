import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/api_client.dart';
import '../../models/group.dart';
import '../errors/failure_mapper.dart';

/// Polls waiting-room status while user is searching for a team.
class WaitingRoomPoller extends ChangeNotifier {
  WaitingRoomPoller(this._api);

  final ApiClient _api;
  Timer? _timer;
  bool _disposed = false;
  bool _refreshing = false;
  bool loading = false;
  String? error;
  WaitingRoomStatus? status;
  WaitingRoomStats? stats;
  Duration interval = const Duration(seconds: 10);

  bool get inQueue => status?.inQueue == true || (status?.queues.isNotEmpty ?? false);
  String? get matchedGroupId => status?.matchedGroupId;
  bool get isActive => _timer?.isActive == true;

  /// Primary queue row — use for peopleWaiting/slots when API returns [queues].
  WaitingRoomStatus? get primaryStatus {
    final current = status;
    if (current == null) return null;
    if (current.queues.isNotEmpty) return current.queues.first;
    return current.inQueue ? current : null;
  }

  /// Starts periodic polling. Safe to call repeatedly — does not restart
  /// an already-running timer or fire a duplicate immediate refresh.
  void start({Duration? interval, bool forceRefresh = false}) {
    if (interval != null) this.interval = interval;
    if (isActive && !forceRefresh) return;
    _restart(immediate: true);
  }

  void pause() => _timer?.cancel();

  void resume() => _restart(immediate: true);

  void stop() {
    _timer?.cancel();
    status = null;
    stats = null;
    error = null;
    if (!_disposed) notifyListeners();
  }

  void _restart({bool immediate = false}) {
    _timer?.cancel();
    if (immediate) unawaited(refresh());
    _timer = Timer.periodic(interval, (_) => unawaited(refresh()));
  }

  Future<void> refresh() async {
    if (_disposed || _refreshing) return;
    _refreshing = true;
    loading = status == null;
    try {
      if (status == null) {
        try {
          final cached = await _api.waitingRoomStatus();
          if (_disposed) return;
          status = WaitingRoomStatus.fromJson(cached);
          loading = false;
          notifyListeners();
        } catch (_) {
          // Live fetch below.
        }
      }
      await _api.invalidateWaitingRoomCache();
      final raw = await _api.waitingRoomStatusLive();
      if (_disposed) return;
      status = WaitingRoomStatus.fromJson(raw);
      stats = await _fetchStatsForStatus(status);
      error = null;
      if (status?.matchedGroupId != null &&
          status!.matchedGroupId!.isNotEmpty) {
        _timer?.cancel();
      }
    } catch (e) {
      error = FailureMapper.from(e).message;
    } finally {
      loading = false;
      _refreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<WaitingRoomStats?> _fetchStatsForStatus(
    WaitingRoomStatus? current,
  ) async {
    if (current == null || (!current.inQueue && current.queues.isEmpty)) {
      return null;
    }
    final target = _primaryQueue(current);
    final skillId = target.skillId;
    final regionCode = target.regionCode;
    if (skillId == null || regionCode == null) return stats;
    try {
      final raw = await _api.waitingRoomStats(
        skillId: skillId,
        regionCode: regionCode,
      );
      return WaitingRoomStats.fromJson(raw);
    } catch (_) {
      return stats;
    }
  }

  WaitingRoomStatus _primaryQueue(WaitingRoomStatus current) {
    if (current.queues.isNotEmpty) return current.queues.first;
    return current;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
