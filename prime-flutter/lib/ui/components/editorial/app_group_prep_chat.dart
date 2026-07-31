import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/chat/chat_system_grouping.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/groups/prep_chat_seen.dart';
import '../../../core/sync/chat_sync_controller.dart';
import '../../../core/sync/realtime_client.dart';
import '../../../data/api_client.dart';
import '../../../design/prime/prime_glass_surface.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../models/group.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/social_restriction_provider.dart';
import '../../../widgets/social_restriction_chat_panel.dart';
import '../app_snackbar.dart';
import '../chat/app_chat_composer.dart';
import '../chat/app_group_chat_message.dart';

/// Compact group chat pinned to the bottom during intro / rules confirmation.
class AppGroupPrepChat extends StatefulWidget {
  const AppGroupPrepChat({
    super.key,
    required this.groupId,
    required this.members,
  });

  final String groupId;
  final List<MemberModel> members;

  @override
  State<AppGroupPrepChat> createState() => _AppGroupPrepChatState();
}

class _AppGroupPrepChatState extends State<AppGroupPrepChat> {
  final _controller = TextEditingController();
  ChatSyncController? _sync;
  RealtimeClient? _realtime;
  bool _expanded = true;
  bool _sending = false;
  String? _mentionQuery;
  List<String> _mentionCandidates = const [];
  int _lastSeenCount = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    unawaited(_loadSeen());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final api = context.read<ApiClient>();
      _sync = ChatSyncController(api)
        ..pollInterval = const Duration(seconds: 2)
        ..start(kind: ChatChannelKind.group, channelId: widget.groupId);
      _sync!.addListener(_onSyncChanged);
      _realtime = context.read<RealtimeClient>();
      _realtime!.addGroupChatUpdateListener(_onGroupChatUpdate);
      unawaited(context.read<SocialRestrictionProvider>().refresh());
    });
  }

  Future<void> _loadSeen() async {
    _lastSeenCount = await PrepChatSeenStore.lastSeenCount(widget.groupId);
    if (mounted) setState(() {});
  }

  Future<void> _markSeen(int count) async {
    _lastSeenCount = count;
    await PrepChatSeenStore.markSeen(widget.groupId, count);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _sync?.removeListener(_onSyncChanged);
    _sync?.dispose();
    _realtime?.removeGroupChatUpdateListener(_onGroupChatUpdate);
    super.dispose();
  }

  void _onSyncChanged() {
    if (!mounted) return;
    final count = _sync?.messages.length ?? 0;
    if (_expanded) {
      unawaited(_markSeen(count));
    }
    setState(() {});
  }

  void _onGroupChatUpdate(GroupChatUpdatePush push) {
    if (push.groupId != widget.groupId || !mounted) return;
    unawaited(_sync?.sync(forceRefresh: true));
  }

  void _onTextChanged() {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    if (cursor < 0) {
      if (_mentionQuery != null) setState(() => _mentionQuery = null);
      return;
    }
    final beforeCursor = text.substring(0, cursor.clamp(0, text.length));
    final atIndex = beforeCursor.lastIndexOf('@');
    if (atIndex >= 0 &&
        (atIndex == 0 || beforeCursor[atIndex - 1] == ' ') &&
        !beforeCursor.substring(atIndex + 1).contains(' ')) {
      final query = beforeCursor.substring(atIndex + 1).toLowerCase();
      final nicknames = widget.members
          .map((m) => m.profile?.nickname ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      final matches = nicknames
          .where((n) => query.isEmpty || n.toLowerCase().startsWith(query))
          .take(5)
          .toList();
      setState(() {
        _mentionQuery = query;
        _mentionCandidates = matches;
      });
      return;
    }
    if (_mentionQuery != null) {
      setState(() {
        _mentionQuery = null;
        _mentionCandidates = const [];
      });
    }
  }

  void _insertMention(String nickname) {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    if (cursor < 0) return;
    final beforeCursor = text.substring(0, cursor.clamp(0, text.length));
    final atIndex = beforeCursor.lastIndexOf('@');
    if (atIndex < 0) return;
    final afterCursor = text.substring(cursor.clamp(0, text.length));
    final next = '${text.substring(0, atIndex)}@$nickname $afterCursor';
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: atIndex + nickname.length + 2,
      ),
    );
    setState(() {
      _mentionQuery = null;
      _mentionCandidates = const [];
    });
  }

  Future<void> _send() async {
    final sync = _sync;
    final me = context.read<AuthProvider>().user?.id;
    final text = _controller.text.trim();
    if (context.read<SocialRestrictionProvider>().isWriteBlocked) return;
    if (sync == null || text.isEmpty || _sending || me == null) return;
    setState(() => _sending = true);
    final draft = text;
    _controller.clear();
    try {
      await sync.sendText(draft, senderUserId: me);
    } catch (e) {
      if (mounted) {
        context.read<SocialRestrictionProvider>().applyFromError(e);
        if (_controller.text.trim().isEmpty) _controller.text = draft;
        showAppSnackBar(context, FailureMapper.from(e).message);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _segmentPreview(ChatDisplaySegment segment) {
    final system = PrimeSystemMessageCard.previewForSegment(segment);
    if (system != null) return system;
    final message = segment.message;
    if (message == null) return const SizedBox.shrink();
    final body = message['body']?.toString() ?? '';
    if (body.isEmpty) return const SizedBox.shrink();
    final p = context.prime;
    final senderProfile = message['sender_profile'];
    final senderMap =
        senderProfile is Map ? Map<String, dynamic>.from(senderProfile) : null;
    final nickname = (senderMap?['nickname'] ?? '').toString();
    final prefix = nickname.isNotEmpty ? '@$nickname: ' : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: AppSpacing.xs),
            decoration: BoxDecoration(
              color: p.brandSoft.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              '$prefix$body',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(color: p.inkSecondary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final sync = _sync;
    final readOnly = context.watch<SocialRestrictionProvider>().isWriteBlocked;
    final messages = sync?.messages ?? const <Map<String, dynamic>>[];
    final unread = PrepChatSeenStore.unreadCount(messages.length, _lastSeenCount);
    final segments = buildChatDisplaySegments(messages);
    final recent = segments.length <= 4
        ? segments
        : segments.sublist(segments.length - 4);

    return PrimeGlassSurface(
      variant: PrimeGlassVariant.toolbar,
      radius: 0,
      padding: EdgeInsets.zero,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () {
                setState(() => _expanded = !_expanded);
                if (!_expanded) return;
                unawaited(_markSeen(messages.length));
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xxs,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: p.mint.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline,
                        size: 17,
                        color: p.mint,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Чат команды',
                        style: AppTypography.title2.copyWith(
                          fontSize: 15,
                          color: p.ink,
                        ),
                      ),
                    ),
                    if (unread > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: p.brand.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          '$unread',
                          style: AppTypography.caption.copyWith(
                            color: p.brandSoft,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    const SizedBox(width: AppSpacing.xxs),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      color: p.inkMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded && recent.isNotEmpty)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: p.surfaceSoft.withValues(alpha: 0.35),
                  border: Border(
                    top: BorderSide(color: p.hairline.withValues(alpha: 0.7)),
                    bottom: BorderSide(color: p.hairline.withValues(alpha: 0.5)),
                  ),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 168),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    itemCount: recent.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.xxs),
                    itemBuilder: (context, index) =>
                        _segmentPreview(recent[index]),
                  ),
                ),
              ),
            if (_expanded) const SocialRestrictionChatPanel(),
            if (_expanded && _mentionCandidates.isNotEmpty)
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  itemCount: _mentionCandidates.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xxs),
                  itemBuilder: (context, index) {
                    final nick = _mentionCandidates[index];
                    return ActionChip(
                      label: Text('@$nick'),
                      onPressed: () => _insertMention(nick),
                    );
                  },
                ),
              ),
            if (_expanded)
              AppChatComposer(
                controller: _controller,
                onSend: _send,
                onAttach: () {},
                uploading: _sending,
                readOnly: readOnly,
                embedded: true,
              ),
          ],
        ),
      ),
    );
  }
}
