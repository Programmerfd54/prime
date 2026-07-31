import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/chat/chat_system_grouping.dart';
import '../core/errors/failure_mapper.dart';
import '../core/media/media_validation.dart';
import '../core/sync/chat_sync_controller.dart';
import '../core/sync/realtime_client.dart';
import '../data/api_client.dart';
import '../design/haptics.dart';
import '../design/routes.dart';
import '../design/theme/prime_theme_context.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/visuals/charts/charts.dart';
import '../l10n/copy.dart';
import '../models/group.dart';
import '../providers/auth_provider.dart';
import '../providers/social_restriction_provider.dart';
import '../ui/components/app_chat_date_separator.dart';
import '../ui/components/app_compact_button.dart';
import '../ui/components/app_header.dart';
import '../ui/components/app_snackbar.dart';
import '../ui/components/chat/app_chat_shell.dart';
import '../ui/components/chat/app_chat_composer.dart';
import '../ui/components/chat/app_group_chat_message.dart';
import '../ui/components/editorial/app_group_editorial.dart';
import '../ui/states/app_connection_banner.dart';
import '../ui/states/app_error_state.dart';
import '../ui/states/app_loading_state.dart';
import '../widgets/social_restriction_chat_panel.dart';
import 'group_detail_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  const GroupChatScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  ChatSyncController? _syncCtrl;
  RealtimeClient? _realtime;
  GroupModel? _group;
  bool _started = false;
  bool _sending = false;
  bool _loadingOlder = false;
  bool _showScrollToBottom = false;
  PendingAttachment? _pending;
  bool _uploading = false;
  double _uploadProgress = 0.0;
  CancelToken? _uploadCancelToken;

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
    _syncCtrl = ChatSyncController(context.read<ApiClient>())
      ..addListener(_onSyncChanged)
      ..start(kind: ChatChannelKind.group, channelId: widget.groupId);
    _realtime = context.read<RealtimeClient>()
      ..addGroupChatUpdateListener(_onGroupChatUpdate);
    unawaited(context.read<SocialRestrictionProvider>().refresh());
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    try {
      final raw = await context.read<ApiClient>().getGroup(widget.groupId);
      if (mounted) setState(() => _group = GroupModel.fromJson(raw));
    } catch (_) {}
  }

  void _onSyncChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onGroupChatUpdate(GroupChatUpdatePush push) {
    if (push.groupId != widget.groupId) return;
    unawaited(_syncCtrl?.sync(forceRefresh: true));
  }

  void _onScroll() {
    final sync = _syncCtrl;
    if (sync == null) return;
    if (_scrollController.hasClients) {
      final pos = _scrollController.position;
      final nearBottom = pos.maxScrollExtent - pos.pixels < 120;
      if (nearBottom != !_showScrollToBottom) {
        setState(() => _showScrollToBottom = !nearBottom);
      }
      if (pos.pixels < 100 && sync.hasMore && !_loadingOlder) {
        _loadOlder();
      }
    }
  }

  Future<void> _sync() async {
    await _syncCtrl?.sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final sync = _syncCtrl;
    if (sync == null) return;
    if (state == AppLifecycleState.resumed) {
      sync.resume();
    } else {
      sync.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _realtime?.removeGroupChatUpdateListener(_onGroupChatUpdate);
    _syncCtrl
      ?..removeListener(_onSyncChanged)
      ..dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOlder() async {
    final sync = _syncCtrl;
    if (sync == null || _loadingOlder) return;
    setState(() => _loadingOlder = true);
    try {
      await sync.loadOlder();
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppDurations.fast,
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    if (context.read<SocialRestrictionProvider>().isWriteBlocked) return;
    if (_pending != null) {
      await _sendPendingAttachment();
      return;
    }
    await _sendText();
  }

  Future<void> _sendText() async {
    final sync = _syncCtrl;
    final text = _controller.text.trim();
    final me = context.read<AuthProvider>().user?.id;
    if (sync == null || text.isEmpty || _sending || me == null) return;
    setState(() => _sending = true);
    final draft = text;
    _controller.clear();
    try {
      await sync.sendText(draft, senderUserId: me);
      await AppHaptics.send();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      context.read<SocialRestrictionProvider>().applyFromError(e);
      if (_controller.text.trim().isEmpty) _controller.text = draft;
      showAppSnackBar(context, FailureMapper.from(e).message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Uploads a validated pending image/file with real progress + cancel,
  /// mirroring the direct-chat attachment flow (parity fix for 5c).
  Future<void> _sendPendingAttachment() async {
    final sync = _syncCtrl;
    final pending = _pending;
    final me = context.read<AuthProvider>().user?.id;
    if (sync == null || pending == null || me == null) return;
    final cancelToken = CancelToken();
    setState(() {
      _uploading = true;
      _uploadCancelToken = cancelToken;
      _uploadProgress = 0;
    });
    final caption = _controller.text.trim();
    try {
      await sync.uploadAndSendMedia(
        senderUserId: me,
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
      if (!mounted) return;
      _controller.clear();
      setState(() => _pending = null);
      await AppHaptics.send();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      if (!cancelToken.isCancelled) {
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

  void _cancelUpload() => _uploadCancelToken?.cancel();

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 88,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    final mime = picked.mimeType ?? mimeFromFilename(picked.name) ?? 'image/jpeg';
    if (bytes.length > MediaLimits.directImageMaxBytes ||
        !MediaLimits.allowedImageTypes.contains(mime)) {
      showAppSnackBar(
        context,
        mediaValidationError(sizeBytes: bytes.length, mimeType: mime, isImage: true),
      );
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

  Future<void> _sendMedia({required String kind}) async {
    if (kIsWeb) {
      showAppSnackBar(context, 'В web-версии пока доступны только фото и текст');
      return;
    }
    XFile? x;
    if (kind == 'video') {
      x = await _picker.pickVideo(source: ImageSource.gallery);
    } else {
      x = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 60),
      );
    }
    if (!mounted) return;
    if (x == null || _sending) return;
    setState(() => _sending = true);
    final api = context.read<ApiClient>();
    final cancelToken = CancelToken();
    setState(() => _uploadCancelToken = cancelToken);
    try {
      final uploadResult = await api.chatUploadMedia(
        widget.groupId,
        File(x.path),
        cancelToken: cancelToken,
        onSendProgress: (sent, total) {
          if (total > 0 && mounted) setState(() => _uploadProgress = sent / total);
        },
      );
      final msgtype = kind == 'video' ? 'm.video' : 'prime.video_note';
      await api.chatSendMedia(widget.groupId, uploadResult, msgtype: msgtype);
      await _sync();
    } catch (e) {
      if (mounted && !cancelToken.isCancelled) {
        showAppSnackBar(context, ApiClient.errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _uploadProgress = 0;
          _uploadCancelToken = null;
        });
      }
    }
  }

  bool _isReportLike(Map<String, dynamic> message) {
    final msgtype = message['msgtype'] as String? ?? 'm.text';
    final body = message['body'] as String? ?? '';
    return msgtype == 'prime.report' ||
        body.startsWith('✅ Отчёт') ||
        body.startsWith('✏️ Отчёт');
  }

  Future<void> _toggleReaction(Map<String, dynamic> message, String emoji) async {
    final messageId = message['id']?.toString();
    if (messageId == null || messageId.isEmpty) return;
    try {
      final updated =
          await context.read<ApiClient>().chatToggleReaction(messageId, emoji);
      if (mounted) {
        final list = _syncCtrl?.messages;
        if (list != null) {
          final index = list.indexWhere((item) => item['id'] == updated['id']);
          if (index != -1) list[index] = updated;
        }
        setState(() {});
        if (updated['support_awarded'] == true &&
            _isReportLike(message) &&
            (emoji == '💪' || emoji == '✅')) {
          showAppSnackBar(context, '+1 Prime автору отчёта за поддержку');
        }
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, ApiClient.errorMessage(e));
    }
  }

  Future<void> _showAttachmentMenu() async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => Material(
        color: AppColors.surface,
        child: SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: AppColors.textSecondary),
                title: const Text('Фото из галереи', style: AppTypography.body),
                onTap: () => Navigator.pop(context, 'photo_gallery'),
              ),
              if (!kIsWeb)
                ListTile(
                  leading: Icon(Icons.photo_camera_outlined, color: AppColors.textSecondary),
                  title: const Text('Камера', style: AppTypography.body),
                  onTap: () => Navigator.pop(context, 'photo_camera'),
                ),
              ListTile(
                leading: Icon(Icons.insert_drive_file_outlined, color: AppColors.textSecondary),
                title: const Text('Файл', style: AppTypography.body),
                onTap: () => Navigator.pop(context, 'file'),
              ),
              if (!kIsWeb) ...[
                ListTile(
                  leading: Icon(Icons.video_library_outlined, color: AppColors.textSecondary),
                  title: const Text('Видео', style: AppTypography.body),
                  onTap: () => Navigator.pop(context, 'video'),
                ),
                ListTile(
                  leading: Icon(Icons.circle_outlined, color: AppColors.textSecondary),
                  title: const Text('Записать видеокружок', style: AppTypography.body),
                  subtitle: const Text('До 60 секунд', style: AppTypography.caption),
                  onTap: () => Navigator.pop(context, 'video_note'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (kind == null || !mounted) return;
    switch (kind) {
      case 'photo_gallery':
        await _pickImage(ImageSource.gallery);
      case 'photo_camera':
        await _pickImage(ImageSource.camera);
      case 'file':
        await _pickFile();
      default:
        await _sendMedia(kind: kind);
    }
  }

  void _showRulesDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Правила цикла', style: AppTypography.title2),
        content: const SingleChildScrollView(child: AppGroupRulesPanel()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  DateTime? _messageDate(Map<String, dynamic> message) {
    final raw = message['created_at'] ?? message['timestamp'];
    if (raw is String) return DateTime.tryParse(raw)?.toLocal();
    if (raw is int) {
      final ms = raw > 9999999999 ? raw : raw * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    }
    return null;
  }

  String _timeLabel(DateTime? date) {
    if (date == null) return '';
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
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

  List<_GroupListItem> _buildItems(List<Map<String, dynamic>> messages) {
    final segments = buildChatDisplaySegments(
      messages,
      includeDateSeparators: true,
      messageDate: _messageDate,
      dateSeparatorLabel: _dateSeparatorLabel,
    );
    return segments.map((segment) {
      if (segment.isSeparator) {
        return _GroupListItem.separator(segment.separatorLabel!);
      }
      if (segment.isSystemGroup) {
        return _GroupListItem.systemGroup(
          segment.messages!,
          segment.kind ?? ChatSystemGroupKind.generic,
        );
      }
      return _GroupListItem.message(segment.message!);
    }).toList();
  }

  bool _isOwnMessage(
    Map<String, dynamic> msg,
    String? currentUserId,
    String? currentMatrixId,
    String? currentUserIdCompact,
  ) {
    final sender = (msg['sender'] ?? '').toString();
    return msg['sender_user_id'] == currentUserId ||
        sender == currentMatrixId ||
        (currentUserIdCompact != null && sender.contains(currentUserIdCompact));
  }

  Widget _opaqueChatStrip({
    required Widget child,
    VoidCallback? onTap,
    Color? backgroundColor,
  }) {
    return AppChatHeaderStrip(onTap: onTap, child: child);
  }

  Widget _cycleHeader() {
    final p = context.prime;
    final group = _group;
    final cycleDay = AppGroupActiveCycleHero.cycleDayFromStart(group?.cycleStartAt);
    final label = cycleDay != null ? 'День $cycleDay из 30 · правила' : 'День — из 30 · правила';
    return _opaqueChatStrip(
      onTap: _showRulesDialog,
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 16,
            color: p.brandSoft,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: p.ink,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.inkMuted),
        ],
      ),
    );
  }

  bool _userReportedToday(String? userId) {
    final group = _group;
    if (group == null || userId == null) return false;
    for (final member in group.members) {
      if (member.userId == userId) {
        return member.reportStatus == 'ready';
      }
    }
    final waiting = group.teamDay?.waitingFor ??
        group.teamPulse?.waitingFor ??
        const <TeamWaitingMember>[];
    if (waiting.isEmpty) return false;
    return !waiting.any((w) => w.userId == userId);
  }

  Widget _dayStatusBar() {
    final p = context.prime;
    final group = _group;
    if (group == null) return const SizedBox.shrink();
    final teamDay = group.teamDay;
    final pulse = group.teamPulse;
    if (teamDay == null && pulse == null) return const SizedBox.shrink();

    final ready = teamDay?.readyCount ?? pulse?.completedToday ?? 0;
    final total = teamDay?.memberCount ??
        pulse?.totalActive ??
        group.membersCount.clamp(1, group.maxMembers);
    final complete = teamDay?.isComplete == true ||
        pulse?.isTeamDayComplete == true;
    final waiting = teamDay?.waitingFor.isNotEmpty == true
        ? teamDay!.waitingFor
        : (pulse?.waitingFor ?? const <TeamWaitingMember>[]);
    final waitingNames = waiting
        .map((m) => m.displayName)
        .where((n) => n.isNotEmpty)
        .take(3)
        .join(', ');
    final remaining = (total - ready).clamp(0, total);
    final me = context.read<AuthProvider>().user?.id;
    final reported = _userReportedToday(me);
    final statusText = complete
        ? 'День закрыт $ready/$total'
        : waitingNames.isNotEmpty
            ? '${AppCopy.waitingReports(remaining)}: $waitingNames'
            : '${AppCopy.waitingReports(remaining)} · $ready/$total';

    return _opaqueChatStrip(
      backgroundColor: complete
          ? p.mint.withValues(alpha: 0.12)
          : p.surface.withValues(alpha: 0.96),
      child: Row(
        children: [
          Icon(
            complete ? Icons.check_circle_outline : Icons.groups_outlined,
            size: 18,
            color: complete ? p.mint : p.brandSoft,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              statusText,
              style: AppTypography.caption.copyWith(
                color: complete ? p.mint : p.inkSecondary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!reported && !complete) ...[
            const SizedBox(width: AppSpacing.xs),
            AppCompactButton(
              label: 'Отчитаться',
              onPressed: () {
                Navigator.of(context).push(
                  PrimeRoute.sharedAxis(
                    builder: (_) => GroupDetailScreen(groupId: widget.groupId),
                  ),
                ).then((_) {
                  if (mounted) _loadGroup();
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyState() {
    final slots = (_group?.members ?? [])
        .take(6)
        .map(
          (m) => TeamRingSlot(
            name: m.profile?.name ?? m.profile?.nickname,
            photoUrl: m.profile?.photoUrl,
            filled: true,
          ),
        )
        .toList();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PrimeTeamRing(
              size: 200,
              slots: slots,
              centerLabel: widget.groupName.isEmpty ? 'Команда' : widget.groupName[0].toUpperCase(),
              centerSubtitle: '${_group?.membersCount ?? 0} участников',
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Поздоровайтесь и напишите, во сколько делаете действие',
              textAlign: TextAlign.center,
              style: AppTypography.bodySecondary.copyWith(
                color: context.prime.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthProvider>().user;
    final p = context.prime;
    final currentMatrixId = currentUser?.matrixUserId;
    final currentUserIdCompact = currentUser?.id.replaceAll('-', '');
    final sync = _syncCtrl;
    final loading = sync == null || (sync.loading && sync.messages.isEmpty);
    final error = sync?.error;
    final offline = sync?.offline ?? false;
    final messages = sync?.messages ?? const <Map<String, dynamic>>[];
    final items = _buildItems(messages);

    final readOnly = context.watch<SocialRestrictionProvider>().isWriteBlocked;

    return AppChatShell(
      appBar: AppChatAppBar(
        title: widget.groupName,
        avatar: CircleAvatar(
          radius: 18,
          backgroundColor: p.surfaceSoft,
          child: Text(
            widget.groupName.isEmpty ? '?' : widget.groupName[0].toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: p.inkSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: Icon(Icons.refresh_rounded, size: AppIconSizes.md, color: p.ink),
            onPressed: _sync,
          ),
        ],
      ),
      banner: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppConnectionBanner(visible: offline, onRetry: _sync),
          const SocialRestrictionChatPanel(),
        ],
      ),
      header: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _cycleHeader(),
          _dayStatusBar(),
        ],
      ),
      messageArea: loading
          ? const AppLoadingState(label: 'Загрузка чата…')
          : error != null && messages.isEmpty
              ? AppErrorState(
                  message: error,
                  correlationId: sync.errorCorrelationId,
                  onRetry: _sync,
                )
              : messages.isEmpty
                  ? _emptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
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
                        if (item.isSystemGroup) {
                          return PrimeSystemMessageCard.grouped(
                            groupKind: item.systemGroupKind!,
                            messages: item.systemGroupMessages!,
                          );
                        }
                        final msg = item.message!;
                        final failed = msg['_status'] == 'failed';
                        final clientId = msg['client_id']?.toString();
                        return AppGroupChatMessage(
                          message: msg,
                          isOwn: _isOwnMessage(
                            msg,
                            currentUser?.id,
                            currentMatrixId,
                            currentUserIdCompact,
                          ),
                          timeLabel: _timeLabel(_messageDate(msg)),
                          onReact: (emoji) => _toggleReaction(msg, emoji),
                          failed: failed,
                          onRetry: (!failed || clientId == null || clientId.isEmpty)
                              ? null
                              : () {
                                  final me = context.read<AuthProvider>().user?.id;
                                  if (me != null) {
                                    sync.retryFailed(clientId, senderUserId: me);
                                  }
                                },
                        );
                      },
                    ),
      composer: AppChatComposer(
        controller: _controller,
        onSend: _send,
        onAttach: _showAttachmentMenu,
        pending: _pending,
        onRemovePending: () => setState(() => _pending = null),
        uploading: _uploading || _sending,
        uploadProgress: _uploadProgress,
        onCancelUpload: _cancelUpload,
        readOnly: readOnly,
      ),
      showScrollToBottom: _showScrollToBottom && messages.isNotEmpty,
      onScrollToBottom: _scrollToBottom,
      scrollHeroTag: 'group_scroll_bottom',
    );
  }
}

class _GroupListItem {
  const _GroupListItem._({
    this.message,
    this.separatorLabel,
    this.systemGroupMessages,
    this.systemGroupKind,
  });

  factory _GroupListItem.message(Map<String, dynamic> message) =>
      _GroupListItem._(message: message);

  factory _GroupListItem.separator(String label) =>
      _GroupListItem._(separatorLabel: label);

  factory _GroupListItem.systemGroup(
    List<Map<String, dynamic>> messages,
    ChatSystemGroupKind kind,
  ) =>
      _GroupListItem._(
        systemGroupMessages: messages,
        systemGroupKind: kind,
      );

  final Map<String, dynamic>? message;
  final String? separatorLabel;
  final List<Map<String, dynamic>>? systemGroupMessages;
  final ChatSystemGroupKind? systemGroupKind;

  bool get isSeparator => separatorLabel != null;
  bool get isSystemGroup =>
      systemGroupMessages != null && systemGroupMessages!.length > 1;
}
