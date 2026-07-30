import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/failure_mapper.dart';
import '../../../core/media/media_urls.dart';
import '../../../core/media/media_validation.dart';
import '../../../core/validation/about_quality.dart';
import '../../../data/api_client.dart';
import '../../../design/lottie_registry.dart';
import '../../../design/prime/prime_toast_overlay.dart';
import '../../../design/routes.dart';
import '../../../providers/auth_provider.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../models/chat_message.dart';
import '../app_message_bubble.dart';
import '../app_primary_button.dart';
import '../app_snackbar.dart';
import '../app_text_button.dart';
import '../profile/about_before_team_sheet.dart';
import '../profile/app_avatar.dart';
import 'app_group_chat_message.dart' show groupReactionEmojis;

/// Renders direct chat rows including text, image, file, report and reactions.
class AppChatMessage extends StatelessWidget {
  const AppChatMessage({
    super.key,
    required this.message,
    required this.isMine,
    this.timeLabel,
    this.statusLabel,
    this.failed = false,
    this.onRetry,
    this.showAvatar = false,
    this.showMeta = true,
    this.isLastInGroup = true,
    this.isFirstInGroup = true,
    this.peerAvatarUrl,
    this.peerName,
    this.myAvatarUrl,
    this.myName,
    this.onReply,
    this.onReact,
    this.onPairInviteJoined,
  });

  final ChatMessageModel message;
  final bool isMine;
  final String? timeLabel;
  final String? statusLabel;
  final bool failed;
  final VoidCallback? onRetry;
  final bool showAvatar;
  final bool showMeta;
  final bool isLastInGroup;
  final bool isFirstInGroup;
  final String? peerAvatarUrl;
  final String? peerName;
  final String? myAvatarUrl;
  final String? myName;
  final VoidCallback? onReply;
  final ValueChanged<String>? onReact;
  final VoidCallback? onPairInviteJoined;

  @override
  Widget build(BuildContext context) {
    final bubble = _buildBubble(context);
    final reactions = message.reactions.isNotEmpty
        ? _ReactionBar(
            reactions: message.reactions,
            isMine: isMine,
            onReact: onReact,
          )
        : null;

    final content = Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        bubble,
        if (reactions != null) reactions,
      ],
    );

    Widget row = Row(
      mainAxisAlignment:
          isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMine) ...[
          if (showAvatar)
            AppAvatar(photoUrl: peerAvatarUrl, radius: 16, name: peerName ?? '?')
          else
            const SizedBox(width: 32),
          const SizedBox(width: AppSpacing.xs),
        ],
        Flexible(child: content),
        if (isMine) ...[
          const SizedBox(width: AppSpacing.xs),
          if (showAvatar)
            AppAvatar(photoUrl: myAvatarUrl, radius: 16, name: myName ?? '?')
          else
            const SizedBox(width: 32),
        ],
      ],
    );

    if (onReply != null) {
      row = GestureDetector(
        onLongPress: onReply,
        child: Dismissible(
          key: ValueKey('reply-${message.stableId}'),
          direction: isMine ? DismissDirection.endToStart : DismissDirection.startToEnd,
          confirmDismiss: (_) async {
            onReply!();
            return false;
          },
          background: Container(
            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Icon(Icons.reply_rounded, color: AppColors.primarySoft),
          ),
          child: row,
        ),
      );
    }

    final isCardMessage = message.isPairInvite || message.isReportMessage;
    final bottomGap = isCardMessage
        ? AppSpacing.sm
        : (isLastInGroup ? AppSpacing.sm : AppSpacing.xxs);
    final topGap = isFirstInGroup && isLastInGroup
        ? AppSpacing.xxs
        : (isFirstInGroup ? AppSpacing.xs : 0.0);

    return Padding(
      padding: EdgeInsets.only(top: topGap, bottom: bottomGap),
      child: row,
    );
  }

  Widget _buildBubble(BuildContext context) {
    if (message.deleted) {
      return AppMessageBubble(
        text: 'Сообщение удалено',
        isMine: isMine,
        timeLabel: showMeta ? timeLabel : null,
        statusLabel: showMeta ? statusLabel : null,
        status: message.deliveryStatus,
        failed: failed,
        onRetry: onRetry,
        isLastInGroup: isLastInGroup,
        replyPreview: message.replyPreview,
      );
    }

    if (message.isReportMessage) {
      return _ReportBubble(
        message: message,
        isMine: isMine,
        timeLabel: showMeta ? timeLabel : null,
        status: message.deliveryStatus,
        failed: failed,
        onRetry: onRetry,
        isLastInGroup: isLastInGroup,
      );
    }

    if (message.isPairInvite) {
      return _PairInviteBubble(
        message: message,
        isMine: isMine,
        timeLabel: showMeta ? timeLabel : null,
        onJoined: onPairInviteJoined,
      );
    }
    final msgtype = message.msgtype;
    if (msgtype == 'm.image') {
      return _ImageBubble(
        message: message,
        isMine: isMine,
        timeLabel: showMeta ? timeLabel : null,
        statusLabel: showMeta ? statusLabel : null,
        status: message.deliveryStatus,
        failed: failed,
        onRetry: onRetry,
        isLastInGroup: isLastInGroup,
        replyPreview: message.replyPreview,
      );
    }
    if (msgtype == 'm.file') {
      return _FileBubble(
        message: message,
        isMine: isMine,
        timeLabel: showMeta ? timeLabel : null,
        statusLabel: showMeta ? statusLabel : null,
        status: message.deliveryStatus,
        failed: failed,
        onRetry: onRetry,
        isLastInGroup: isLastInGroup,
        replyPreview: message.replyPreview,
      );
    }

    return AppMessageBubble(
      text: message.body,
      isMine: isMine,
      timeLabel: showMeta ? timeLabel : null,
      statusLabel: showMeta ? statusLabel : null,
      status: message.deliveryStatus,
      failed: failed,
      onRetry: onRetry,
      isLastInGroup: isLastInGroup,
      replyPreview: message.replyPreview,
    );
  }
}

class _PairInviteBubble extends StatefulWidget {
  const _PairInviteBubble({
    required this.message,
    required this.isMine,
    this.timeLabel,
    this.onJoined,
  });

  final ChatMessageModel message;
  final bool isMine;
  final String? timeLabel;
  final VoidCallback? onJoined;

  @override
  State<_PairInviteBubble> createState() => _PairInviteBubbleState();
}

class _PairInviteBubbleState extends State<_PairInviteBubble> {
  bool _joining = false;
  bool _joined = false;

  String get _inviteCode =>
      (widget.message.filename ?? '').trim();

  String get _skillName {
    final body = widget.message.body;
    final match = RegExp(r'«([^»]+)»').firstMatch(body);
    if (match != null && (match.group(1)?.isNotEmpty ?? false)) {
      return match.group(1)!;
    }
    final skillId = widget.message.contentType?.trim();
    if (skillId != null && skillId.isNotEmpty) return skillId;
    return 'привычка';
  }

  Future<void> _join() async {
    final code = _inviteCode;
    if (code.isEmpty || _joining || _joined || widget.isMine) return;

    final about = context.read<AuthProvider>().user?.about ?? '';
    if (AboutQuality.junkReason(about) != null) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Сначала напишите о себе — команда увидит это при знакомстве',
        variant: PrimeToastVariant.error,
        duration: const Duration(seconds: 5),
        actionLabel: 'Написать о себе',
        onAction: () async {
          final saved = await showAboutBeforeTeamSheet(
            context,
            reason: AboutBeforeTeamReason.pairInvite,
          );
          if (saved && mounted) {
            await _performJoin(code);
          }
        },
      );
      return;
    }

    await _performJoin(code);
  }

  Future<void> _performJoin(String code) async {
    if (_joining || _joined) return;
    setState(() => _joining = true);
    try {
      await context.read<ApiClient>().joinWaitingRoomPair(code);
      if (!mounted) return;
      setState(() => _joined = true);
      showAppSnackBar(
        context,
        'Вы в паре по «$_skillName». Продолжайте поиск в разделе Группы.',
      );
      widget.onJoined?.call();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, FailureMapper.from(e).message);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.habitSocial.withValues(alpha: 0.12),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.md),
            topRight: const Radius.circular(AppRadius.md),
            bottomLeft: Radius.circular(
              widget.isMine ? AppRadius.md : AppRadius.sm,
            ),
            bottomRight: Radius.circular(
              widget.isMine ? AppRadius.sm : AppRadius.md,
            ),
          ),
          border: Border.all(
            color: AppColors.habitSocial.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.group_add_outlined,
                  size: 18,
                  color: AppColors.habitSocial,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  'Приглашение в пару',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.habitSocial,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Привычка «$_skillName»',
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              widget.isMine
                  ? 'Приглашение отправлено. Ожидаем, пока друг нажмёт «Присоединиться».'
                  : 'Нажмите «Присоединиться» — вы автоматически встанете в поиск и попадёте в пару.',
              style: AppTypography.bodySecondary,
            ),
            if (!widget.isMine) ...[
              const SizedBox(height: AppSpacing.sm),
              AppPrimaryButton(
                label: _joined ? 'Вы в паре' : 'Присоединиться',
                icon: _joined ? Icons.check_rounded : Icons.handshake_outlined,
                loading: _joining,
                success: _joined,
                onPressed: _joined || _joining ? null : _join,
              ),
            ],
            if (widget.timeLabel != null && widget.timeLabel!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  widget.timeLabel!,
                  style: AppTypography.caption.copyWith(fontSize: 11),
                  textAlign: TextAlign.end,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReportBubble extends StatelessWidget {
  const _ReportBubble({
    required this.message,
    required this.isMine,
    this.timeLabel,
    this.status,
    this.failed = false,
    this.onRetry,
    this.isLastInGroup = true,
  });

  final ChatMessageModel message;
  final bool isMine;
  final String? timeLabel;
  final ChatDeliveryStatus? status;
  final bool failed;
  final VoidCallback? onRetry;
  final bool isLastInGroup;

  @override
  Widget build(BuildContext context) {
    final lines = message.body.split('\n');
    final headline = lines.isNotEmpty ? lines.first : message.body;
    final detail = lines.length > 1 ? lines.sublist(1).join('\n').trim() : '';
    final isReady = headline.contains('✅') || headline.contains('готов');

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.md),
            topRight: const Radius.circular(AppRadius.md),
            bottomLeft: Radius.circular(isMine ? AppRadius.md : AppRadius.sm),
            bottomRight: Radius.circular(isMine ? AppRadius.sm : AppRadius.md),
          ),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isReady ? Icons.check_circle_outline : Icons.edit_outlined,
                  size: 18,
                  color: AppColors.primarySoft,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  'Отчёт',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primarySoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(headline, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(detail, style: AppTypography.bodySecondary),
            ],
            if (timeLabel != null && timeLabel!.isNotEmpty && !failed)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(timeLabel!, style: AppTypography.caption.copyWith(fontSize: 11)),
                    if (isMine && status != null) ...[
                      const SizedBox(width: 4),
                      _StatusTicks(status: status!),
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

class _ReactionBar extends StatelessWidget {
  const _ReactionBar({
    required this.reactions,
    required this.isMine,
    this.onReact,
  });

  final List<ChatReactionModel> reactions;
  final bool isMine;
  final ValueChanged<String>? onReact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
        children: [
          for (final item in reactions)
            _ReactionChip(
              emoji: item.emoji,
              count: item.count,
              selected: item.reactedByMe,
              onTap: onReact,
            ),
          if (onReact != null) _AddReactionButton(onTap: onReact!),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.selected,
    this.onTap,
  });

  final String emoji;
  final int count;
  final bool selected;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap == null ? null : () => onTap!(emoji),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : AppColors.elevatedSurface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.45)
                : AppColors.border,
          ),
        ),
        child: Text(
          '$emoji $count',
          style: AppTypography.caption.copyWith(
            color: selected ? AppColors.primarySoft : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AddReactionButton extends StatelessWidget {
  const _AddReactionButton({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Реакция',
      onSelected: onTap,
      padding: EdgeInsets.zero,
      color: AppColors.elevatedSurface,
      itemBuilder: (context) => [
        for (final emoji in groupReactionEmojis)
          PopupMenuItem<String>(
            value: emoji,
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          '+',
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ImageBubble extends StatelessWidget {
  const _ImageBubble({
    required this.message,
    required this.isMine,
    this.timeLabel,
    this.statusLabel,
    this.status,
    this.failed = false,
    this.onRetry,
    this.isLastInGroup = true,
    this.replyPreview,
  });

  final ChatMessageModel message;
  final bool isMine;
  final String? timeLabel;
  final String? statusLabel;
  final ChatDeliveryStatus? status;
  final bool failed;
  final VoidCallback? onRetry;
  final bool isLastInGroup;
  final String? replyPreview;

  @override
  Widget build(BuildContext context) {
    final local = message.localPreviewBytes;
    final url = absoluteMediaUrl(message.url);
    final caption = message.body;
    final showCaption = caption.isNotEmpty &&
        caption != 'Изображение' &&
        caption != 'изображение';

    Widget image;
    if (local != null && local.isNotEmpty) {
      image = Image.memory(Uint8List.fromList(local), fit: BoxFit.cover);
    } else if (url != null) {
      image = Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            color: AppColors.surfaceSoft,
            alignment: Alignment.center,
            child: const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          color: AppColors.surfaceSoft,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: const PrimeLottie(
            slot: PrimeLottieSlot.imageNotPreview,
            width: 72,
            height: 72,
            repeat: false,
          ),
        ),
      );
    } else {
      image = Container(
        color: AppColors.surfaceSoft,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined),
      );
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
        decoration: BoxDecoration(
          color: isMine ? AppColors.bubbleOutbound : AppColors.bubbleInbound,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.md),
            topRight: const Radius.circular(AppRadius.md),
            bottomLeft: Radius.circular(isMine ? AppRadius.md : AppRadius.sm),
            bottomRight: Radius.circular(isMine ? AppRadius.sm : AppRadius.md),
          ),
          border: Border.all(
            color: isMine
                ? AppColors.primary.withValues(alpha: 0.18)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (replyPreview != null && replyPreview!.isNotEmpty)
              _ReplyPreview(text: replyPreview!, isMine: isMine),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md - 1),
              child: GestureDetector(
                onTap: url == null && local == null
                    ? null
                    : () => _openViewer(context, url, local),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 180, maxHeight: 280),
                  child: AspectRatio(aspectRatio: 4 / 3, child: image),
                ),
              ),
            ),
            if (showCaption)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Text(caption, style: AppTypography.body),
              ),
            _MetaRow(
              timeLabel: timeLabel,
              statusLabel: statusLabel,
              status: status,
              failed: failed,
              onRetry: onRetry,
            ),
          ],
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, String? url, List<int>? local) {
    Navigator.of(context).push(
      PrimeRoute.fadeThrough<void>(
        builder: (_) => _FullScreenImage(
          url: url,
          bytes: local != null ? Uint8List.fromList(local) : null,
        ),
      ),
    );
  }
}

class _FileBubble extends StatelessWidget {
  const _FileBubble({
    required this.message,
    required this.isMine,
    this.timeLabel,
    this.statusLabel,
    this.status,
    this.failed = false,
    this.onRetry,
    this.isLastInGroup = true,
    this.replyPreview,
  });

  final ChatMessageModel message;
  final bool isMine;
  final String? timeLabel;
  final String? statusLabel;
  final ChatDeliveryStatus? status;
  final bool failed;
  final VoidCallback? onRetry;
  final bool isLastInGroup;
  final String? replyPreview;

  @override
  Widget build(BuildContext context) {
    final filename = message.filename ?? 'Файл';
    final size = message.sizeBytes;
    final url = absoluteMediaUrl(message.url);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: url == null ? null : () => _openFile(url),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
            decoration: BoxDecoration(
              color: isMine ? AppColors.bubbleOutbound : AppColors.bubbleInbound,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AppRadius.md),
                topRight: const Radius.circular(AppRadius.md),
                bottomLeft: Radius.circular(isMine ? AppRadius.md : AppRadius.sm),
                bottomRight: Radius.circular(isMine ? AppRadius.sm : AppRadius.md),
              ),
              border: Border.all(
                color: isMine
                    ? AppColors.primary.withValues(alpha: 0.18)
                    : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (replyPreview != null && replyPreview!.isNotEmpty)
                  _ReplyPreview(text: replyPreview!, isMine: isMine),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
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
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            filename,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body.copyWith(fontSize: 14),
                          ),
                          if (size != null)
                            Text(formatFileSize(size), style: AppTypography.caption),
                        ],
                      ),
                    ),
                  ],
                ),
                _MetaRow(
                  timeLabel: timeLabel,
                  statusLabel: statusLabel,
                  status: status,
                  failed: failed,
                  onRetry: onRetry,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.text, required this.isMine});

  final String text;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
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
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    this.timeLabel,
    this.statusLabel,
    this.status,
    this.failed = false,
    this.onRetry,
  });

  final String? timeLabel;
  final String? statusLabel;
  final ChatDeliveryStatus? status;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!failed && (timeLabel != null || status != null))
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (timeLabel != null && timeLabel!.isNotEmpty)
                  Text(timeLabel!, style: AppTypography.caption.copyWith(fontSize: 11)),
                if (status != null) ...[
                  if (timeLabel != null && timeLabel!.isNotEmpty)
                    const SizedBox(width: 4),
                  _StatusTicks(status: status!),
                ] else if (statusLabel != null && statusLabel!.isNotEmpty) ...[
                  if (timeLabel != null && timeLabel!.isNotEmpty)
                    Text(' · ', style: AppTypography.caption.copyWith(fontSize: 11)),
                  Text(statusLabel!, style: AppTypography.caption.copyWith(fontSize: 11)),
                ],
              ],
            ),
          if (failed)
            AppTextButton(label: 'Не отправлено · Повторить', onPressed: onRetry),
        ],
      ),
    );
  }
}

class _StatusTicks extends StatelessWidget {
  const _StatusTicks({required this.status});

  final ChatDeliveryStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status == ChatDeliveryStatus.read
        ? AppColors.primarySoft
        : AppColors.textMuted;
    if (status == ChatDeliveryStatus.sending) {
      return Icon(Icons.schedule, size: 13, color: color);
    }
    if (status == ChatDeliveryStatus.read) {
      return Icon(Icons.done_all_rounded, size: 14, color: color);
    }
    return Icon(Icons.check_rounded, size: 14, color: color);
  }
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({this.url, this.bytes});

  final String? url;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: Center(
          child: bytes != null ? Image.memory(bytes!) : Image.network(url!),
        ),
      ),
    );
  }
}
