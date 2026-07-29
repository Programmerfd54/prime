import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/media/media_validation.dart';
import '../../../design/glass.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../app_icon_button.dart';

class PendingAttachment {
  const PendingAttachment({
    required this.bytes,
    required this.filename,
    required this.mimeType,
    required this.isImage,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
  final bool isImage;
}

/// Mature chat input bar: attach, multiline field, preview, send.
class AppChatComposer extends StatelessWidget {
  const AppChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onAttach,
    this.pending,
    this.onRemovePending,
    this.uploading = false,
    this.uploadProgress,
    this.onCancelUpload,
    this.replyPreview,
    this.onCancelReply,
    this.quickReplies = const [],
    this.onQuickReply,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final PendingAttachment? pending;
  final VoidCallback? onRemovePending;
  final bool uploading;
  final double? uploadProgress;
  final VoidCallback? onCancelUpload;
  final String? replyPreview;
  final VoidCallback? onCancelReply;
  final List<String> quickReplies;
  final ValueChanged<String>? onQuickReply;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.zero,
      padding: EdgeInsets.zero,
      fillOpacity: 0.08,
      sigma: 12,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (quickReplies.isNotEmpty && replyPreview == null && pending == null)
                _QuickReplyRow(
                  labels: quickReplies,
                  onTap: onQuickReply,
                ),
              if (replyPreview != null && replyPreview!.trim().isNotEmpty)
                _ReplyComposerPreview(
                  text: replyPreview!,
                  onCancel: onCancelReply,
                ),
              if (pending != null) _AttachmentPreview(
                attachment: pending!,
                uploading: uploading,
                progress: uploadProgress,
                onRemove: uploading ? onCancelUpload : onRemovePending,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppIconButton(
                    tooltip: 'Добавить в сообщение',
                    icon: Icons.add_rounded,
                    onPressed: uploading ? null : onAttach,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 5,
                      enabled: !uploading,
                      textInputAction: TextInputAction.newline,
                      style: AppTypography.body,
                      decoration: InputDecoration(
                        hintText: 'Сообщение',
                        hintStyle: AppTypography.bodySecondary,
                        filled: true,
                        fillColor: AppColors.surfaceSoft.withValues(alpha: 0.6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.5),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.sm,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  AppIconButton(
                    tooltip: 'Отправить',
                    icon: Icons.arrow_upward_rounded,
                    filled: true,
                    onPressed: _canSend ? onSend : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canSend {
    if (uploading) return false;
    if (pending != null) return true;
    return controller.text.trim().isNotEmpty;
  }
}

class _QuickReplyRow extends StatelessWidget {
  const _QuickReplyRow({required this.labels, this.onTap});

  final List<String> labels;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final label in labels)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xxs),
                child: ActionChip(
                  label: Text(label, style: AppTypography.caption),
                  backgroundColor: AppColors.surfaceSoft,
                  side: BorderSide(color: AppColors.border),
                  onPressed: onTap == null ? null : () => onTap!(label),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReplyComposerPreview extends StatelessWidget {
  const _ReplyComposerPreview({required this.text, this.onCancel});

  final String text;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        borderRadius: BorderRadius.circular(AppRadius.bentoInner),
        fillOpacity: 0.04,
        child: Row(
          children: [
            Icon(Icons.reply_rounded, size: 18, color: AppColors.primarySoft),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption,
              ),
            ),
            IconButton(
              tooltip: 'Отменить ответ',
              onPressed: onCancel,
              icon: const Icon(Icons.close, size: 18),
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.attachment,
    required this.uploading,
    this.progress,
    this.onRemove,
  });

  final PendingAttachment attachment;
  final bool uploading;
  final double? progress;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: GlassContainer(
        padding: const EdgeInsets.all(AppSpacing.xs),
        borderRadius: BorderRadius.circular(AppRadius.bentoInner),
        fillOpacity: 0.04,
        child: Row(
          children: [
            if (attachment.isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Image.memory(
                  attachment.bytes,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accentSurface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  Icons.insert_drive_file_outlined,
                  color: AppColors.primarySoft,
                ),
              ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(fontSize: 14),
                  ),
                  Text(
                    formatFileSize(attachment.bytes.length),
                    style: AppTypography.caption,
                  ),
                  if (uploading)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: AppColors.primaryContainer,
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: uploading ? 'Отменить' : 'Удалить',
              onPressed: onRemove,
              icon: Icon(uploading ? Icons.close : Icons.delete_outline),
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
