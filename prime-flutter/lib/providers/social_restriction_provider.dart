import 'package:flutter/foundation.dart';

import '../core/errors/app_failure.dart';
import '../core/errors/failure_mapper.dart';
import '../data/api_client.dart';
import '../models/social_restriction.dart';

/// Tracks active SOCIAL_WRITE moderation restrictions for the signed-in user.
class SocialRestrictionProvider extends ChangeNotifier {
  SocialRestrictionProvider(this._api);

  final ApiClient _api;
  SocialRestrictionStatus? _status;
  var _loading = false;

  SocialRestrictionStatus? get status => _status;
  bool get isLoading => _loading;
  bool get isWriteBlocked => _status?.isWriteBlocked ?? false;
  DateTime? get expiresAt => _status?.expiresAt;
  String? get decisionId => _status?.decisionId;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      _status = await _api.fetchMySocialRestriction();
    } catch (_) {
      // Keep the last known restriction when offline.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void applyFromError(Object error) {
    final failure = FailureMapper.from(error);
    if (failure is SocialWriteRestrictedFailure) {
      _status = SocialRestrictionStatus(
        active: true,
        scope: 'SOCIAL_WRITE',
        expiresAt: failure.expiresAt,
        decisionId: _status?.decisionId,
      );
      notifyListeners();
      return;
    }
    if (failure is ProfanityRejectedFailure && failure.expiresAt != null) {
      _status = SocialRestrictionStatus(
        active: true,
        scope: 'SOCIAL_WRITE',
        expiresAt: failure.expiresAt,
        decisionId: _status?.decisionId,
      );
      notifyListeners();
    }
  }

  void clear() {
    _status = null;
    notifyListeners();
  }
}
