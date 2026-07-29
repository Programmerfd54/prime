import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../models/chat_message.dart';
import 'app_text_button.dart';

/// Chat bubble for direct / group messages.
/// Outbound uses soft purple [AppColors.bubbleOutbound], not bright primary fill.
class AppMessageBubble extends StatelessWidget {
  const AppMessageBubble({
    super.key,
    required this.text,
    required this.isMine,
    this.timeLabel,
    this.statusLabel,
    this.status,
    this.failed = false,
    this.onRetry,
    this.senderLabel,
    this.isLastInGroup = true,
    this.replyPreview,
  });

  final String text;
  final bool isMine;
  final String? timeLabel;
  final String? statusLabel;
  final ChatDeliveryStatus? status;
  final bool failed;
  final VoidCallback? onRetry;
  final String? senderLabel;
  final bool isLastInGroup;
  final String? replyPreview;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadius.md),
      topRight: const Radius.circular(AppRadius.md),
      bottomLeft: Radius.circular(isMine ? AppRadius.md : (isLastInGroup ? AppRadius.sm : AppRadius.md)),
      bottomRight: Radius.circular(isMine ? (isLastInGroup ? AppRadius.sm : AppRadius.md) : AppRadius.md),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
        decoration: BoxDecoration(
          color: isMine ? AppColors.bubbleOutbound : AppColors.bubbleInbound,
          borderRadius: radius,
          border: Border.all(
            color: isMine
                ? AppColors.primary.withValues(alpha: 0.18)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (senderLabel != null && senderLabel!.isNotEmpty && !isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                child: Text(
                  senderLabel!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primarySoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (replyPreview != null && replyPreview!.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppSpacing.xxs),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border(
                    left: BorderSide(
                      color: isMine ? AppColors.primarySoft : AppColors.textMuted,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  replyPreview!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
              ),
            Text(text, style: AppTypography.body.copyWith(color: AppColors.textPrimary)),
            if (isLastInGroup && !failed && (timeLabel != null || status != null || statusLabel != null))
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (timeLabel != null && timeLabel!.isNotEmpty)
                      Text(
                        timeLabel!,
                        style: AppTypography.caption.copyWith(fontSize: 11, color: AppColors.textMuted),
                      ),
                    if (status != null) ...[
                      if (timeLabel != null && timeLabel!.isNotEmpty) const SizedBox(width: 4),
                      _InlineStatusIcon(status: status!),
                    ] else if (statusLabel != null && statusLabel!.isNotEmpty) ...[
                      if (timeLabel != null && timeLabel!.isNotEmpty)
                        Text(' · ', style: AppTypography.caption.copyWith(fontSize: 11)),
                      Text(statusLabel!, style: AppTypography.caption.copyWith(fontSize: 11)),
                    ],
                  ],
                ),
              ),
            if (failed)
              AppTextButton(label: 'Не отправлено · Повторить', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _InlineStatusIcon extends StatelessWidget {
  const _InlineStatusIcon({required this.status});

  final ChatDeliveryStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == ChatDeliveryStatus.sending) {
      return Icon(Icons.schedule, size: 13, color: AppColors.textMuted);
    }
    if (status == ChatDeliveryStatus.read) {
      return Icon(Icons.done_all_rounded, size: 14, color: AppColors.primarySoft);
    }
    return Icon(Icons.check_rounded, size: 14, color: AppColors.textMuted);
  }
}
