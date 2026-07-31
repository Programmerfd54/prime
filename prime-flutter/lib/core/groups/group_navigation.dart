import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/sync/waiting_room_poller.dart';
import '../../data/api_client.dart';
import '../../design/routes.dart';
import '../../screens/group_detail_screen.dart';

typedef GroupNavigationCallback = void Function({
  bool preferSearchTab,
  String? skillId,
});

typedef NotificationNavigateCallback = void Function({
  String? groupId,
  String? skillId,
  bool preferSearchTab,
});

/// Opens group detail and applies post-change-group navigation consistently.
Future<void> openGroupDetail(
  BuildContext context, {
  required String groupId,
  GroupNavigationCallback? host,
}) async {
  final api = context.read<ApiClient>();
  final changed = await Navigator.of(context).push<bool>(
    PrimeRoute.sharedAxis(
      builder: (_) => GroupDetailScreen(groupId: groupId),
    ),
  );
  if (changed != true || !context.mounted) return;
  await api.invalidateGroupsCache();
  if (!context.mounted) return;
  context.read<WaitingRoomPoller>().start(forceRefresh: true);
  host?.call(preferSearchTab: true);
}

/// Parses native/push deep links into navigation intents.
({String? groupId, String? skillId, bool preferSearchTab}) parsePushPayload(
  Map<String, dynamic> payload,
) {
  final deepLink = payload['deep_link'] as String? ?? '';
  final notificationType = payload['notification_type'] as String? ??
      payload['type'] as String? ??
      '';
  final groupId = payload['group_id'] as String?;
  final skillId = payload['skill_id'] as String?;

  if (deepLink.startsWith('prime://waiting-room')) {
    final uri = Uri.tryParse(deepLink);
    final linkedSkill = uri?.queryParameters['skill_id'] ?? skillId;
    return (groupId: null, skillId: linkedSkill, preferSearchTab: true);
  }
  if (deepLink.startsWith('prime://groups/')) {
    final parts = Uri.tryParse(deepLink)?.pathSegments ?? const [];
    if (parts.isNotEmpty) {
      return (groupId: parts.last, skillId: skillId, preferSearchTab: false);
    }
  }
  if (notificationType == 'early_start_request') {
    return (groupId: groupId, skillId: skillId, preferSearchTab: true);
  }
  if (groupId != null && groupId.isNotEmpty) {
    return (groupId: groupId, skillId: skillId, preferSearchTab: false);
  }
  return (groupId: null, skillId: skillId, preferSearchTab: true);
}
