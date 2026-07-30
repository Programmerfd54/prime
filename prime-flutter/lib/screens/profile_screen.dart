import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/analytics/analytics.dart';
import '../core/errors/failure_mapper.dart';
import '../data/api_client.dart';
import '../core/media/media_urls.dart';
import '../core/metrics/analytics_metrics.dart';
import '../design/routes.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../l10n/copy.dart';
import '../models/achievement.dart';
import '../models/group.dart';
import '../models/report.dart';
import '../providers/auth_provider.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../ui/components/app_dialog.dart';
import '../ui/components/app_dropdown_field.dart';
import '../ui/components/app_primary_button.dart';
import '../ui/components/app_snackbar.dart';
import '../ui/components/app_textarea.dart';
import '../ui/components/prime_text_field.dart';
import '../ui/kit/presentation/profile_about_card.dart';
import '../ui/kit/presentation/profile_editorial_widgets.dart';
import '../ui/kit/presentation/profile_icons.dart';
import '../ui/kit/presentation/profile_page_layout.dart';
import '../ui/kit/presentation/profile_sections.dart';
import '../ui/kit/presentation/profile_states.dart';
import '../ui/kit/presentation/profile_surfaces.dart';
import '../ui/kit/presentation/profile_tabs.dart';
import '../ui/kit/presentation/profile_view_model.dart';
import '../ui/kit/tokens/kit_layout.dart';
import 'account_settings_screen.dart';
import 'avatar_screen.dart';
import 'edit_profile_screen.dart';
import 'prime_history_screen.dart';
import 'tournaments_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onOpenGroups});

  final VoidCallback? onOpenGroups;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<AchievementModel> _achievements = [];
  int _currentStreak = 0;
  int _bestStreak = 0;
  int? _cyclePacePercent;
  List<ProfileInsightModel> _insights = const [];
  CalendarOut? _calendar;
  List<ProfileHabitTag> _habitTags = const [];
  GroupModel? _activeGroup;
  Map<String, dynamic> _preferences = const {};
  bool _loadingCalendar = true;
  bool _loadingAchievements = false;
  bool _achievementsLoaded = false;
  bool _offlineCached = false;
  double _scrollOffset = 0;
  OwnProfileTab _tab = OwnProfileTab.overview;

  final _cycleKey = GlobalKey();
  final _analyticsKey = GlobalKey();
  final _achievementsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadSecondary();
  }

  Future<void> _loadAchievements() async {
    if (_achievementsLoaded || _loadingAchievements) return;
    setState(() => _loadingAchievements = true);
    try {
      final list = await context.read<ApiClient>().listAchievements();
      _achievements = list
          .map((j) => AchievementModel.fromJson(j as Map<String, dynamic>))
          .toList()
        ..sort((a, b) {
          final aDone = a.unlocked ? 0 : 1;
          final bDone = b.unlocked ? 0 : 1;
          if (aDone != bDone) return aDone.compareTo(bDone);
          return a.requiredDays.compareTo(b.requiredDays);
        });
      _achievementsLoaded = true;
    } catch (_) {
      _achievements = const [];
    } finally {
      if (mounted) setState(() => _loadingAchievements = false);
    }
  }

  Future<void> _loadSecondary() async {
    if (mounted) {
      setState(() {
        _loadingCalendar = true;
        _offlineCached = false;
      });
    }
    final api = context.read<ApiClient>();
    final userId = context.read<AuthProvider>().user?.id;

    try {
      final calendarFuture = api.calendarAll().then((raw) {
        final calendar = CalendarOut.fromJson(raw);
        _calendar = calendar;
        _currentStreak = calendar.currentStreak;
        _bestStreak = calendar.bestStreak;
        _cyclePacePercent = calendar.cyclePacePercent;
        _insights = calendar.insights;
      }).catchError((_) {
        _calendar = null;
        _currentStreak = 0;
        _bestStreak = 0;
        _cyclePacePercent = null;
        _insights = const [];
        _offlineCached = true;
      });

      final groupsFuture = api.listGroups().then((rows) {
        final groups = rows
            .map((g) => GroupModel.fromJson(g as Map<String, dynamic>))
            .toList();
        final skillNames = <String>{};
        GroupModel? activeGroup;
        for (final group in groups) {
          if (userId == null) continue;
          final isMember =
              group.members.any((m) => m.profile?.id == userId);
          if (isMember) {
            if (group.skillName?.isNotEmpty == true) {
              skillNames.add(group.skillName!);
            }
            if (group.status == GroupStatus.active) {
              activeGroup ??= group;
            }
          }
        }
        _activeGroup = activeGroup;
        return skillNames;
      }).catchError((_) {
        _activeGroup = null;
        return <String>{};
      });

      final prefsFuture = api.getPreferences().then((prefs) {
        _preferences = prefs;
      }).catchError((_) {
        _preferences = const {};
      });

      final results =
          await Future.wait([calendarFuture, groupsFuture, prefsFuture]);
      final skillNames = results[1] as Set<String>;
      if (skillNames.isEmpty && _calendar != null) {
        final bySkill = completionBySkill(_calendar!);
        final top = bySkill.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        _habitTags = profileHabitTagsFromNames(top.take(3).map((e) => e.key));
      } else {
        _habitTags = profileHabitTagsFromNames(skillNames);
      }
    } finally {
      if (mounted) setState(() => _loadingCalendar = false);
    }
  }

  Future<void> _load() async {
    await _loadSecondary();
    if (_tab == OwnProfileTab.achievements) {
      await _loadAchievements();
    }
  }

  void _openAvatar() {
    Navigator.of(context).push(
      PrimeRoute.sharedAxis(builder: (_) => const AvatarScreen()),
    );
  }

  Future<void> _editProfile() async {
    final saved = await Navigator.of(context).push<bool>(
      PrimeRoute.sharedAxis(builder: (_) => const EditProfileScreen()),
    );
    if (saved == true && mounted) {
      try {
        _preferences = await context.read<ApiClient>().getPreferences();
      } catch (_) {}
      setState(() {});
      showAppSnackBar(context, 'Профиль обновлён');
    }
  }

  bool _reportedToday(CalendarOut? calendar) {
    if (calendar == null) return false;
    final today = DateTime(
      calendar.today.year,
      calendar.today.month,
      calendar.today.day,
    );
    for (final day in calendar.days) {
      final d = DateTime(day.date.year, day.date.month, day.date.day);
      if (d == today) return day.reported;
    }
    return false;
  }

  List<String> _memberPhotoUrls(GroupModel? group) {
    if (group == null) return const [];
    return group.members
        .map((m) => m.profile?.photoUrl)
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .take(6)
        .toList();
  }

  List<ProfileMetricPill> _ownMetrics({
    required int streak,
    required int primes,
    required int cycleDay,
    required int consistency7,
  }) {
    return [
      ProfileMetricPill(
        label: 'Дней подряд',
        value: '$streak дн.',
        variant: ProfileMetricPillVariant.gold,
      ),
      ProfileMetricPill(
        label: 'Праймы',
        value: '$primes',
        variant: ProfileMetricPillVariant.charcoal,
      ),
      ProfileMetricPill(
        label: AppCopy.profileProgressLabel,
        value: cycleDay > 0 ? '$cycleDay/30' : AppCopy.profileProgressEmpty,
        variant: ProfileMetricPillVariant.hatched,
      ),
      ProfileMetricPill(
        label: 'Стаб. 7д',
        value: '$consistency7%',
        variant: ProfileMetricPillVariant.glass,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const ProfileLoadingState();

    final photoUrl = absolutePhotoUrl(user.photoUrl);
    final displayName = user.name.isNotEmpty
        ? user.name
        : (user.nickname.isNotEmpty ? '@${user.nickname}' : '');
    final cycleDay = user.successfulDays % 30;
    final subtitle = [
      if (user.nickname.isNotEmpty) '@${user.nickname}',
      if (user.regionName?.isNotEmpty == true) user.regionName,
      if (user.age != null) '${user.age} лет',
    ].join(' · ');
    final consistency7 = _calendar == null
        ? 0
        : _consistencyPercent(_calendar!, window: 7);
    final statusLine = _habitTags.isNotEmpty
        ? _habitTags.first.label
        : (cycleDay > 0 ? 'День $cycleDay/30' : null);
    final aboutData = buildOwnAboutData(
      user: user,
      habitNames: _habitTags.map((t) => t.label),
      activeGroup: _activeGroup,
      cycleDay: cycleDay,
      preferences: _preferences,
    );
    final memberPhotos = _memberPhotoUrls(_activeGroup);
    final reportedToday = _reportedToday(_calendar);

    final hero = ProfileHeroCard(
      displayName: displayName.isEmpty ? 'Профиль' : displayName,
      subtitle: subtitle.isEmpty ? null : subtitle,
      statusLine: statusLine,
      photoUrl: photoUrl,
      about: user.about,
      tags: _habitTags,
      showVerifiedBadge: user.emailVerified,
      metrics: _ownMetrics(
        streak: _currentStreak,
        primes: user.primePoints,
        cycleDay: cycleDay,
        consistency7: consistency7,
      ),
      calendar: _calendar,
      scrollOffset: _scrollOffset,
      onSettings: () {
        Navigator.of(context).push(
          PrimeRoute.sharedAxis(
            builder: (_) => const AccountSettingsScreen(),
          ),
        );
      },
      onEdit: _editProfile,
      onAvatarTap: _openAvatar,
    );

    final tabLabels = const ['Обзор', 'Прогресс', 'Привычки', 'Достижения'];

    Widget tabBody() {
      switch (_tab) {
        case OwnProfileTab.overview:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileAboutCard(
                data: aboutData,
                onEdit: _editProfile,
                onFillProfile: _editProfile,
              ),
              const SizedBox(height: AppSpacing.lg),
              ProfileLinkTile(
                icon: ProfileIcons.trophy,
                title: 'Турниры',
                onTap: () {
                  Navigator.of(context).push(
                    PrimeRoute.sharedAxis(
                      builder: (_) => TournamentsScreen(
                        onShowMessage: () =>
                            showAppSnackBar(context, 'Турниры скоро'),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              ProfileLinkTile(
                icon: ProfileIcons.history,
                title: 'История Праймов',
                onTap: () {
                  Navigator.of(context).push(
                    PrimeRoute.sharedAxis(
                      builder: (_) => const PrimeHistoryScreen(),
                    ),
                  );
                },
              ),
            ],
          );
        case OwnProfileTab.progress:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyedSubtree(
                key: _cycleKey,
                child: ProfileCurrentCycleSection(
                  successfulDays: user.successfulDays,
                  currentStreak: _currentStreak,
                  primePoints: user.primePoints,
                  bestStreak: _bestStreak,
                  cyclePacePercent: _cyclePacePercent,
                  calendar: _calendar,
                  streakShields: user.streakShields,
                  shieldPending: user.shieldPending,
                  habitName: _activeGroup?.skillName ?? _activeGroup?.name,
                  memberPhotoUrls: memberPhotos,
                  reportedToday: reportedToday,
                  onChooseHabit: widget.onOpenGroups,
                  onCheckIn: widget.onOpenGroups,
                  onBuyShield: () async {
                    try {
                      await context.read<ApiClient>().buyStreakShield();
                      await context.read<AuthProvider>().refreshUser();
                      if (mounted) showAppSnackBar(context, 'Щит куплен');
                    } catch (e) {
                      if (mounted) {
                        showAppSnackBar(context, ApiClient.errorMessage(e));
                      }
                    }
                  },
                  onUseShield: () async {
                    try {
                      await context.read<ApiClient>().useStreakShield();
                      await context.read<AuthProvider>().refreshUser();
                      if (mounted) showAppSnackBar(context, 'Щит активирован');
                    } catch (e) {
                      if (mounted) {
                        showAppSnackBar(context, ApiClient.errorMessage(e));
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              KeyedSubtree(
                key: _analyticsKey,
                child: ProfileAnalyticsSection(
                  calendar: _calendar,
                  insights: _insights,
                  onInsightOpened: (insight) =>
                      Analytics.instance.insightOpened(insight.id),
                ),
              ),
            ],
          );
        case OwnProfileTab.habits:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_habitTags.isEmpty)
                ProfileAboutCard(
                  data: aboutData.copyWith(
                    currentFocus: 'Выберите первую привычку',
                    teamStatus: 'Ищу команду',
                  ),
                  onFillProfile: widget.onOpenGroups,
                )
              else ...[
                ProfileHabitTagsRow(tags: _habitTags),
                const SizedBox(height: AppSpacing.md),
                ProfileAboutCard(data: aboutData, onEdit: _editProfile),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppPrimaryButton(
                label: _habitTags.isEmpty
                    ? 'Выбрать привычку'
                    : 'Управление привычками',
                onPressed: widget.onOpenGroups,
              ),
            ],
          );
        case OwnProfileTab.achievements:
          if (_loadingAchievements && !_achievementsLoaded) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return KeyedSubtree(
            key: _achievementsKey,
            child: ProfileAchievementsSection(
              achievements: _achievements,
              successfulDays: user.successfulDays,
            ),
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
          if (_offlineCached) ...[
            ProfileOfflineBanner(onRetry: _load),
            const SizedBox(height: AppSpacing.md),
          ],
          ProfileTabBar(
            tabs: tabLabels,
            selectedIndex: _tab.index,
            onSelected: (i) {
              final tab = OwnProfileTab.values[i];
              setState(() => _tab = tab);
              if (tab == OwnProfileTab.achievements) {
                unawaited(_loadAchievements());
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          tabBody(),
        ],
      ),
    );

    final rail = [
      ProfileRailDestination(
        icon: ProfileIcons.cycle,
        label: 'Цикл',
        key: _cycleKey,
      ),
      ProfileRailDestination(
        icon: ProfileIcons.analytics,
        label: 'Аналитика',
        key: _analyticsKey,
      ),
      ProfileRailDestination(
        icon: ProfileIcons.achievements,
        label: 'Достижения',
        key: _achievementsKey,
      ),
    ];

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
                railDestinations: rail,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(bottom: KitLayout.dockScrollTail(context)),
              sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
          ],
        ),
      ),
      ),
    );
  }

  int _consistencyPercent(CalendarOut calendar, {required int window}) {
    final recent = calendar.days.length <= window
        ? calendar.days
        : calendar.days.sublist(calendar.days.length - window);
    if (recent.isEmpty) return 0;
    final met = recent.where((day) => day.reported).length;
    return ((met / recent.length) * 100).round();
  }
}
