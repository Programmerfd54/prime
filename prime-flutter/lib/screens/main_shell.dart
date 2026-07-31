import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/analytics/analytics.dart';
import '../core/groups/group_navigation.dart';
import '../core/notifications/native_push_service.dart';
import '../core/sync/realtime_client.dart';
import '../core/sync/waiting_room_poller.dart';
import '../data/api_client.dart';
import '../design/routes.dart';
import '../design/tokens.dart';
import '../l10n/copy.dart';
import '../providers/chats_inbox_provider.dart';
import '../core/pending/pending_search.dart';
import '../models/skill.dart';
import '../providers/auth_provider.dart';
import '../providers/social_restriction_provider.dart';
import '../ui/components/app_bottom_navigation.dart';
import '../ui/components/app_navigation_rail.dart';
import '../ui/components/app_snackbar.dart';
import '../ui/states/app_connection_banner.dart';
import 'chats_screen.dart';
import 'dashboard_screen.dart';
import 'group_detail_screen.dart';
import 'groups_screen.dart';
import 'profile_screen.dart';
import 'skills_screen.dart';

/// Основная навигация приложения — phone bottom bar / tablet rail.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialTabIndex});

  /// Preselected tab, e.g. when the app was opened via a `/groups` or
  /// `/chats` deep link. When null, the last persisted tab (or the default
  /// "Главная" tab) is restored instead.
  final int? initialTabIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

/// SharedPreferences key backing the persisted, refresh-safe tab index.
const _tabIndexPrefsKey = 'prime_main_tab_index';

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 2;
  SkillModel? _selectedGroupSkill;
  int _groupsRefreshToken = 0;
  bool _groupsPreferSearchTab = false;
  String? _lastMatchedSnackGroupId;
  WaitingRoomPoller? _poller;
  RealtimeClient? _realtime;
  bool _openFriendSearch = false;

  static const _navItems = [
    AppBottomNavItem(
      icon: Icons.psychology_alt_outlined,
      selectedIcon: Icons.psychology_alt,
      label: AppCopy.habits,
      assetPath: 'assets/logo.png',
    ),
    AppBottomNavItem(
      icon: Icons.groups_2_outlined,
      selectedIcon: Icons.groups_2,
      label: 'Группы',
    ),
    AppBottomNavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Главная',
    ),
    AppBottomNavItem(
      icon: Icons.forum_outlined,
      selectedIcon: Icons.forum,
      label: 'Чаты',
    ),
    AppBottomNavItem(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Профиль',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialTabIndex != null) {
      _index = widget.initialTabIndex!;
      unawaited(_persistTabIndex(_index));
    } else {
      unawaited(_restoreTabIndex());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _poller = context.read<WaitingRoomPoller>();
      _poller!.addListener(_onPollerChanged);
      _realtime = context.read<RealtimeClient>();
      _realtime!.onMatch = _onRealtimeMatch;
      _realtime!.onNotificationPush = _onNotificationPush;
      _realtime!.onWaitingRoomUpdate = _onWaitingRoomUpdate;
      _realtime!.onGroupUpdate = _onGroupUpdate;
      _realtime!.addDirectMessageListener(_onDirectMessageInbox);
      _realtime!.start();
      unawaited(
        NativePushService.instance.start(
          context.read<ApiClient>(),
          onOpen: _onNativePushOpen,
        ),
      );
      _consumePendingSearch();
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _poller!.start();
        unawaited(context.read<ChatsInboxProvider>().ensureLoaded());
        unawaited(context.read<SocialRestrictionProvider>().refresh());
      });
    });
  }

  void _onDirectMessageInbox(DirectMessagePush push) {
    if (push.friendId.isEmpty || !mounted) return;
    final inbox = context.read<ChatsInboxProvider>();
    inbox.invalidate();
    unawaited(inbox.ensureLoaded(force: true));
    final msgtype = push.message?['msgtype'] as String? ?? '';
    if (msgtype == 'prime.pair_invite') {
      _refreshWaitingRoom();
    }
  }

  void _onWaitingRoomUpdate() {
    if (!mounted) return;
    _refreshWaitingRoom();
  }

  void _onGroupUpdate(String groupId) {
    if (!mounted || groupId.isEmpty) return;
    unawaited(context.read<ApiClient>().invalidateGroupsCache());
    setState(() => _groupsRefreshToken += 1);
  }

  void _refreshWaitingRoom() {
    final poller = _poller;
    if (poller == null) return;
    unawaited(poller.refresh().then((_) {
      if (!mounted) return;
      if (poller.inQueue) {
        poller.start(forceRefresh: true);
      }
    }));
  }

  void _onNotificationPush() {
    if (!mounted) return;
    final api = context.read<ApiClient>();
    unawaited(api.invalidateSocialCaches());
    final inbox = context.read<ChatsInboxProvider>();
    inbox.invalidate();
    unawaited(inbox.ensureLoaded(force: true));
  }

  void _onNativePushOpen(Map<String, dynamic> payload) {
    if (!mounted) return;
    final intent = parsePushPayload(payload);
    unawaited(context.read<ApiClient>().invalidateGroupsCache());
    setState(() {
      _groupsRefreshToken += 1;
      _groupsPreferSearchTab = intent.preferSearchTab;
      if (intent.skillId != null && intent.skillId!.isNotEmpty) {
        _selectedGroupSkill = SkillModel.fromJson({
          'id': intent.skillId,
          'name': payload['skill_name'] as String? ?? 'Программа',
          'description': '',
          'category': 'focus',
        });
      }
      _setIndex(1);
    });
    _refreshWaitingRoom();
    if (intent.groupId != null && intent.groupId!.isNotEmpty) {
      unawaited(
        openGroupDetail(
          context,
          groupId: intent.groupId!,
          host: ({preferSearchTab = false, skillId}) {
            if (!mounted) return;
            setState(() {
              _groupsPreferSearchTab = preferSearchTab;
              _groupsRefreshToken += 1;
            });
          },
        ),
      );
    }
  }

  /// Restores the last selected tab so a browser refresh (web) or app
  /// relaunch lands the user back where they left off, defaulting to
  /// "Главная" (index 2) when nothing was persisted yet.
  Future<void> _restoreTabIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_tabIndexPrefsKey);
      if (saved != null && saved >= 0 && saved < _navItems.length && mounted) {
        setState(() => _index = saved);
      }
    } catch (_) {
      // Best-effort restore; default tab remains.
    }
  }

  Future<void> _persistTabIndex(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_tabIndexPrefsKey, index);
    } catch (_) {
      // Persistence is best-effort; tab still works this session.
    }
  }

  /// Central setter for [_index] so every tab change is persisted the same
  /// way — call this instead of assigning `_index` directly inside setState.
  void _setIndex(int index) {
    _index = index;
    unawaited(_persistTabIndex(index));
  }

  Future<void> _consumePendingSearch() async {
    final skillId = await PendingSearch.read();
    if (skillId == null || !mounted) return;
    final api = context.read<ApiClient>();
    await PendingSearch.clear();
    try {
      final skills = await api.listSkills();
      if (!mounted) return;
      final match = skills.cast<Map<String, dynamic>>().firstWhere(
            (s) => s['id'] == skillId,
            orElse: () =>
                {'id': skillId, 'name': 'Программа', 'category': 'focus'},
          );
      setState(() {
        _selectedGroupSkill = SkillModel.fromJson(match);
        _groupsRefreshToken += 1;
        _setIndex(1);
      });
    } catch (_) {
      setState(() {
        _selectedGroupSkill = SkillModel.fromJson({
          'id': skillId,
          'name': 'Программа',
          'description': '',
          'category': 'focus',
        });
        _groupsRefreshToken += 1;
        _setIndex(1);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poller?.removeListener(_onPollerChanged);
    _poller?.pause();
    _realtime?.removeDirectMessageListener(_onDirectMessageInbox);
    _realtime?.stop();
    NativePushService.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final poller = _poller;
    if (poller == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        poller.resume();
        _realtime?.start();
        unawaited(_reconcileMembershipIfNeeded());
        unawaited(context.read<ApiClient>().invalidateGroupsCache());
        if (mounted) {
          setState(() => _groupsRefreshToken += 1);
        }
        unawaited(context.read<ChatsInboxProvider>().ensureLoaded(force: true));
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        poller.pause();
        _realtime?.stop();
    }
  }

  Future<void> _reconcileMembershipIfNeeded() async {
    if (!mounted) return;
    final api = context.read<ApiClient>();
    try {
      final overview = await api.groupsOverview(forceRefresh: true);
      if (overview['membership_consistent'] == true) return;
      await api.reconcileMembership();
      if (mounted) setState(() => _groupsRefreshToken += 1);
    } catch (_) {}
  }

  void _onRealtimeMatch(String groupId) {
    if (!mounted || groupId.isEmpty) return;
    if (_lastMatchedSnackGroupId == groupId) return;
    _lastMatchedSnackGroupId = groupId;
    Analytics.instance.teamReady(groupId);
    unawaited(context.read<ApiClient>().invalidateGroupsCache());
    _refreshWaitingRoom();
    showAppSnackBar(
      context,
      'Команда готова',
      actionLabel: 'Открыть',
      onAction: () {
        setState(() => _setIndex(1));
        Navigator.of(context).push(
          PrimeRoute.sharedAxis(
            builder: (_) => GroupDetailScreen(groupId: groupId),
          ),
        );
      },
    );
  }

  void _onPollerChanged() {
    final poller = _poller;
    if (poller == null || !mounted) return;
    final matchedId = poller.matchedGroupId;
    if (matchedId == null || matchedId.isEmpty) return;
    if (_lastMatchedSnackGroupId == matchedId) return;
    if (_index != 2) return;

    _lastMatchedSnackGroupId = matchedId;
    Analytics.instance.teamReady(matchedId);
    showAppSnackBar(
      context,
      'Команда готова',
      actionLabel: 'Открыть',
      onAction: () {
        Navigator.of(context).push(
          PrimeRoute.sharedAxis(
            builder: (_) => GroupDetailScreen(groupId: matchedId),
          ),
        );
      },
    );
  }

  void _openGroupsTab() {
    setState(() {
      _groupsPreferSearchTab = false;
      _setIndex(1);
    });
  }

  void _onNotificationNavigate({
    String? groupId,
    String? skillId,
    bool preferSearchTab = false,
  }) {
    setState(() {
      _groupsPreferSearchTab = preferSearchTab;
      _groupsRefreshToken += 1;
      if (skillId != null && skillId.isNotEmpty) {
        _selectedGroupSkill = SkillModel.fromJson({
          'id': skillId,
          'name': 'Программа',
          'description': '',
          'category': 'focus',
        });
      }
      _setIndex(groupId != null ? 1 : 2);
    });
    _refreshWaitingRoom();
    if (groupId != null && groupId.isNotEmpty) {
      unawaited(
        openGroupDetail(
          context,
          groupId: groupId,
          host: ({preferSearchTab = false, skillId}) {
            if (!mounted) return;
            setState(() {
              _groupsPreferSearchTab = preferSearchTab;
              _groupsRefreshToken += 1;
            });
          },
        ),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _groupsPreferSearchTab) {
        setState(() => _groupsPreferSearchTab = false);
      }
    });
  }

  void _openGroupsForSkill(SkillModel _) {
    setState(() {
      _selectedGroupSkill = null;
      _groupsRefreshToken += 1;
      _groupsPreferSearchTab = true;
      _setIndex(1);
    });
  }

  void _selectDestination(int i) {
    setState(() {
      if (i == 1) _groupsPreferSearchTab = false;
      _setIndex(i);
      if (i == 3) _groupsRefreshToken += 1;
    });
    if (i == 3) {
      unawaited(context.read<ChatsInboxProvider>().ensureLoaded());
    }
  }

  void _openFindFriend() {
    setState(() {
      _setIndex(3);
      _openFriendSearch = true;
    });
  }

  List<Widget> _buildPages() {
    return [
      SkillsScreen(onSearchStarted: _openGroupsForSkill),
      GroupsScreen(
        preselectedSkill: _selectedGroupSkill,
        refreshToken: _groupsRefreshToken,
        preferSearchTab: _groupsPreferSearchTab,
      ),
      DashboardScreen(
        onOpenHabits: () => setState(() => _setIndex(0)),
        onOpenChats: () => _selectDestination(3),
        onOpenGroups: _openGroupsTab,
        onNotificationNavigate: _onNotificationNavigate,
        refreshToken: _groupsRefreshToken,
      ),
      ChatsScreen(
        openFriendSearch: _openFriendSearch,
        refreshToken: _groupsRefreshToken,
        onFriendSearchOpened: () {
          if (_openFriendSearch) {
            setState(() => _openFriendSearch = false);
          }
        },
        onFindFriend: _openFindFriend,
        onOpenGroups: _openGroupsTab,
      ),
      ProfileScreen(onOpenGroups: _openGroupsTab),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final offlineMode = context.watch<AuthProvider>().offlineMode;
    final groupsMatched =
        context.watch<WaitingRoomPoller>().matchedGroupId != null;
    final chatsUnread = context.watch<ChatsInboxProvider>().unreadCount;
    final badgeIndices = <int>{
      if (groupsMatched) 1,
      if (chatsUnread > 0) 3,
    };
    final pages = _buildPages();

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= AppBreakpoints.tablet;
        final content = Column(
          children: [
            AppConnectionBanner(visible: offlineMode),
            Expanded(child: IndexedStack(index: _index, children: pages)),
          ],
        );

        if (useRail) {
          return Scaffold(
            body: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  AppNavigationRail(
                    items: _navItems,
                    selectedIndex: _index,
                    onSelected: _selectDestination,
                    badgeIndices: badgeIndices,
                  ),
                  VerticalDivider(width: 1, color: AppColors.border),
                  Expanded(child: content),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          body: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: SafeArea(
                  left: true,
                  right: true,
                  bottom: false,
                  minimum: const EdgeInsets.only(top: 4),
                  child: content,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: RepaintBoundary(
                  child: AppBottomNavigation(
                    selectedIndex: _index,
                    onSelected: _selectDestination,
                    badgeIndices: badgeIndices,
                    items: _navItems,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
