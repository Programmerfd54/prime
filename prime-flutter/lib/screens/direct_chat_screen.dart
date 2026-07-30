import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../core/analytics/analytics.dart';
import '../core/errors/failure_mapper.dart';
import '../core/media/media_validation.dart';
import '../core/sync/chat_sync_controller.dart';
import '../data/api_client.dart';
import '../design/haptics.dart';
import '../design/routes.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../models/chat_message.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/chats_inbox_provider.dart';
import '../core/sync/realtime_client.dart';
import '../core/sync/waiting_room_poller.dart';
import '../ui/components/app_chat_date_separator.dart';
import '../ui/components/app_dialog.dart';
import '../ui/components/app_header.dart';
import '../ui/components/app_snackbar.dart';
import '../ui/components/chat/app_chat_shell.dart';
import '../ui/components/chat/app_chat_composer.dart';
import '../ui/components/chat/app_chat_message.dart';
import '../ui/components/profile/app_avatar.dart';
import '../ui/states/app_connection_banner.dart';
import '../ui/states/app_empty_state.dart';
import '../ui/states/app_error_state.dart';
import 'public_profile_screen.dart';

class DirectChatScreen extends StatefulWidget {
  const DirectChatScreen({
    super.key,
    required this.friend,
    this.embedded = false,
    this.onMessageSent,
  });

  final UserPublic friend;
  final bool embedded;
  final VoidCallback? onMessageSent;

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen>
    with WidgetsBindingObserver {
  final _messageCtrl = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  late ChatSyncController _sync;
  var _started = false;
  var _initialized = false;
  var _loadingOlder = false;
  var _showScrollToBottom = false;
  RealtimeClient? _realtime;
  PendingAttachment? _pending;
  var _uploading = false;
  var _uploadProgress = 0.0;
  CancelToken? _uploadCancelToken;
  ChatMessageModel? _replyTo;
  String? _stickyDayLabel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_initChat());
  }

  Future<void> _initChat() async {
    final api = context.read<ApiClient>();
    final cached = api.peekDirectMessagesCacheSync(widget.friend.id);

    _sync = ChatSyncController(api)
      ..addListener(_onSync)
      ..start(
        kind: ChatChannelKind.direct,
        channelId: widget.friend.id,
        cachedPayload: cached,
      );
    _realtime = context.read<RealtimeClient>()
      ..addDirectMessageListener(_onDirectMessage)
      ..addDirectChatReadListener(_onDirectChatRead);
    if (mounted) setState(() => _initialized = true);

    unawaited(
      api.peekDirectMessagesCache(widget.friend.id).then((diskCache) {
        if (!mounted || diskCache == null) return;
        _sync.warmCache(diskCache);
      }),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _markReadLocally();
      unawaited(_markConversationReadOnServer());
    });
  }

  void _markReadLocally() {
    if (!mounted) return;
    context.read<ChatsInboxProvider>().patchUnread(widget.friend.id, unread: 0);
  }

  Future<void> _markConversationReadOnServer() async {
    try {
      await context.read<ApiClient>().markDirectChatRead(widget.friend.id);
    } catch (_) {
      // Inbox badge is cleared locally; server catches up on next open or sync.
    }
  }

  void _onDirectChatRead(DirectChatReadPush push) {
    if (push.friendId != widget.friend.id) return;
    _sync.applyPeerReadAt(push.readAt);
    if (mounted) setState(() {});
  }

  void _onDirectMessage(DirectMessagePush push) {
    if (push.friendId != widget.friend.id) return;
    if (push.message != null) {
      _sync.applyIncomingMessage(push.message!);
      if (mounted) setState(() {});
      _scrollToBottom();
      _markReadLocally();
      unawaited(_markConversationReadOnServer());
      return;
    }
    unawaited(_refreshThreadFromServer());
  }

  Future<void> _refreshThreadFromServer() async {
    await context.read<ApiClient>().invalidateDirectMessagesCache(widget.friend.id);
    await _sync.bumpSync();
    if (!mounted) return;
    setState(() {});
    if (_sync.messages.isEmpty) return;
    final last = _sync.messages.last;
    if (last['sender_user_id'] == widget.friend.id) {
      _scrollToBottom();
      _markReadLocally();
      unawaited(_markConversationReadOnServer());
    }
  }

  void _onSync() {
    if (!mounted) return;
    setState(() {});
    if (_sync.messages.isEmpty) return;
    final last = _sync.messages.last;
    if (last['sender_user_id'] == widget.friend.id) {
      _scrollToBottom();
      _markReadLocally();
      unawaited(_markConversationReadOnServer());
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final nearBottom = pos.maxScrollExtent - pos.pixels < 120;
    if (nearBottom != !_showScrollToBottom) {
      setState(() => _showScrollToBottom = !nearBottom);
    }
    _updateStickyDay(_sync.messages);
    if (pos.pixels < 80 && _sync.hasMore && !_loadingOlder) {
      _loadOlder();
    }
  }

  void _updateStickyDay(List<Map<String, dynamic>> messages) {
    if (!_scrollController.hasClients || messages.isEmpty) return;
    final items = _buildItems(messages);
    final approxIndex = (_scrollController.offset / 64).floor().clamp(0, items.length - 1);
    String? label;
    for (var i = approxIndex; i >= 0; i--) {
      if (items[i].isSeparator) {
        label = items[i].separatorLabel;
        break;
      }
    }
    if (label != _stickyDayLabel && mounted) {
      setState(() => _stickyDayLabel = label);
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_sync.hasMore) return;
    setState(() => _loadingOlder = true);
    final beforeExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    await _sync.loadOlder();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final afterExtent = _scrollController.position.maxScrollExtent;
      final delta = afterExtent - beforeExtent;
      if (delta > 0) {
        _scrollController.jumpTo(_scrollController.offset + delta);
      }
    });
    setState(() => _loadingOlder = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sync.resume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _sync.pause();
    }
  }

  @override
  void dispose() {
    _realtime?.removeDirectMessageListener(_onDirectMessage);
    _realtime?.removeDirectChatReadListener(_onDirectChatRead);
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    if (_initialized) {
      _sync
        ..removeListener(_onSync)
        ..dispose();
    }
    _messageCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: AppDurations.fast,
        curve: Curves.easeOut,
      );
    });
  }

  void _setReply(ChatMessageModel message) {
    setState(() => _replyTo = message);
  }

  void _clearReply() => setState(() => _replyTo = null);

  String _replyPreviewFor(ChatMessageModel message) {
    if (message.msgtype == 'm.image') return 'Изображение';
    if (message.msgtype == 'm.file') return message.filename ?? 'Файл';
    final body = message.body.trim();
    if (body.length > 100) return '${body.substring(0, 97)}...';
    return body;
  }

  Future<void> _send() async {
    final me = context.read<AuthProvider>().user?.id;
    if (me == null) return;

    if (_pending != null) {
      await _sendPending(me);
      return;
    }

    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;
    final draft = text;
    final reply = _replyTo;
    _messageCtrl.clear();
    _clearReply();
    Analytics.instance.messageSendStarted(channel: 'direct');
    try {
      await _sync.sendText(
        draft,
        senderUserId: me,
        replyToId: reply?.id,
        replyPreview: reply != null ? _replyPreviewFor(reply) : null,
      );
      Analytics.instance.messageSendSuccess(channel: 'direct');
      await AppHaptics.send();
      _scrollToBottom();
      widget.onMessageSent?.call();
    } catch (e) {
      // sendText returns immediately; delivery errors surface on the bubble.
      Analytics.instance.messageSendFailed(
        channel: 'direct',
        type: FailureMapper.from(e).runtimeType.toString(),
      );
    }
  }

  Future<void> _sendPending(String meId) async {
    final pending = _pending;
    if (pending == null) return;
    final cancelToken = CancelToken();
    setState(() {
      _uploading = true;
      _uploadCancelToken = cancelToken;
      _uploadProgress = 0;
    });
    final caption = _messageCtrl.text.trim();
    Analytics.instance.chatAttachmentStarted(channel: 'direct');
    try {
      await _sync.uploadAndSendMedia(
        senderUserId: meId,
        bytes: pending.bytes,
        filename: pending.filename,
        contentType: pending.mimeType,
        isImage: pending.isImage,
        caption: caption.isEmpty ? null : caption,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
        cancelToken: cancelToken,
      );
      Analytics.instance.chatAttachmentSucceeded(channel: 'direct');
      if (!mounted) return;
      _messageCtrl.clear();
      setState(() => _pending = null);
      await AppHaptics.send();
      _scrollToBottom();
      widget.onMessageSent?.call();
    } catch (e) {
      final cancelled = cancelToken.isCancelled;
      if (!cancelled) {
        Analytics.instance.chatAttachmentFailed(
          channel: 'direct',
          type: FailureMapper.from(e).runtimeType.toString(),
        );
      }
      if (!mounted) return;
      if (!cancelled) {
        showAppSnackBar(context, FailureMapper.from(e).message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadProgress = 0;
          _uploadCancelToken = null;
        });
      }
    }
  }

  Future<void> _toggleReaction(ChatMessageModel message, String emoji) async {
    final messageId = message.id;
    if (messageId == null || messageId.isEmpty) return;
    try {
      final updated =
          await context.read<ApiClient>().directToggleReaction(messageId, emoji);
      final index = _sync.messages.indexWhere((item) => item['id'] == updated['id']);
      if (index != -1) _sync.messages[index] = updated;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) showAppSnackBar(context, ApiClient.errorMessage(e));
    }
  }

  Future<void> _showAttachSheet() async {
    final action = await showAppBottomSheet<_AttachAction>(
      context: context,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                'Добавить в сообщение',
                style: AppTypography.titleSerif,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Фото из галереи'),
              onTap: () => Navigator.pop(context, _AttachAction.gallery),
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Камера'),
                onTap: () => Navigator.pop(context, _AttachAction.camera),
              ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Файл'),
              onTap: () => Navigator.pop(context, _AttachAction.file),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _AttachAction.gallery:
        await _pickImage(ImageSource.gallery);
      case _AttachAction.camera:
        await _pickImage(ImageSource.camera);
      case _AttachAction.file:
        await _pickFile();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 2048,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    final mime = picked.mimeType ?? mimeFromFilename(picked.name) ?? 'image/jpeg';
    final error = mediaValidationError(
      sizeBytes: bytes.length,
      mimeType: mime,
      isImage: true,
    );
    if (bytes.length > MediaLimits.directImageMaxBytes ||
        !MediaLimits.allowedImageTypes.contains(mime)) {
      showAppSnackBar(context, error);
      return;
    }
    setState(() {
      _pending = PendingAttachment(
        bytes: bytes,
        filename: picked.name.isNotEmpty ? picked.name : 'photo.jpg',
        mimeType: mime,
        isImage: true,
      );
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const [
        'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'zip',
      ],
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      showAppSnackBar(context, 'Не удалось прочитать файл');
      return;
    }
    final mime = mimeFromFilename(file.name) ?? 'application/octet-stream';
    if (bytes.length > MediaLimits.directFileMaxBytes ||
        (!MediaLimits.allowedFileTypes.contains(mime) &&
            !mime.startsWith('image/'))) {
      showAppSnackBar(
        context,
        mediaValidationError(sizeBytes: bytes.length, mimeType: mime, isImage: false),
      );
      return;
    }
    setState(() {
      _pending = PendingAttachment(
        bytes: bytes,
        filename: file.name,
        mimeType: mime,
        isImage: false,
      );
    });
  }

  void _cancelUpload() => _uploadCancelToken?.cancel();

  void _openPublicProfile() {
    Navigator.of(context).push(
      PrimeRoute.sharedAxis(builder: (_) => PublicProfileScreen(profile: widget.friend)),
    );
  }

  String _dateSeparatorLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Сегодня';
    if (diff == 1) return 'Вчера';
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd.$mm.${date.year}';
  }

  String _timeLabel(DateTime? date) {
    if (date == null) return '';
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  List<_ChatListItem> _buildItems(List<Map<String, dynamic>> messages) {
    final items = <_ChatListItem>[];
    DateTime? lastDay;
    final meId = context.read<AuthProvider>().user?.id;
    for (final raw in messages) {
      final model = ChatMessageModel.fromJson(
        raw,
        currentUserId: meId,
        peerLastReadAt: _sync.peerLastReadAt,
      );
      final date = model.createdAt;
      if (date != null) {
        final day = DateTime(date.year, date.month, date.day);
        if (lastDay == null || day != lastDay) {
          items.add(_ChatListItem.separator(_dateSeparatorLabel(date)));
          lastDay = day;
        }
      }
      items.add(_ChatListItem.message(model));
    }
    return items;
  }

  _MessageGroupMeta _groupMeta(List<_ChatListItem> items, int index, String? meId) {
    final item = items[index];
    if (!item.isMessage) {
      return const _MessageGroupMeta(showAvatar: false, showMeta: false, isLastInGroup: true);
    }
    final current = item.message!;
    final senderKey = current.senderUserId ?? '';

    bool isLastInGroup = true;
    bool isFirstInGroup = true;
    final breaksGroup = current.isPairInvite || current.isReportMessage;
    for (var i = index + 1; i < items.length; i++) {
      final next = items[i];
      if (next.isSeparator) break;
      if (next.isMessage) {
        final nextBreaks = next.message!.isPairInvite || next.message!.isReportMessage;
        isLastInGroup =
            breaksGroup || nextBreaks || next.message!.senderUserId != senderKey;
        break;
      }
    }
    for (var i = index - 1; i >= 0; i--) {
      final prev = items[i];
      if (prev.isSeparator) break;
      if (prev.isMessage) {
        final prevBreaks = prev.message!.isPairInvite || prev.message!.isReportMessage;
        isFirstInGroup =
            breaksGroup || prevBreaks || prev.message!.senderUserId != senderKey;
        break;
      }
    }

    return _MessageGroupMeta(
      showAvatar: isLastInGroup,
      showMeta: isLastInGroup,
      isLastInGroup: isLastInGroup,
      isFirstInGroup: isFirstInGroup,
    );
  }

  String? _avatarUrl(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return null;
    if (photoUrl.startsWith('http')) return photoUrl;
    if (photoUrl.startsWith('/')) return '$apiBaseUrl$photoUrl';
    return '$apiBaseUrl/$photoUrl';
  }

  Widget _messageArea(ChatSyncController sync) {
    if (sync.messages.isNotEmpty) {
      final items = _buildItems(sync.messages);
      return Stack(
        children: [
          ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            itemCount: items.length + (_loadingOlder ? 1 : 0),
            itemBuilder: (context, index) {
              if (_loadingOlder && index == 0) {
                return Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                );
              }
              final itemIndex = _loadingOlder ? index - 1 : index;
              final item = items[itemIndex];
              if (item.isSeparator) {
                return AppChatDateSeparator(label: item.separatorLabel!);
              }
              final message = item.message!;
              final meId = context.read<AuthProvider>().user?.id;
              final me = context.read<AuthProvider>().user;
              final isMine = message.senderUserId == meId;
              final group = _groupMeta(items, itemIndex, meId);
              final failed =
                  message.deliveryStatus == ChatDeliveryStatus.failed;
              return AppChatMessage(
                message: message,
                isMine: isMine,
                timeLabel: group.showMeta ? _timeLabel(message.createdAt) : null,
                failed: failed,
                showAvatar: group.showAvatar,
                showMeta: group.showMeta,
                isLastInGroup: group.isLastInGroup,
                isFirstInGroup: group.isFirstInGroup,
                peerAvatarUrl: _avatarUrl(widget.friend.photoUrl),
                peerName: widget.friend.name.isEmpty
                    ? '@${widget.friend.nickname}'
                    : widget.friend.name,
                myAvatarUrl: _avatarUrl(me?.photoUrl),
                myName: me?.name.isNotEmpty == true ? me!.name : me?.nickname,
                onReply: () => _setReply(message),
                onReact: message.id == null
                    ? null
                    : (emoji) => _toggleReaction(message, emoji),
                onRetry: meId == null
                    ? null
                    : () => sync.retryFailed(
                          message.clientId ?? message.id!,
                          senderUserId: meId,
                        ),
                onPairInviteJoined: () {
                  final poller = context.read<WaitingRoomPoller>();
                  unawaited(poller.refresh());
                  if (poller.inQueue) {
                    poller.start(forceRefresh: true);
                  }
                },
              );
            },
          ),
          AppChatStickyDateHeader(label: _stickyDayLabel),
        ],
      );
    }

    if (!_initialized) {
      return const Center(
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (sync.error != null) {
      return AppErrorState(
        message: sync.error!,
        correlationId: sync.errorCorrelationId,
        onRetry: () => sync.sync(forceRefresh: true),
      );
    }

    return const AppEmptyState(
      title: 'Начните общение',
      subtitle:
          'Напишите первое сообщение — собеседник увидит его без обновления.',
      icon: Icons.chat_bubble_outline,
    );
  }

  Widget _composerFor(ChatSyncController sync) {
    if (!_initialized) {
      return const SizedBox.shrink();
    }
    return AppChatComposer(
      controller: _messageCtrl,
      onSend: _send,
      onAttach: _showAttachSheet,
      pending: _pending,
      onRemovePending: () => setState(() => _pending = null),
      uploading: _uploading,
      uploadProgress: _uploadProgress,
      onCancelUpload: _cancelUpload,
      replyPreview: _replyTo != null ? _replyPreviewFor(_replyTo!) : null,
      onCancelReply: _clearReply,
      quickReplies: directQuickReplies,
      onQuickReply: (text) {
        _messageCtrl.text = text;
        _messageCtrl.selection =
            TextSelection.collapsed(offset: text.length);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAction = IconButton(
      tooltip: 'Посмотреть профиль',
      icon: const Icon(Icons.person_outline_rounded),
      onPressed: _openPublicProfile,
    );

    if (!_initialized) {
      final title = widget.friend.name.isEmpty
          ? '@${widget.friend.nickname}'
          : widget.friend.name;
      return AppChatShell(
        appBar: AppChatAppBar(
          title: title,
          subtitle: '@${widget.friend.nickname}',
          onTitleTap: _openPublicProfile,
          avatar: AppAvatar(photoUrl: widget.friend.photoUrl, radius: 18, name: title),
          actions: [profileAction],
        ),
        messageArea: const Center(
          child: SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        composer: const SizedBox.shrink(),
      );
    }

    final sync = _sync;
    final title = widget.friend.name.isEmpty
        ? '@${widget.friend.nickname}'
        : widget.friend.name;

    return AppChatShell(
      appBar: AppChatAppBar(
        title: title,
        subtitle: '@${widget.friend.nickname}',
        onTitleTap: _openPublicProfile,
        avatar: AppAvatar(photoUrl: widget.friend.photoUrl, radius: 18, name: title),
        actions: [profileAction],
      ),
      banner: AppConnectionBanner(
        visible: sync.offline,
        onRetry: () => sync.sync(forceRefresh: true),
      ),
      messageArea: _messageArea(sync),
      composer: _composerFor(sync),
      showScrollToBottom: _showScrollToBottom && sync.messages.isNotEmpty,
      onScrollToBottom: _scrollToBottom,
      scrollBottomOffset: widget.embedded ? 88 : 96,
      scrollHeroTag: 'scroll_bottom_${widget.friend.id}',
    );
  }
}

class _ChatListItem {
  const _ChatListItem._({this.message, this.separatorLabel});

  factory _ChatListItem.message(ChatMessageModel message) =>
      _ChatListItem._(message: message);

  factory _ChatListItem.separator(String label) =>
      _ChatListItem._(separatorLabel: label);

  final ChatMessageModel? message;
  final String? separatorLabel;

  bool get isSeparator => separatorLabel != null;
  bool get isMessage => message != null;
}

class _MessageGroupMeta {
  const _MessageGroupMeta({
    required this.showAvatar,
    required this.showMeta,
    required this.isLastInGroup,
    this.isFirstInGroup = true,
  });

  final bool showAvatar;
  final bool showMeta;
  final bool isLastInGroup;
  final bool isFirstInGroup;
}

enum _AttachAction { gallery, camera, file }
