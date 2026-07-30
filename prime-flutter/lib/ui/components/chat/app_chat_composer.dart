import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/media/media_validation.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';

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

/// Telegram-style chat input: pill field + circular send button.
class AppChatComposer extends StatefulWidget {
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
  State<AppChatComposer> createState() => _AppChatComposerState();
}

class _AppChatComposerState extends State<AppChatComposer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant AppChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  bool get _canSend {
    if (widget.uploading) return false;
    if (widget.pending != null) return true;
    return widget.controller.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.98),
        border: Border(top: BorderSide(color: p.hairline)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
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
              if (widget.quickReplies.isNotEmpty &&
                  widget.replyPreview == null &&
                  widget.pending == null)
                _QuickReplyRow(
                  labels: widget.quickReplies,
                  onTap: widget.onQuickReply,
                ),
              if (widget.replyPreview != null &&
                  widget.replyPreview!.trim().isNotEmpty)
                _ReplyComposerPreview(
                  text: widget.replyPreview!,
                  onCancel: widget.onCancelReply,
                ),
              if (widget.pending != null)
                _AttachmentPreview(
                  attachment: widget.pending!,
                  uploading: widget.uploading,
                  progress: widget.uploadProgress,
                  onRemove: widget.uploading
                      ? widget.onCancelUpload
                      : widget.onRemovePending,
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: p.surfaceSoft,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(color: p.hairline),
                      ),
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: widget.uploading ? null : widget.onAttach,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.add_rounded,
                                  size: 22,
                                  color: widget.uploading
                                      ? p.inkMuted
                                      : p.inkSecondary,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: widget.controller,
                              minLines: 1,
                              maxLines: 5,
                              enabled: !widget.uploading,
                              textInputAction: TextInputAction.newline,
                              style: AppTypography.body.copyWith(color: p.ink),
                              cursorColor: p.brand,
                              decoration: InputDecoration(
                                hintText: 'Сообщение',
                                hintStyle: AppTypography.bodySecondary.copyWith(
                                  color: p.inkMuted,
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 10,
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Material(
                    color: _canSend
                        ? p.brand
                        : p.surfaceSoft.withValues(alpha: 0.9),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: _canSend ? widget.onSend : null,
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          size: 22,
                          color: _canSend ? Colors.white : p.inkMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickReplyRow extends StatelessWidget {
  const _QuickReplyRow({required this.labels, this.onTap});

  final List<String> labels;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final label in labels)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: p.brandContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: onTap == null ? null : () => onTap!(label),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Text(
                        label,
                        style: AppTypography.caption.copyWith(
                          color: p.inkSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
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
    final p = context.prime;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: p.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.hairline),
        ),
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
    final p = context.prime;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: p.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.hairline),
        ),
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
