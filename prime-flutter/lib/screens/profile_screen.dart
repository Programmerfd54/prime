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
import '../ui/components/app_skeleton.dart';
import '../ui/components/prime_text_field.dart';
import '../ui/kit/presentation/profile_editorial_widgets.dart';
import '../ui/kit/presentation/profile_page_layout.dart';
import '../ui/kit/presentation/profile_sections.dart';
import '../ui/kit/presentation/profile_view_model.dart';
import '../ui/kit/tokens/kit_layout.dart';
import '../widgets/async_error_view.dart';
import 'account_settings_screen.dart';
import 'avatar_screen.dart';
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
  bool _loading = true;
  String? _error;
  String? _errorCorrelationId;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _errorCorrelationId = null;
      });
    }
    final api = context.read<ApiClient>();
    try {
      final list = await api.listAchievements();
      _achievements = list
          .map((j) => AchievementModel.fromJson(j as Map<String, dynamic>))
          .toList()
        ..sort((a, b) {
          final aDone = a.unlocked ? 0 : 1;
          final bDone = b.unlocked ? 0 : 1;
          if (aDone != bDone) return aDone.compareTo(bDone);
          return a.requiredDays.compareTo(b.requiredDays);
        });
      try {
        final calendar = CalendarOut.fromJson(await api.calendarAll());
        _calendar = calendar;
        _currentStreak = calendar.currentStreak;
        _bestStreak = calendar.bestStreak;
        _cyclePacePercent = calendar.cyclePacePercent;
        _insights = calendar.insights;
      } catch (_) {
        _calendar = null;
        _currentStreak = 0;
        _bestStreak = 0;
        _cyclePacePercent = null;
        _insights = const [];
      }
      try {
        final userId = context.read<AuthProvider>().user?.id;
        final rows = await api.listGroups();
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
        if (skillNames.isEmpty && _calendar != null) {
          final bySkill = completionBySkill(_calendar!);
          final top = bySkill.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          skillNames.addAll(top.take(3).map((e) => e.key));
        }
        _habitTags = profileHabitTagsFromNames(skillNames);
      } catch (_) {
        _habitTags = const [];
        _activeGroup = null;
      }
    } catch (e) {
      if (mounted) {
        final failure = FailureMapper.from(e);
        _error = failure.message;
        _errorCorrelationId = failure.correlationId;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _openAvatar() {
    Navigator.of(context).push(
      PrimeRoute.sharedAxis(builder: (_) => const AvatarScreen()),
    );
  }

  Future<void> _editProfile() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;
    final nameCtrl = TextEditingController(text: user.name);
    final aboutCtrl = TextEditingController(text: user.about);
    final ageCtrl = TextEditingController(text: user.age?.toString() ?? '');
    List<Map<String, dynamic>> regions = [];
    String? regionCode = user.regionCode;
    try {
      regions = await context.read<ApiClient>().listRegions();
    } catch (_) {}
    if (!mounted) return;
    var saving = false;
    String? error;
    final saved = await showAppBottomSheet<bool>(
      context: context,
      child: StatefulBuilder(
        builder: (sheetContext, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.lg,
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom +
                  AppSpacing.lg,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Редактировать профиль',
                    style: AppTypography.title1,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimeTextField(
                    controller: nameCtrl,
                    label: 'Имя',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextarea(
                    controller: aboutCtrl,
                    label: 'О себе',
                    minLines: 3,
                    maxLines: 6,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PrimeTextField(
                    controller: ageCtrl,
                    label: 'Возраст',
                    icon: Icons.cake_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (regions.isNotEmpty)
                    AppDropdownField<String>(
                      value: regions.any((r) => r['code'] == regionCode)
                          ? regionCode
                          : null,
                      label: 'Область',
                      items: [
                        for (final region in regions)
                          DropdownMenuItem(
                            value: region['code'] as String?,
                            child: Text(region['name'] as String? ?? ''),
                          ),
                      ],
                      onChanged: (value) =>
                          setModalState(() => regionCode = value),
                    ),
                  if (error != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      error!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  AppPrimaryButton(
                    label: AppCopy.save,
                    loading: saving,
                    onPressed: saving
                        ? null
                        : () async {
                            setModalState(() {
                              saving = true;
                              error = null;
                            });
                            try {
                              final selected = regions
                                  .cast<Map<String, dynamic>?>()
                                  .firstWhere(
                                    (item) => item?['code'] == regionCode,
                                    orElse: () => null,
                                  );
                              await auth.api.updateMe({
                                'name': nameCtrl.text.trim(),
                                'about': aboutCtrl.text.trim(),
                                'age': int.tryParse(ageCtrl.text.trim()),
                                'region_code': regionCode,
                                if (selected != null) 'city': selected['name'],
                              });
                              await auth.refreshUser();
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop(true);
                              }
                            } catch (e) {
                              setModalState(() {
                                saving = false;
                                error = FailureMapper.from(e).message;
                              });
                            }
                          },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    nameCtrl.dispose();
    aboutCtrl.dispose();
    ageCtrl.dispose();
    if (saved == true && mounted) {
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
        label: 'Циклы',
        value: cycleDay > 0 ? '$cycleDay/30' : 'Нет цикла',
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
    if (_loading) return const AppProfileSkeleton();
    if (_error != null) {
      return AsyncErrorView(
        message: _error!,
        correlationId: _errorCorrelationId,
        onRetry: _load,
      );
    }

    final photoUrl = absolutePhotoUrl(user?.photoUrl);
    final displayName = user?.name.isNotEmpty == true
        ? user!.name
        : (user?.nickname.isNotEmpty == true ? '@${user!.nickname}' : '');
    final cycleDay = (user?.successfulDays ?? 0) % 30;
    final subtitle = [
      if (user?.nickname.isNotEmpty == true) '@${user!.nickname}',
      if (user?.regionName?.isNotEmpty == true) user!.regionName,
      if (user?.age != null) '${user!.age} лет',
    ].join(' · ');
    final consistency7 = _calendar == null
        ? 0
        : _consistencyPercent(_calendar!, window: 7);
    final statusLine = _habitTags.isNotEmpty
        ? _habitTags.first.label
        : (cycleDay > 0 ? 'День $cycleDay/30' : null);
    final aboutRows = user == null
        ? const <ProfileAboutRow>[]
        : ownProfileAboutRows(
            user: user,
            habitNames: _habitTags.map((t) => t.label),
          );
    final memberPhotos = _memberPhotoUrls(_activeGroup);
    final reportedToday = _reportedToday(_calendar);

    final hero = ProfileHeroCard(
      displayName: displayName.isEmpty ? 'Профиль' : displayName,
      subtitle: subtitle.isEmpty ? null : subtitle,
      statusLine: statusLine,
      photoUrl: photoUrl,
      about: user?.about,
      tags: _habitTags,
      metrics: _ownMetrics(
        streak: _currentStreak,
        primes: user?.primePoints ?? 0,
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
          ProfileAboutSection(rows: aboutRows),
          if (aboutRows.isNotEmpty) const SizedBox(height: AppSpacing.lg),
          ProfileCurrentCycleSection(
            successfulDays: user?.successfulDays ?? 0,
            currentStreak: _currentStreak,
            primePoints: user?.primePoints ?? 0,
            bestStreak: _bestStreak,
            cyclePacePercent: _cyclePacePercent,
            calendar: _calendar,
            streakShields: user?.streakShields ?? 0,
            shieldPending: user?.shieldPending ?? false,
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
          const SizedBox(height: AppSpacing.lg),
          ProfileAnalyticsSection(
            calendar: _calendar,
            insights: _insights,
            onInsightOpened: (insight) =>
                Analytics.instance.insightOpened(insight.id),
            onCheckIn: widget.onOpenGroups,
          ),
          const SizedBox(height: AppSpacing.lg),
          ProfileLinkTile(
            icon: Icons.emoji_events_outlined,
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
            icon: Icons.history,
            title: 'История Праймов',
            onTap: () {
              Navigator.of(context).push(
                PrimeRoute.sharedAxis(
                  builder: (_) => const PrimeHistoryScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          ProfileAchievementsSection(
            achievements: _achievements,
            successfulDays: user?.successfulDays ?? 0,
          ),
        ],
      ),
    );

    return AmbientCanvas(
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
              padding: const EdgeInsets.only(bottom: KitLayout.navBottomClearance),
              sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
          ],
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
