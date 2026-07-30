import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/failure_mapper.dart';
import '../../../core/sync/realtime_client.dart';
import '../../../design/tokens.dart';
import '../../../models/notification.dart';
import '../../../ui/components/app_dialog.dart';
import '../../../ui/components/app_skeleton.dart';
import '../../../ui/components/app_snackbar.dart';
import '../ui/kit/presentation/gate_notifications_presentation.dart';

/// Opens notification center instantly; refresh runs inside the sheet.
Future<void> showNotificationCenterSheet({
  required BuildContext context,
  VoidCallback? onOpenGroups,
  required Future<void> Function(PrimeNotification notification) onItemTap,
  required Future<void> Function(PrimeNotification notification, bool accept)
      onRespondFriend,
}) {
  return showAppBottomSheet<void>(
    context: context,
    child: _NotificationCenterLoader(
      onOpenGroups: onOpenGroups,
      onItemTap: onItemTap,
      onRespondFriend: onRespondFriend,
    ),
  );
}

class _NotificationCenterLoader extends StatefulWidget {
  const _NotificationCenterLoader({
    this.onOpenGroups,
    required this.onItemTap,
    required this.onRespondFriend,
  });

  final VoidCallback? onOpenGroups;
  final Future<void> Function(PrimeNotification notification) onItemTap;
  final Future<void> Function(PrimeNotification notification, bool accept)
      onRespondFriend;

  @override
  State<_NotificationCenterLoader> createState() =>
      _NotificationCenterLoaderState();
}

class _NotificationCenterLoaderState extends State<_NotificationCenterLoader> {
  var _refreshing = false;
  String? _respondingId;
  bool? _respondingAccept;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final realtime = context.read<RealtimeClient>();
    final showSkeleton = realtime.items.isEmpty;
    if (showSkeleton && mounted) setState(() => _refreshing = true);
    try {
      await realtime.refresh().timeout(const Duration(seconds: 8));
    } catch (_) {
      // Keep cached items — sheet stays usable offline / on timeout.
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _onItemTap(PrimeNotification notification) async {
    await widget.onItemTap(notification);
  }

  Future<void> _respond(PrimeNotification notification, bool accept) async {
    if (_respondingId != null) return;
    final key = notification.requestId ?? notification.id;
    setState(() {
      _respondingId = key;
      _respondingAccept = accept;
    });
    final realtime = context.read<RealtimeClient>();
    realtime.removeNotificationLocally(notification.id);
    try {
      await widget
          .onRespondFriend(notification, accept)
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, FailureMapper.from(e).message);
        unawaited(_refresh());
      }
    } finally {
      if (mounted) {
        setState(() {
          _respondingId = null;
          _respondingAccept = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final realtime = context.watch<RealtimeClient>();
    if (_refreshing && realtime.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSkeleton(height: 24, width: 160),
            SizedBox(height: AppSpacing.md),
            AppSkeleton(height: 64),
            SizedBox(height: AppSpacing.sm),
            AppSkeleton(height: 64),
            SizedBox(height: AppSpacing.sm),
            AppSkeleton(height: 64),
          ],
        ),
      );
    }

    return GateNotificationCenterSheet(
      items: realtime.items,
      unreadCount: realtime.unreadCount,
      loading: _refreshing,
      respondingId: _respondingId,
      respondingAccept: _respondingAccept,
      onRefresh: _refresh,
      onMarkAllRead: realtime.unreadCount > 0
          ? () async {
              await realtime.markAllRead();
              if (context.mounted) Navigator.of(context).pop();
            }
          : null,
      onItemTap: _onItemTap,
      onAcceptFriend: (n) => _respond(n, true),
      onDeclineFriend: (n) => _respond(n, false),
    );
  }
}
