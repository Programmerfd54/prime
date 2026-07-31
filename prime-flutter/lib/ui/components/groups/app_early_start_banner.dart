import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../models/group.dart';
import '../../kit/components/prime_content_card.dart';
import '../app_primary_button.dart';
import '../app_secondary_button.dart';

/// In-app banner when someone proposes early start in the waiting room.
class AppEarlyStartBanner extends StatefulWidget {
  const AppEarlyStartBanner({
    super.key,
    required this.status,
    required this.onConfirm,
    required this.onKeepWaiting,
    this.loading = false,
  });

  final WaitingRoomStatus status;
  final VoidCallback onConfirm;
  final VoidCallback onKeepWaiting;
  final bool loading;

  @override
  State<AppEarlyStartBanner> createState() => _AppEarlyStartBannerState();
}

class _AppEarlyStartBannerState extends State<AppEarlyStartBanner> {
  Timer? _ticker;
  late int _secondsRemaining;
  DateTime? _fallbackExpiresAt;

  @override
  void initState() {
    super.initState();
    _syncRemaining();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _secondsRemaining <= 0) return;
      setState(() {
        _secondsRemaining = widget.status.earlyStartExpiresAt == null
            ? _secondsRemaining - 1
            : _calculateRemaining();
      });
    });
  }

  @override
  void didUpdateWidget(covariant AppEarlyStartBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status.earlyStartRequestId !=
            widget.status.earlyStartRequestId ||
        oldWidget.status.earlyStartSecondsRemaining !=
            widget.status.earlyStartSecondsRemaining ||
        oldWidget.status.earlyStartExpiresAt !=
            widget.status.earlyStartExpiresAt) {
      _syncRemaining();
    }
  }

  int _calculateRemaining() {
    final expiresAt = widget.status.earlyStartExpiresAt ?? _fallbackExpiresAt;
    if (expiresAt == null) return 0;
    final seconds = expiresAt.difference(DateTime.now()).inSeconds;
    return seconds.clamp(0, 15 * 60).toInt();
  }

  void _syncRemaining() {
    _fallbackExpiresAt = widget.status.earlyStartExpiresAt == null
        ? DateTime.now().add(
            Duration(seconds: widget.status.earlyStartSecondsRemaining),
          )
        : null;
    _secondsRemaining = _calculateRemaining();
  }

  String _timerLabel() {
    final seconds = _secondsRemaining;
    if (seconds <= 0) return 'Время истекло';
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${rest.toString().padLeft(2, '0')} на решение';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    if (!status.earlyStartPending && !status.earlyStartWaitingOthers) {
      return const SizedBox.shrink();
    }
    final p = context.prime;
    final proposer = status.earlyStartProposerName?.trim();
    final confirmed = status.earlyStartConfirmedCount;
    final needed = status.earlyStartNeededConfirmations;

    return PrimeContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: p.brand),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  proposer != null && proposer.isNotEmpty
                      ? '$proposer предлагает старт втроём'
                      : 'Предложен ранний старт втроём',
                  style: AppTypography.title2.copyWith(color: p.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Уже $confirmed из $needed согласились · ${_timerLabel()}',
            style: AppTypography.bodySecondary.copyWith(color: p.inkSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          if (status.earlyStartPending) ...[
            AppPrimaryButton(
              label: 'Подтвердить старт втроём',
              icon: Icons.check_rounded,
              loading: widget.loading,
              onPressed: widget.loading || _secondsRemaining <= 0
                  ? null
                  : widget.onConfirm,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppSecondaryButton(
              label: 'Продолжить ждать',
              onPressed: widget.loading ? null : widget.onKeepWaiting,
            ),
          ] else
            Text(
              'Вы подтвердили ранний старт · ждём остальных',
              style: AppTypography.caption.copyWith(color: p.mint),
            ),
        ],
      ),
    );
  }
}
