import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/api_client.dart';
import '../design/routes.dart';
import '../design/tokens.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../models/group.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../design/prime/prime_toast_overlay.dart';
import '../ui/components/app_snackbar.dart';
import '../ui/components/editorial/app_public_profile.dart';
import '../ui/components/prime_toast.dart';
import '../ui/kit/presentation/profile_about_card.dart';
import '../ui/kit/presentation/profile_compatibility.dart';
import '../ui/kit/presentation/profile_context_menu.dart';
import '../ui/kit/presentation/profile_editorial_widgets.dart';
import '../ui/kit/presentation/profile_page_layout.dart';
import '../ui/kit/presentation/profile_sections.dart';
import '../ui/kit/presentation/profile_states.dart';
import '../ui/kit/presentation/profile_surfaces.dart';
import '../ui/kit/presentation/profile_tabs.dart';
import '../ui/kit/presentation/profile_typography.dart';
import '../ui/kit/presentation/profile_view_model.dart';
import '../ui/kit/tokens/kit_layout.dart';
import 'direct_chat_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final UserPublic profile;
  final String? reportStatus;
  final bool? acceptedRules;

  const PublicProfileScreen({
    super.key,
    required this.profile,
    this.reportStatus,
    this.acceptedRules,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  bool _sendingInvite = false;
  bool _saved = false;
  bool _isFriend = false;
  List<String> _sharedHabits = const [];
  List<String> _sharedGroups = const [];
  GroupModel? _inviteGroup;
  double _scrollOffset = 0;
  PublicProfileTab _tab = PublicProfileTab.overview;
  UserPublic? _profile;

  final _heroMoreKey = GlobalKey();
  final _barMoreKey = GlobalKey();

  UserPublic get _activeProfile => _profile ?? widget.profile;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshProfile());
    _loadSharedContext();
  }

  Future<void> _refreshProfile() async {
    final nickname = widget.profile.nickname.trim();
    if (nickname.isEmpty) return;
    try {
      final raw = await context.read<ApiClient>().findUserByNickname(
            nickname,
            forceRefresh: true,
          );
      if (!mounted) return;
      final userJson = raw['user'];
      setState(() {
        if (userJson is Map) {
          _profile = UserPublic.fromJson(Map<String, dynamic>.from(userJson));
        }
        _isFriend = raw['is_friend'] as bool? ?? false;
      });
    } catch (_) {
      // Keep the passed-in snapshot on network errors.
    }
  }

  Future<void> _loadSharedContext() async {
    try {
      final rows = await context.read<ApiClient>().listGroups();
      final groups = rows
          .map((g) => GroupModel.fromJson(g as Map<String, dynamic>))
          .toList();
      final habits = <String>{};
      final groupNames = <String>{};
      GroupModel? openGroup;
      for (final group in groups) {
        final hasMember =
            group.members.any((m) => m.profile?.id == _activeProfile.id);
        if (hasMember) {
          if (group.skillName?.isNotEmpty == true) {
            habits.add(group.skillName!);
          }
          groupNames.add(group.name.isNotEmpty ? group.name : 'Команда');
        }
        if (group.status == GroupStatus.active &&
            group.membersCount < group.maxMembers &&
            openGroup == null) {
          openGroup = group;
        }
      }
      if (!mounted) return;
      setState(() {
        _sharedHabits = habits.toList();
        _sharedGroups = groupNames.toList();
        _inviteGroup = openGroup;
      });
    } catch (_) {}
  }

  Future<void> _openDirectChat(UserPublic profile) async {
    unawaited(context.read<ApiClient>().warmDirectMessagesCache(profile.id));
    if (!mounted) return;
    await Navigator.push(
      context,
      PrimeRoute.sharedAxis(
        builder: (_) => DirectChatScreen(friend: profile),
      ),
    );
  }

  Future<void> _inviteToTalk() async {
    final profile = _activeProfile;
    if (_sendingInvite || profile.nickname.isEmpty) return;

    if (_isFriend) {
      await _openDirectChat(profile);
      return;
    }

    setState(() => _sendingInvite = true);
    try {
      final result = await context
          .read<ApiClient>()
          .sendFriendRequestByNickname(profile.nickname);
      if (!mounted) return;
      final status = result['status'] as String? ?? 'pending';
      if (status == 'accepted') {
        setState(() => _isFriend = true);
        showAppSnackBar(context, 'Можно общаться — открываю личный чат');
        await _openDirectChat(profile);
      } else {
        PrimeToast.inviteSent(context);
      }
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, ApiClient.errorMessage(error));
    } finally {
      if (mounted) setState(() => _sendingInvite = false);
    }
  }

  void _inviteToTeam() {
    if (_inviteGroup != null) {
      showAppSnackBar(
        context,
        'Приглашение в «${_inviteGroup!.skillName ?? _inviteGroup!.name}» — скоро',
      );
      return;
    }
    showAppSnackBar(context, 'Скоро');
  }

  void _toggleSave() {
    setState(() => _saved = !_saved);
    showAppSnackBar(
      context,
      _saved ? 'Профиль сохранён' : 'Убрано из сохранённых',
    );
  }

  void _shareProfile() {
    showAppSnackBar(context, 'Ссылка на профиль скопирована');
  }

  void _showMoreActions(BuildContext? anchorContext) {
    final p = _activeProfile;
    ProfileContextMenu.show(
      context: context,
      nickname: p.nickname,
      anchorContext: anchorContext,
      onCopyNickname: () =>
          showAppSnackBar(context, 'Никнейм скопирован'),
      onInvite: _inviteGroup != null ? _inviteToTeam : null,
      onBlock: () => showAppSnackBar(context, 'Профиль скрыт'),
      onReport: () => showAppSnackBar(context, 'Жалоба — скоро'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _activeProfile;
    final projection = PublicProfileProjection.from(
      profile: p,
      habitNames: _sharedHabits,
      sharedGroups: _sharedGroups,
    );
    final currentUserId = context.watch<AuthProvider>().user?.id;
    final isSelf = currentUserId == p.id;
    final isBlocked = widget.reportStatus == 'blocked';

    final hero = ProfileHeroCard(
      displayName: projection.displayName,
      subtitle: projection.subtitle,
      photoUrl: projection.photoUrl,
      about: projection.about,
      tags: projection.tags,
      metrics: projection.metrics,
      showChart: projection.showChart,
      mode: ProfileHeroMode.public,
      scrollOffset: _scrollOffset,
      statusBadge: projection.statusBadge,
      showVerifiedBadge: p.emailVerified,
      onBack: () => Navigator.maybePop(context),
      onMessage: isSelf || isBlocked ? null : _inviteToTalk,
      onMore: isSelf || isBlocked
          ? null
          : () => _showMoreActions(_heroMoreKey.currentContext),
      moreButtonKey: _heroMoreKey,
    );

    const tabLabels = ['Обзор', 'Совместимость', 'Привычки', 'Достижения'];

    Widget tabBody() {
      switch (_tab) {
        case PublicProfileTab.overview:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (projection.publicStats.isNotEmpty) ...[
                ProfilePublicStatsRow(stats: projection.publicStats),
                const SizedBox(height: AppSpacing.md),
              ],
              if (projection.infoRows.isNotEmpty) ...[
                ProfileInfoRows(rows: projection.infoRows),
                const SizedBox(height: AppSpacing.md),
              ],
              if (projection.aboutData.hasVisibleContent)
                ProfileAboutCard(data: projection.aboutData),
              if (!isSelf &&
                  (_sharedHabits.isNotEmpty || _sharedGroups.isNotEmpty)) ...[
                const SizedBox(height: AppSpacing.md),
                ProfileSharedContextSection(
                  sharedHabits: _sharedHabits,
                  sharedGroups: _sharedGroups,
                ),
              ],
              if (widget.reportStatus != null || widget.acceptedRules != null)
                AppPublicProfileGroupStatus(
                  reportReady: widget.reportStatus == 'ready',
                  acceptedRules: widget.acceptedRules,
                ),
            ],
          );
        case PublicProfileTab.compatibility:
          return ProfileCompatibilitySection(
            compatibility: projection.compatibility,
          );
        case PublicProfileTab.habits:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (projection.tags.isEmpty)
                Text(
                  'Привычки скрыты или пока не выбраны',
                  style: ProfileTypography.secondary.copyWith(
                    color: ProfilePalette.coolGrey,
                  ),
                )
              else
                ProfileHabitTagsRow(tags: projection.tags),
              if (projection.aboutData.currentHabit?.isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.md),
                ProfileAboutCard(data: projection.aboutData),
              ],
            ],
          );
        case PublicProfileTab.achievements:
          return ProfileAchievementsSection(
            achievements: const [],
            successfulDays: p.successfulDays,
          );
      }
    }

    final sections = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isBlocked) ...[
            const ProfileBlockedBanner(),
            const SizedBox(height: AppSpacing.md),
          ],
          if (projection.isRestricted) ...[
            const ProfileRestrictedBanner(),
            const SizedBox(height: AppSpacing.md),
          ],
          ProfileTabBar(
            tabs: tabLabels,
            selectedIndex: _tab.index,
            onSelected: (i) =>
                setState(() => _tab = PublicProfileTab.values[i]),
          ),
          const SizedBox(height: AppSpacing.md),
          tabBody(),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: ProfileSurfaces.canvas,
      body: AmbientCanvas(
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification ||
                notification is ScrollMetricsNotification) {
              final next = notification.metrics.pixels.clamp(0.0, 120.0);
              if ((next - _scrollOffset).abs() > 0.5) {
                setState(() => _scrollOffset = next);
              }
            }
            return false;
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ProfilePageLayout(
                  hero: hero,
                  sections: sections,
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: isSelf
                      ? KitLayout.navBottomClearance
                      : ProfileActionBar.heightFor(context),
                ),
                sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: isSelf || isBlocked
          ? null
          : ProfileActionBar(
              primaryLabel: 'Написать',
              primaryLoading: _sendingInvite,
              onPrimary: _sendingInvite || p.nickname.isEmpty
                  ? null
                  : _inviteToTalk,
              secondaryLabel: _inviteGroup != null ? 'Пригласить' : null,
              onSecondary: _inviteGroup != null ? _inviteToTeam : null,
              onSave: _toggleSave,
              onShare: _shareProfile,
              onCopyNickname: () {
                Clipboard.setData(ClipboardData(text: p.nickname));
                showAppSnackBar(context, 'Никнейм скопирован');
              },
              onBlock: () => showAppSnackBar(context, 'Профиль скрыт'),
              onReport: () => showAppSnackBar(
                context,
                'Жалоба — скоро',
                variant: PrimeToastVariant.warning,
              ),
              moreButtonKey: _barMoreKey,
            ),
    );
  }
}
