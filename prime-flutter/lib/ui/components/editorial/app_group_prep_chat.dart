import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/failure_mapper.dart';
import '../../../core/sync/chat_sync_controller.dart';
import '../../../core/sync/realtime_client.dart';
import '../../../data/api_client.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../models/group.dart';
import '../../../providers/auth_provider.dart';
import '../app_snackbar.dart';
import '../chat/app_chat_composer.dart';

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

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final api = context.read<ApiClient>();
      _sync = ChatSyncController(api)
        ..pollInterval = const Duration(seconds: 2)
        ..start(kind: ChatChannelKind.group, channelId: widget.groupId);
      _sync!.addListener(_onSyncChanged);
      _realtime = context.read<RealtimeClient>();
      _realtime!.addGroupChatUpdateListener(_onGroupChatUpdate);
    });
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
    if (mounted) setState(() {});
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
    if (sync == null || text.isEmpty || _sending || me == null) return;
    setState(() => _sending = true);
    final draft = text;
    _controller.clear();
    try {
      await sync.sendText(draft, senderUserId: me);
    } catch (e) {
      if (mounted) {
        if (_controller.text.trim().isEmpty) _controller.text = draft;
        showAppSnackBar(context, FailureMapper.from(e).message);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _senderLabel(Map<String, dynamic> message) {
    final profile = message['sender_profile'];
    if (profile is Map) {
      final nickname = profile['nickname']?.toString() ?? '';
      if (nickname.isNotEmpty) return '@$nickname';
      final name = profile['name']?.toString() ?? '';
      if (name.isNotEmpty) return name;
    }
    return 'Участник';
  }

  Widget _mentionRichText(String body, TextStyle style) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'@(\w+)');
    var start = 0;
    for (final match in pattern.allMatches(body)) {
      if (match.start > start) {
        spans.add(TextSpan(text: body.substring(start, match.start), style: style));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: style.copyWith(
            color: context.prime.brandSoft,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      start = match.end;
    }
    if (start < body.length) {
      spans.add(TextSpan(text: body.substring(start), style: style));
    }
    return RichText(
      text: TextSpan(children: spans.isEmpty ? [TextSpan(text: body, style: style)] : spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final sync = _sync;
    final messages = sync?.messages ?? const <Map<String, dynamic>>[];
    final recent = messages.length <= 3
        ? messages
        : messages.sublist(messages.length - 3);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.98),
        border: Border(top: BorderSide(color: p.hairline)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xxs,
                ),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 18, color: p.mint),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Чат команды',
                        style: AppTypography.title2.copyWith(
                          fontSize: 15,
                          color: p.ink,
                        ),
                      ),
                    ),
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
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: recent.length,
                  itemBuilder: (context, index) {
                    final msg = recent[index];
                    final body = msg['body']?.toString() ?? '';
                    if (body.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_senderLabel(msg)}: ',
                            style: AppTypography.caption.copyWith(
                              color: p.inkSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Expanded(
                            child: _mentionRichText(
                              body,
                              AppTypography.caption.copyWith(color: p.inkSecondary),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            if (_mentionCandidates.isNotEmpty)
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
            AppChatComposer(
              controller: _controller,
              onSend: _send,
              onAttach: () {},
              uploading: _sending,
            ),
          ],
        ),
      ),
    );
  }
}
