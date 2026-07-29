import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../core/media/media_urls.dart';
import '../../../data/api_client.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../app_text_button.dart';
import '../profile/app_avatar.dart';

const groupReactionEmojis = ['🔥', '💪', '✅', '❤️', '👏', '⚡'];

/// Group chat row — sender, reactions, image/video/text/system.
class AppGroupChatMessage extends StatelessWidget {
  const AppGroupChatMessage({
    super.key,
    required this.message,
    required this.isOwn,
    required this.timeLabel,
    required this.onReact,
    this.failed = false,
    this.onRetry,
  });

  final Map<String, dynamic> message;
  final bool isOwn;
  final String timeLabel;
  final ValueChanged<String> onReact;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _GroupMessageBody(
      message: message,
      isOwn: isOwn,
      timeLabel: timeLabel,
      onReact: onReact,
      failed: failed,
      onRetry: onRetry,
    );
  }
}

class _GroupMessageBody extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isOwn;
  final String timeLabel;
  final ValueChanged<String> onReact;
  final bool failed;
  final VoidCallback? onRetry;
  const _GroupMessageBody({
    required this.message,
    required this.isOwn,
    required this.timeLabel,
    required this.onReact,
    this.failed = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final msgtype = message['msgtype'] ?? 'm.text';
    final body = message['body'] ?? '';
    final url = absoluteMediaUrl(message['url']?.toString());
    final sender = message['sender'] ?? '';
    final senderProfile = message['sender_profile'];
    final senderMap =
        senderProfile is Map ? Map<String, dynamic>.from(senderProfile) : null;
    final nickname = (senderMap?['nickname'] ?? '').toString();
    final name = (senderMap?['name'] ?? '').toString();
    final displayName = nickname.isNotEmpty
        ? '@$nickname'
        : name.isNotEmpty
            ? name
            : sender.toString().split(':')[0].replaceFirst('@', '');
    final avatarUrl = absoluteMediaUrl(senderMap?['photo_url']?.toString());
    final authorization =
        context.read<ApiClient>().dio.options.headers['Authorization'];
    final mediaHeaders = authorization == null
        ? <String, String>{}
        : <String, String>{'Authorization': authorization.toString()};
    final isSystem = msgtype == 'm.room.message' && sender.isEmpty;
    final isPrimeSystem = msgtype == 'prime.system' ||
        msgtype == 'prime.nudge' ||
        body.toString().startsWith('🎉 День закрыт') ||
        body.toString().startsWith('⏳ Осталось');
    final isReportCard = msgtype == 'prime.report' ||
        body.toString().startsWith('✅ Отчёт') ||
        body.toString().startsWith('✏️ Отчёт');

    if (isPrimeSystem || isSystem) {
      if (isReportCard) {
        return _ReportSystemCard(body: body.toString());
      }
      return _PrimeSystemCard(
        body: body.toString(),
        isCelebration: body.toString().startsWith('🎉') ||
            msgtype == 'prime.system',
        isNudge: msgtype == 'prime.nudge' ||
            body.toString().startsWith('⏳'),
      );
    }

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadius.md),
      topRight: const Radius.circular(AppRadius.md),
      bottomLeft: Radius.circular(isOwn ? AppRadius.md : AppRadius.sm),
      bottomRight: Radius.circular(isOwn ? AppRadius.sm : AppRadius.md),
    );

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.74,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isOwn ? AppColors.bubbleOutbound : AppColors.bubbleInbound,
        borderRadius: radius,
        border: Border.all(
          color: isOwn
              ? AppColors.primary.withValues(alpha: 0.18)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isOwn)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                displayName,
                style: AppTypography.caption.copyWith(
                  color: AppColors.primarySoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (msgtype == 'm.image' && url != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.network(
                url,
                headers: mediaHeaders,
                width: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.broken_image,
                  color: AppColors.textMuted,
                ),
              ),
            )
          else if ((msgtype == 'm.video' || msgtype == 'prime.video_note') &&
              url != null)
            _VideoMessage(
              url: url,
              headers: mediaHeaders,
              round: msgtype == 'prime.video_note',
            )
          else if (msgtype == 'prime.report')
            _ReportCardBody(body: body.toString())
          else
            Text(
              body,
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          if ((msgtype == 'm.image' ||
                  msgtype == 'm.video' ||
                  msgtype == 'prime.video_note') &&
              body.toString().trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                body,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (!failed && timeLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  timeLabel,
                  style: AppTypography.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          if (failed)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Align(
                alignment: Alignment.centerRight,
                child: AppTextButton(
                  label: 'Не отправлено · Повторить',
                  onPressed: onRetry,
                ),
              ),
            ),
        ],
      ),
    );

    final content = Column(
      crossAxisAlignment:
          isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        bubble,
        _ReactionBar(
          reactions: message['reactions'],
          onReact: onReact,
          isOwn: isOwn,
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        mainAxisAlignment:
            isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwn) ...[
            _GroupSenderAvatar(name: displayName, imageUrl: avatarUrl),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(child: content),
        ],
      ),
    );
  }
}

class _PrimeSystemCard extends StatelessWidget {
  const _PrimeSystemCard({
    required this.body,
    this.isCelebration = false,
    this.isNudge = false,
  });

  final String body;
  final bool isCelebration;
  final bool isNudge;

  @override
  Widget build(BuildContext context) {
    final accent = isCelebration
        ? AppColors.success
        : (isNudge ? AppColors.habitSocial : AppColors.primary);
    final lines = body.split('\n');
    final headline = lines.isNotEmpty ? lines.first : body;
    final detail = lines.length > 1 ? lines.sublist(1).join('\n').trim() : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Center(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.16),
                AppColors.elevatedSurface,
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Icon(
                isCelebration
                    ? Icons.emoji_events_outlined
                    : (isNudge
                        ? Icons.notifications_active_outlined
                        : Icons.info_outline),
                color: accent,
                size: 22,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (detail.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportSystemCard extends StatelessWidget {
  const _ReportSystemCard({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final lines = body.split('\n');
    final headline = lines.isNotEmpty ? lines.first : body;
    final detail = lines.length > 1 ? lines.sublist(1).join('\n').trim() : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Center(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Text(
                headline,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.primarySoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (detail.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportCardBody extends StatelessWidget {
  const _ReportCardBody({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final lines = body.split('\n');
    final headline = lines.isNotEmpty ? lines.first : body;
    final detail = lines.length > 1 ? lines.sublist(1).join('\n').trim() : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flag_outlined, size: 16, color: AppColors.primarySoft),
            const SizedBox(width: 4),
            Text(
              'Отчёт',
              style: AppTypography.caption.copyWith(
                color: AppColors.primarySoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(headline, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
        if (detail.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(detail, style: AppTypography.bodySecondary),
          ),
      ],
    );
  }
}

class _ReactionBar extends StatelessWidget {
  final Object? reactions;
  final ValueChanged<String> onReact;
  final bool isOwn;

  const _ReactionBar({
    required this.reactions,
    required this.onReact,
    required this.isOwn,
  });

  @override
  Widget build(BuildContext context) {
    final items = (reactions as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        alignment: isOwn ? WrapAlignment.end : WrapAlignment.start,
        children: [
          for (final item in items)
            _ReactionChip(
              emoji: item['emoji']?.toString() ?? '',
              count: item['count'] as int? ?? 0,
              selected: item['reacted_by_me'] as bool? ?? false,
              onTap: onReact,
            ),
          _AddReactionButton(onTap: onReact),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String emoji;
  final int count;
  final bool selected;
  final ValueChanged<String> onTap;

  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (emoji.isEmpty || count <= 0) return const SizedBox.shrink();
    return InkWell(
      onTap: () => onTap(emoji),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryContainer
              : AppColors.elevatedSurface,
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
  final ValueChanged<String> onTap;

  const _AddReactionButton({required this.onTap});

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
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 22),
            ),
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

class _GroupSenderAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;

  const _GroupSenderAvatar({required this.name, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return AppAvatar(photoUrl: imageUrl, radius: 16, name: name);
  }
}

class _VideoMessage extends StatefulWidget {
  final String url;
  final Map<String, String> headers;
  final bool round;

  const _VideoMessage({
    required this.url,
    required this.headers,
    required this.round,
  });

  @override
  State<_VideoMessage> createState() => _VideoMessageState();
}

class _VideoMessageState extends State<_VideoMessage> {
  late VideoPlayerController _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant _VideoMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller.dispose();
      _initController();
    }
  }

  void _initController() {
    _error = null;
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: widget.headers,
    )
      ..setLooping(false)
      ..addListener(() {
        if (mounted) setState(() {});
      })
      ..initialize().then((_) {
        if (mounted) setState(() {});
      }).catchError((error) {
        if (mounted) setState(() => _error = error);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!_controller.value.isInitialized) return;
    _controller.value.isPlaying ? _controller.pause() : _controller.play();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.round ? 154.0 : 220.0;
    final height = widget.round ? 154.0 : 132.0;
    final initialized = _controller.value.isInitialized;
    final hasError = _error != null || _controller.value.hasError;

    Widget child;
    if (hasError) {
      child = Center(
        child: Icon(Icons.broken_image, color: AppColors.textMuted, size: 42),
      );
    } else if (!initialized) {
      child = Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      );
    } else if (widget.round) {
      final videoSize = _controller.value.size;
      child = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: videoSize.width,
          height: videoSize.height,
          child: VideoPlayer(_controller),
        ),
      );
    } else {
      child = AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      );
    }

    final content = GestureDetector(
      onTap: _toggle,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ColoredBox(color: AppColors.deepSurface, child: child),
          if (!initialized || !_controller.value.isPlaying)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: AppColors.textPrimary,
                size: 34,
              ),
            ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: widget.round
          ? BorderRadius.circular(AppRadius.pill)
          : BorderRadius.circular(AppRadius.sm),
      child: SizedBox(width: size, height: height, child: content),
    );
  }
}
