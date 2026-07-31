import 'dart:async';

import 'package:flutter/material.dart';

import '../design/theme/prime_theme_context.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../ui/kit/components/prime_content_card.dart';

/// In-app banner while social writes are temporarily restricted.
class SocialRestrictionBanner extends StatefulWidget {
  const SocialRestrictionBanner({
    super.key,
    required this.expiresAt,
    this.message,
  });

  final DateTime expiresAt;
  final String? message;

  @override
  State<SocialRestrictionBanner> createState() => _SocialRestrictionBannerState();
}

class _SocialRestrictionBannerState extends State<SocialRestrictionBanner> {
  Timer? _ticker;
  late int _secondsRemaining;

  @override
  void initState() {
    super.initState();
    _syncRemaining();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = _calculateRemaining();
      if (next != _secondsRemaining) {
        setState(() => _secondsRemaining = next);
      }
    });
  }

  @override
  void didUpdateWidget(covariant SocialRestrictionBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) {
      _syncRemaining();
    }
  }

  int _calculateRemaining() {
    final seconds = widget.expiresAt.difference(DateTime.now()).inSeconds;
    return seconds.clamp(0, 7 * 24 * 3600).toInt();
  }

  void _syncRemaining() {
    _secondsRemaining = _calculateRemaining();
  }

  String _timerLabel() {
    final seconds = _secondsRemaining;
    if (seconds <= 0) return 'Ограничение скоро снимется';
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours.toString().padLeft(2, '0')}:'
          '${mins.toString().padLeft(2, '0')}:'
          '${rest.toString().padLeft(2, '0')} до разблокировки';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${rest.toString().padLeft(2, '0')} до разблокировки';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_secondsRemaining <= 0) return const SizedBox.shrink();

    final p = context.prime;
    final message = widget.message?.trim();

    return PrimeContentCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.timer_outlined, color: p.coral, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  message?.isNotEmpty == true
                      ? message!
                      : 'Публикация сообщений временно ограничена',
                  style: AppTypography.body.copyWith(color: p.ink),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  _timerLabel(),
                  style: AppTypography.caption.copyWith(color: p.inkSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
