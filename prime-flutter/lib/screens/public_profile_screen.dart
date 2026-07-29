import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/api_client.dart';
import '../design/routes.dart';
import '../design/tokens.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../models/group.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../ui/components/app_dialog.dart';
import '../ui/components/app_snackbar.dart';
import '../ui/components/editorial/app_public_profile.dart';
import '../ui/components/prime_toast.dart';
import '../ui/kit/presentation/profile_editorial_widgets.dart';
import '../ui/kit/presentation/profile_page_layout.dart';
import '../ui/kit/presentation/profile_sections.dart';
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
  List<String> _sharedHabits = const [];
  List<String> _sharedGroups = const [];
  GroupModel? _inviteGroup;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _loadSharedContext();
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
            group.members.any((m) => m.profile?.id == widget.profile.id);
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

  Future<void> _inviteToTalk() async {
    final profile = widget.profile;
    if (_sendingInvite || profile.nickname.isEmpty) return;
    setState(() => _sendingInvite = true);
    try {
      final result = await context
          .read<ApiClient>()
          .sendFriendRequestByNickname(profile.nickname);
      if (!mounted) return;
      final status = result['status'] as String? ?? 'pending';
      if (status == 'accepted') {
        showAppSnackBar(context, 'Можно общаться — открываю личный чат');
        Navigator.push(
          context,
          PrimeRoute.sharedAxis(
            builder: (_) => DirectChatScreen(friend: profile),
          ),
        );
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

  void _showMoreActions() {
    final p = widget.profile;
    showAppBottomSheet<void>(
      context: context,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (p.nickname.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.alternate_email),
                title: Text('Скопировать @${p.nickname}'),
                onTap: () {
                  Navigator.pop(context);
                  showAppSnackBar(context, 'Никнейм скопирован');
                },
              ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Пожаловаться'),
              onTap: () {
                Navigator.pop(context);
                showAppSnackBar(context, 'Жалоба — скоро');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final projection = PublicProfileProjection.from(
      profile: p,
      habitNames: _sharedHabits,
      sharedGroups: _sharedGroups,
    );
    final currentUserId = context.watch<AuthProvider>().user?.id;
    final isSelf = currentUserId == p.id;

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
      onBack: () => Navigator.maybePop(context),
      onMessage: isSelf ? null : _inviteToTalk,
      onMore: isSelf ? null : _showMoreActions,
    );

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
          if (projection.isRestricted) ...[
            const ProfileRestrictedBanner(),
            const SizedBox(height: AppSpacing.md),
          ],
          if (!isSelf)
            ProfileSharedContextSection(
              sharedHabits: _sharedHabits,
              sharedGroups: _sharedGroups,
            ),
          if (!isSelf &&
              (_sharedHabits.isNotEmpty || _sharedGroups.isNotEmpty))
            const SizedBox(height: AppSpacing.md),
          if (projection.aboutRows.isNotEmpty) ...[
            ProfileAboutSection(rows: projection.aboutRows),
            const SizedBox(height: AppSpacing.md),
          ],
          if (widget.reportStatus != null || widget.acceptedRules != null)
            AppPublicProfileGroupStatus(
              reportReady: widget.reportStatus == 'ready',
              acceptedRules: widget.acceptedRules,
            ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
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
      bottomNavigationBar: isSelf
          ? null
          : ProfileActionBar(
              primaryLabel: 'Написать',
              primaryLoading: _sendingInvite,
              onPrimary: _sendingInvite || p.nickname.isEmpty
                  ? null
                  : _inviteToTalk,
              secondaryLabel: _inviteGroup != null ? 'В команду' : null,
              onSecondary: _inviteGroup != null ? _inviteToTeam : null,
              onMore: _showMoreActions,
            ),
    );
  }
}
