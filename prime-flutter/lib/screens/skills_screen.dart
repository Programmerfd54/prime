import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/analytics/analytics.dart';
import '../core/sync/user_personalization_sync.dart';
import '../core/habits/habit_favorites.dart';
import '../core/habits/habit_program_metadata.dart';
import '../core/onboarding/onboarding_preferences.dart';
import '../core/errors/failure_mapper.dart';
import '../core/sync/waiting_room_poller.dart';
import '../data/api_client.dart';
import '../design/lottie_registry.dart';
import '../design/routes.dart';
import '../design/theme/prime_theme_context.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../l10n/copy.dart';
import '../models/skill.dart';
import '../providers/auth_provider.dart';
import '../design/visuals/habit_tags.dart';
import '../design/visuals/habit_art.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../ui/kit/presentation/profile_surfaces.dart';
import '../design/visuals/charts/charts.dart';
import '../ui/components/app_chip.dart';
import '../ui/components/app_dialog.dart';
import '../ui/components/app_primary_button.dart';
import '../ui/components/app_skeleton.dart';
import '../ui/components/editorial/app_habit_catalog.dart';
import '../ui/components/editorial/app_habit_detail_v2.dart';
import '../ui/components/profile/about_before_team_sheet.dart';
import '../ui/kit/prime_kit.dart';
import '../widgets/async_error_view.dart';

class SkillsScreen extends StatefulWidget {
  final ValueChanged<SkillModel>? onSearchStarted;

  const SkillsScreen({
    super.key,
    this.onSearchStarted,
  });

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  List<SkillModel> _skills = [];
  bool _loading = true;
  String? _error;
  String? _errorCorrelationId;
  HabitFilterTag _filter = HabitFilterTag.all;
  HabitTimeOfDayFilter _timeFilter = HabitTimeOfDayFilter.any;
  HabitMood _mood = HabitMood.focused;
  OnboardingPreferences _onboardingPrefs = const OnboardingPreferences();
  Set<String> _favorites = {};

  @override
  void initState() {
    super.initState();
    Analytics.instance.habitListViewed();
    _load();
    _loadPersonalization();
  }

  Future<void> _loadPersonalization() async {
    final prefs = await OnboardingPreferences.load();
    final favorites = await HabitFavorites.load();
    if (mounted) {
      setState(() {
        _onboardingPrefs = prefs;
        _favorites = favorites;
      });
      final recId = prefs.recommendedSkillId;
      if (recId != null) {
        Analytics.instance.habitRecommendationViewed(recId);
      }
    }
  }

  Future<void> _toggleFavorite(String skillId) async {
    final added = await HabitFavorites.toggle(skillId);
    if (added) Analytics.instance.habitSaved(skillId);
    if (context.read<AuthProvider>().isAuthenticated) {
      await UserPersonalizationSync.pushFavoriteToggle(
        context.read<ApiClient>(),
        skillId,
        added,
      );
    }
    if (mounted) {
      setState(() {
        if (added) {
          _favorites.add(skillId);
        } else {
          _favorites.remove(skillId);
        }
      });
    }
  }

  Future<void> _showCreateCustomHabit() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final created = await showAppBottomSheet<bool>(
      context: context,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Своя привычка', style: AppTypography.title1),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Описание'),
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            AppPrimaryButton(
              label: 'Создать',
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.length < 2) return;
                try {
                  await context.read<ApiClient>().createCustomSkill(
                        name: name,
                        description: descCtrl.text.trim(),
                      );
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ApiClient.errorMessage(e))),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    descCtrl.dispose();
    if (created == true && mounted) {
      await _load();
    }
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
      final list = await api.listSkills();
      _skills = list
          .map((json) => SkillModel.fromJson(json as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.popularity.compareTo(b.popularity));
    } catch (e) {
      if (mounted) {
        final failure = FailureMapper.from(e);
        _error = failure.message;
        _errorCorrelationId = failure.correlationId;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  int _moodRank(SkillModel skill) {
    final kind = habitArtKindFor('${skill.id} ${skill.name} ${skill.icon}');
    return switch (_mood) {
      HabitMood.energetic => switch (kind) {
          HabitArtKind.charge || HabitArtKind.social => 0,
          HabitArtKind.focus => 1,
          _ => 2,
        },
      HabitMood.calm => switch (kind) {
          HabitArtKind.sleep || HabitArtKind.detox => 0,
          HabitArtKind.read => 1,
          _ => 2,
        },
      HabitMood.focused => switch (kind) {
          HabitArtKind.focus || HabitArtKind.read => 0,
          HabitArtKind.detox => 1,
          _ => 2,
        },
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _skills.isEmpty) return const AppSkeletonList();
    if (_error != null) {
      return AsyncErrorView(
        message: _error!,
        correlationId: _errorCorrelationId,
        onRetry: _load,
      );
    }

    final official = _skills
        .where((skill) => skill.category == SkillCategory.official)
        .where((skill) => skillMatchesFilter(skill, _filter))
        .where((skill) => skillMatchesTimeOfDay(skill, _timeFilter))
        .toList()
      ..sort((a, b) => _moodRank(a).compareTo(_moodRank(b)));
    final custom = _skills
        .where((skill) => skill.category == SkillCategory.custom)
        .toList();
    final user = context.watch<AuthProvider>().user;
    final recommendedId = _onboardingPrefs.recommendedSkillId;
    SkillModel? recommended;
    if (recommendedId != null) {
      for (final skill in _skills) {
        if (skill.id == recommendedId) {
          recommended = skill;
          break;
        }
      }
    }
    // Mood temporarily boosts matching recommendation to the top.
    if (recommended == null && official.isNotEmpty) {
      recommended = official.first;
    }
    final catalogSkills = recommended == null
        ? official
        : official.where((s) => s.id != recommended!.id).toList();
    final savedSkills = _skills
        .where((s) => _favorites.contains(s.id))
        .where((skill) => skillMatchesFilter(skill, _filter))
        .where((skill) => skillMatchesTimeOfDay(skill, _timeFilter))
        .toList();

    final p = context.prime;

    return AmbientCanvas(
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: KitLayout.tabScrollPadding(
                context,
                left: AppSpacing.md,
                top: AppSpacing.md,
                right: AppSpacing.md,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  PrimeTabContentFrame(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                  Text(
                    AppCopy.habits,
                    style: KitTypography.pageTitle.copyWith(color: p.ink),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Выберите программу — у каждой свой ритм и визуальный характер',
                    style: KitTypography.bodySecondary.copyWith(color: p.inkSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _HowItWorksCard(),
                  const SizedBox(height: AppSpacing.md),
                  PrimeMoodSwitcher(
                    value: _mood,
                    onChanged: (m) => setState(() => _mood = m),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (recommended case final SkillModel featured) ...[
                    const _SectionTitle('Рекомендуем'),
                    const SizedBox(height: AppSpacing.sm),
                    _FeaturedHabitCard(
                      skill: featured,
                      isFavorite: _favorites.contains(featured.id),
                      onFavoriteToggle: () => _toggleFavorite(featured.id),
                      onTap: () => Navigator.of(context).push(
                        PrimeRoute.sharedAxis(
                          builder: (_) => SkillDetailScreen(
                            skill: featured,
                            allSkills: _skills
                                .where(
                                  (s) => s.category == SkillCategory.official,
                                )
                                .toList(),
                            onSearchStarted: widget.onSearchStarted,
                            isFavorite: _favorites.contains(featured.id),
                            onFavoriteToggle: () =>
                                _toggleFavorite(featured.id),
                          ),
                        ),
                      ),
                    ),
                    if (_onboardingPrefs.recommendationReason(null) !=
                        null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        _onboardingPrefs.recommendationReason(null)!,
                        style: AppTypography.caption.copyWith(
                          color: p.brandSoft,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (savedSkills.isNotEmpty) ...[
                    const _SectionTitle('Избранное'),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 180,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: savedSkills.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final skill = savedSkills[index];
                          return AppHabitCompactTile(
                            skill: skill,
                            onTap: () => Navigator.of(context).push(
                              PrimeRoute.sharedAxis(
                                builder: (_) => SkillDetailScreen(
                                  skill: skill,
                                  allSkills: _skills
                                      .where(
                                        (s) =>
                                            s.category == SkillCategory.official,
                                      )
                                      .toList(),
                                  onSearchStarted: widget.onSearchStarted,
                                  isFavorite: _favorites.contains(skill.id),
                                  onFavoriteToggle: () =>
                                      _toggleFavorite(skill.id),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  PrimeContentCard(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: HabitTimeOfDayFilter.values.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: AppSpacing.xs),
                            itemBuilder: (context, index) {
                              final tag = HabitTimeOfDayFilter.values[index];
                              final selected = _timeFilter == tag;
                              return AppChip(
                                label: tag.label,
                                selected: selected,
                                onTap: () => setState(() => _timeFilter = tag),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: HabitFilterTag.values.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: AppSpacing.xs),
                            itemBuilder: (context, index) {
                              final tag = HabitFilterTag.values[index];
                              final selected = _filter == tag;
                              return AppChip(
                                label: tag.label,
                                selected: selected,
                                onTap: () => setState(() => _filter = tag),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionTitle('Каталог'),
                  const SizedBox(height: AppSpacing.sm),
                  _SkillCatalog(
                    skills: catalogSkills,
                    comparePool: _skills
                        .where((s) => s.category == SkillCategory.official)
                        .toList(),
                    onSearchStarted: widget.onSearchStarted,
                    favorites: _favorites,
                    onFavoriteToggle: _toggleFavorite,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppCustomHabitUnlockCard(
                    primePoints: user?.primePoints ?? 0,
                    unlocked: user?.canCreateCustomSkills ?? false,
                    onCreate: (user?.canCreateCustomSkills ?? false)
                        ? _showCreateCustomHabit
                        : null,
                  ),
                  if (custom.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionTitle('Пользовательские привычки'),
                    const SizedBox(height: AppSpacing.sm),
                    _SkillCatalog(
                      skills: custom,
                      onSearchStarted: widget.onSearchStarted,
                      favorites: _favorites,
                      onFavoriteToggle: _toggleFavorite,
                    ),
                  ],
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillCatalog extends StatelessWidget {
  final List<SkillModel> skills;
  final List<SkillModel> comparePool;
  final ValueChanged<SkillModel>? onSearchStarted;
  final Set<String> favorites;
  final ValueChanged<String>? onFavoriteToggle;

  const _SkillCatalog({
    required this.skills,
    this.comparePool = const [],
    this.onSearchStarted,
    this.favorites = const {},
    this.onFavoriteToggle,
  });

  static const _gridRatios = [4 / 5, 1 / 1, 3 / 4];

  void _open(BuildContext context, SkillModel skill) {
    Navigator.of(context).push(
      PrimeRoute.sharedAxis(
        builder: (_) => SkillDetailScreen(
          skill: skill,
          allSkills: comparePool.isNotEmpty ? comparePool : skills,
          onSearchStarted: onSearchStarted,
          isFavorite: favorites.contains(skill.id),
          onFavoriteToggle: onFavoriteToggle == null
              ? null
              : () => onFavoriteToggle!(skill.id),
        ),
      ),
    );
  }

  double _ratioFor(int gridIndex) => _gridRatios[gridIndex % _gridRatios.length];

  Widget _habitCard(
    BuildContext context,
    SkillModel skill, {
    required double aspectRatio,
  }) {
    final meta = HabitProgramCatalog.metaFor(skill);
    final photo = habitPhotoAssetFor('${skill.id} ${skill.name}');
    final kind = habitArtKindFor('${skill.id} ${skill.name} ${skill.icon}');
    final description = skill.description.trim();
    final subtitle =
        description.isEmpty ? habitPromise(kind) : description;

    return PrimeImageCard(
      image: AssetImage(photo),
      title: skill.name,
      subtitle: subtitle,
      aspectRatio: aspectRatio,
      onTap: () => _open(context, skill),
      metadata: [
        _PhotoMetaChip(label: meta.timeOfDay),
        _PhotoMetaChip(label: meta.difficulty),
        _PhotoMetaChip(label: '6 чел.'),
      ],
      trailing: onFavoriteToggle == null
          ? null
          : IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Icon(
                favorites.contains(skill.id)
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => onFavoriteToggle!(skill.id),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (skills.isEmpty) {
      return PrimeContentCard(
        child: Text(
          'Нет программ в этой категории',
          textAlign: TextAlign.center,
          style: KitTypography.bodySecondary.copyWith(
            color: context.prime.inkSecondary,
          ),
        ),
      );
    }

    final children = <Widget>[
      _habitCard(context, skills.first, aspectRatio: 16 / 10),
    ];

    if (skills.length > 1) {
      children.add(const SizedBox(height: AppSpacing.sm));
      for (var i = 1; i < skills.length; i += 2) {
        if (i > 1) {
          children.add(const SizedBox(height: AppSpacing.sm));
        }
        children.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _habitCard(
                  context,
                  skills[i],
                  aspectRatio: _ratioFor(i - 1),
                ),
              ),
              if (i + 1 < skills.length) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _habitCard(
                    context,
                    skills[i + 1],
                    aspectRatio: _ratioFor(i),
                  ),
                ),
              ] else
                const Expanded(child: SizedBox.shrink()),
            ],
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _FeaturedHabitCard extends StatelessWidget {
  const _FeaturedHabitCard({
    required this.skill,
    required this.onTap,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  final SkillModel skill;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final meta = HabitProgramCatalog.metaFor(skill);
    final photo = habitPhotoAssetFor('${skill.id} ${skill.name}');
    final kind = habitArtKindFor('${skill.id} ${skill.name} ${skill.icon}');
    final description = skill.description.trim();
    final subtitle =
        description.isEmpty ? habitPromise(kind) : description;

    return PrimeImageCard(
      image: AssetImage(photo),
      title: skill.name,
      subtitle: subtitle,
      aspectRatio: 16 / 10,
      onTap: onTap,
      metadata: [
        _PhotoMetaChip(label: meta.durationLabel),
        _PhotoMetaChip(label: meta.difficulty),
        _PhotoMetaChip(label: '6 чел.'),
      ],
      trailing: IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        icon: Icon(
          isFavorite ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
          color: Colors.white,
          size: 20,
        ),
        onPressed: onFavoriteToggle,
      ),
    );
  }
}

class _PhotoMetaChip extends StatelessWidget {
  const _PhotoMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: KitTypography.caption.copyWith(
          color: Colors.white,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: KitTypography.sectionTitle.copyWith(color: context.prime.ink),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  static const _steps = [
    (Icons.menu_book_outlined, 'Выберите привычку'),
    (Icons.groups_outlined, 'Соберите команду из 6'),
    (Icons.done_all_rounded, AppCopy.dayClosesTogether),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return PrimeContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Как это работает',
            style: KitTypography.sectionTitle.copyWith(fontSize: 16, color: p.ink),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Center(
            child: PrimeLottie(
              slot: PrimeLottieSlot.studyDiscussion,
              width: 132,
              height: 100,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (var i = 0; i < _steps.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: p.inkMuted,
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      Icon(
                        _steps[i].$1,
                        size: 22,
                        color: p.brandSoft,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        _steps[i].$2,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppCopy.primesForTeamDay,
            style: AppTypography.caption.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class SkillDetailScreen extends StatefulWidget {
  final SkillModel skill;
  final List<SkillModel> allSkills;
  final ValueChanged<SkillModel>? onSearchStarted;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const SkillDetailScreen({
    super.key,
    required this.skill,
    this.allSkills = const [],
    this.onSearchStarted,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  State<SkillDetailScreen> createState() => _SkillDetailScreenState();
}

class _SkillDetailScreenState extends State<SkillDetailScreen> {
  late bool _favorite;

  @override
  void initState() {
    super.initState();
    _favorite = widget.isFavorite;
    Analytics.instance.habitDetailsViewed(widget.skill.id);
  }

  Future<void> _joinGroup() async {
    final aboutOk = await ensureAboutBeforeTeam(
      context,
      reason: AboutBeforeTeamReason.search,
    );
    if (!aboutOk || !mounted) return;

    Analytics.instance.searchStarted(widget.skill.id);
    final api = context.read<ApiClient>();
    final poller = context.read<WaitingRoomPoller>();
    final skill = widget.skill;

    widget.onSearchStarted?.call(skill);
    if (mounted) Navigator.of(context).pop();

    try {
      final result = await api.joinWaitingRoom(skill.id);
      poller.start();
      if (result['matched_group_id'] != null) {
        await poller.refresh();
      }
    } catch (_) {
      // Groups tab shows queue state via poller; errors surface on refresh.
    }
  }

  @override
  Widget build(BuildContext context) {
    final description = widget.skill.description.trim();
    final kind = habitArtKindFor('${widget.skill.id} ${widget.skill.name}');
    final promise = description.isNotEmpty ? description : habitPromise(kind);
    final meta = HabitProgramCatalog.metaFor(widget.skill);
    final photo = habitPhotoAssetFor('${widget.skill.id} ${widget.skill.name}');
    final bottomBarHeight = PrimeContextualActionBar.heightFor(context);

    return Scaffold(
      backgroundColor: ProfileSurfaces.canvas,
      bottomNavigationBar: PrimeContextualActionBar(
        hint: 'Команда из 6 · первый сезон 30 дней',
        primaryLabel: AppCopy.findTeam,
        primaryIcon: Icons.groups_outlined,
        onPrimary: _joinGroup,
      ),
      body: AmbientCanvas(
        child: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  expandedHeight: 280 + MediaQuery.paddingOf(context).top,
                  pinned: false,
                  stretch: true,
                  automaticallyImplyLeading: false,
                  toolbarHeight: 0,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.blurBackground,
                    ],
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(photo, fit: BoxFit.cover),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.92),
                                Colors.black.withValues(alpha: 0.35),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.55, 0.95],
                            ),
                          ),
                        ),
                        Positioned(
                          left: AppSpacing.lg,
                          right: AppSpacing.lg,
                          bottom: AppSpacing.xl,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.skill.name,
                                style: KitTypography.pageTitle.copyWith(
                                  fontSize: 24,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                promise,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: KitTypography.bodySecondary.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Wrap(
                        alignment: WrapAlignment.start,
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          AppChip(label: AppCopy.cycleDays),
                          AppChip(label: meta.difficulty),
                          AppChip(label: meta.timeOfDay),
                          AppChip(label: meta.durationLabel),
                          const AppChip(label: '6 человек'),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppHabitDetailSections(skill: widget.skill),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        AppCopy.multiQueueHint,
                        style: AppTypography.caption.copyWith(
                          color: context.prime.inkMuted,
                        ),
                      ),
                      SizedBox(height: bottomBarHeight + AppSpacing.lg),
                    ]),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      _HeroGlassIconButton(
                        tooltip: AppCopy.back,
                        icon: Icons.arrow_back_ios_new_rounded,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      _HeroGlassIconButton(
                        tooltip: _favorite
                            ? 'Убрать из избранного'
                            : 'Сохранить',
                        icon: _favorite
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_outline_rounded,
                        highlighted: _favorite,
                        onPressed: widget.onFavoriteToggle == null
                            ? null
                            : () {
                                widget.onFavoriteToggle!();
                                setState(() => _favorite = !_favorite);
                              },
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _HeroGlassIconButton(
                        tooltip: 'Сравнить',
                        icon: Icons.compare_arrows_rounded,
                        onPressed: widget.allSkills.length < 2
                            ? null
                            : () {
                                Analytics.instance.habitCompareOpened(
                                  widget.skill.id,
                                );
                                showHabitCompareSheet(
                                  context: context,
                                  primary: widget.skill,
                                  allSkills: widget.allSkills,
                                );
                              },
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _HeroGlassIconButton(
                        tooltip: 'Поделиться',
                        icon: Icons.ios_share_rounded,
                        onPressed: () async {
                          final text =
                              'Программа «${widget.skill.name}» в ПРАЙМ — ${AppCopy.cycleDays}';
                          await Clipboard.setData(ClipboardData(text: text));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ссылка скопирована в буфер'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular frosted control for photo hero toolbars.
class _HeroGlassIconButton extends StatelessWidget {
  const _HeroGlassIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.highlighted = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool highlighted;

  static const _size = 44.0;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final iconColor = !enabled
        ? Colors.white.withValues(alpha: 0.38)
        : highlighted
            ? AppColors.primarySoft
            : Colors.white.withValues(alpha: 0.94);

    Widget button = PrimeGlassOverlay(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: SizedBox(
            width: _size,
            height: _size,
            child: Icon(icon, size: 20, color: iconColor),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
