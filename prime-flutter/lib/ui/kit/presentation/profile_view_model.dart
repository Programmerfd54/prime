import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/profile/profile_preferences.dart';
import '../../../core/media/media_urls.dart';
import '../../../l10n/copy.dart';
import '../../../models/group.dart';
import '../../../models/user.dart';
import 'profile_editorial_widgets.dart';
import 'profile_icons.dart';
import 'profile_sections.dart';
import 'profile_utils.dart';

class ProfileAboutFact {
  const ProfileAboutFact({
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? accent;
}

class ProfileAboutData {
  const ProfileAboutData({
    this.bio,
    this.currentFocus,
    this.currentHabit,
    this.cycleGoal,
    this.facts = const [],
    this.tags = const [],
    this.teamStatus,
    this.isOwner = false,
    this.isPartiallyPrivate = false,
    this.completenessPercent = 100,
  });

  final String? bio;
  final String? currentFocus;
  final String? currentHabit;
  final String? cycleGoal;
  final List<ProfileAboutFact> facts;
  final List<ProfileHabitTag> tags;
  final String? teamStatus;
  final bool isOwner;
  final bool isPartiallyPrivate;
  final int completenessPercent;

  bool get hasVisibleContent =>
      (bio?.isNotEmpty ?? false) ||
      (currentFocus?.isNotEmpty ?? false) ||
      facts.isNotEmpty ||
      tags.isNotEmpty ||
      (teamStatus?.isNotEmpty ?? false);

  ProfileAboutData copyWith({
    String? bio,
    String? currentFocus,
    String? currentHabit,
    String? cycleGoal,
    List<ProfileAboutFact>? facts,
    List<ProfileHabitTag>? tags,
    String? teamStatus,
    bool? isOwner,
    bool? isPartiallyPrivate,
    int? completenessPercent,
  }) {
    return ProfileAboutData(
      bio: bio ?? this.bio,
      currentFocus: currentFocus ?? this.currentFocus,
      currentHabit: currentHabit ?? this.currentHabit,
      cycleGoal: cycleGoal ?? this.cycleGoal,
      facts: facts ?? this.facts,
      tags: tags ?? this.tags,
      teamStatus: teamStatus ?? this.teamStatus,
      isOwner: isOwner ?? this.isOwner,
      isPartiallyPrivate: isPartiallyPrivate ?? this.isPartiallyPrivate,
      completenessPercent: completenessPercent ?? this.completenessPercent,
    );
  }
}

class ProfilePublicStat {
  const ProfilePublicStat({required this.label, required this.value});
  final String label;
  final String value;
}

class ProfileInfoRow {
  const ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
}

class ProfileCompatibility {
  const ProfileCompatibility({
    required this.summaryLabel,
    this.reasons = const [],
  });

  final String summaryLabel;
  final List<String> reasons;
}

class PublicProfileProjection {
  const PublicProfileProjection({
    required this.displayName,
    this.subtitle,
    this.photoUrl,
    this.about,
    this.tags = const [],
    this.metrics = const [],
    this.aboutData = const ProfileAboutData(),
    this.publicStats = const [],
    this.infoRows = const [],
    this.compatibility = const ProfileCompatibility(summaryLabel: 'Пока мало данных'),
    this.statusBadge,
    this.showChart = false,
    this.isRestricted = false,
  });

  final String displayName;
  final String? subtitle;
  final String? photoUrl;
  final String? about;
  final List<ProfileHabitTag> tags;
  final List<ProfileMetricPill> metrics;
  final ProfileAboutData aboutData;
  final List<ProfilePublicStat> publicStats;
  final List<ProfileInfoRow> infoRows;
  final ProfileCompatibility compatibility;
  final String? statusBadge;
  final bool showChart;
  final bool isRestricted;

  /// Legacy rows — prefer [aboutData].
  List<ProfileAboutRow> get aboutRows => const [];

  factory PublicProfileProjection.from({
    required UserPublic profile,
    List<String> habitNames = const [],
    List<String> sharedGroups = const [],
    GroupModel? viewerActiveGroup,
    String? viewerPreferredTime,
  }) {
    final privacy = profile.privacySettings;
    final showBio = privacy['show_bio'] ?? true;
    final showRegion = privacy['show_region'] ?? true;
    final showAge = privacy['show_age'] ?? true;
    final showHabits = privacy['show_habits'] ?? true;
    final showStreak = privacy['show_streak'] ?? true;
    final showAchievements = privacy['show_achievements'] ?? true;
    final showGroups = privacy['show_groups'] ?? true;

    final showMetrics = showStreak || showAchievements;
    final isRestricted = !showBio &&
        !showMetrics &&
        !showHabits &&
        !showRegion &&
        !showAge;

    final displayName =
        profile.name.isEmpty ? '@${profile.nickname}' : profile.name;

    final location = [
      if (showRegion && profile.regionName?.isNotEmpty == true)
        profile.regionName,
      if (showAge && profile.age != null) '${profile.age} лет',
    ].join(' · ');

    final subtitle = [
      if (profile.nickname.isNotEmpty && profile.name.isNotEmpty)
        '@${profile.nickname}',
      if (location.isNotEmpty) location,
    ].join(' · ');

    final about = showBio ? sanitizeProfileBio(profile.about) : null;
    final tags = showHabits
        ? profileHabitTagsFromNames(habitNames)
        : const <ProfileHabitTag>[];

    final metrics = showMetrics
        ? buildPublicProfileMetrics(
            primes: showAchievements ? profile.primePoints : null,
            successfulDays: showStreak ? profile.successfulDays : null,
          )
        : const <ProfileMetricPill>[];

    final habit = habitNames.isNotEmpty ? habitNames.first : null;
    final cycleDay = profile.successfulDays % 30;
    final inCycle = profile.successfulDays > 0;

    final statusBadge = inCycle
        ? 'В цикле · день ${cycleDay == 0 ? 30 : cycleDay}/30'
        : (sharedGroups.isEmpty ? 'Ищет команду' : 'Открыт к приглашениям');

    final aboutData = buildPublicAboutData(
      profile: profile,
      habitNames: habitNames,
      showBio: showBio,
      showRegion: showRegion,
      showAge: showAge,
      showHabits: showHabits,
      showGroups: showGroups,
      sharedGroups: sharedGroups,
      inCycle: inCycle,
    );

    final consistency7 = profile.successfulDays > 0
        ? ((profile.successfulDays.clamp(0, 7) / 7) * 100).round()
        : 0;

    final publicStats = showMetrics
        ? [
            ProfilePublicStat(
              label: 'Стаб. 7д',
              value: consistency7 > 0 ? '$consistency7%' : '—',
            ),
            ProfilePublicStat(
              label: 'Дней в PRIME',
              value: '${profile.successfulDays}',
            ),
            ProfilePublicStat(
              label: 'Праймы',
              value: '${profile.primePoints}',
            ),
          ]
        : const <ProfilePublicStat>[];

    final infoRows = <ProfileInfoRow>[
      if (showHabits && habit != null)
        ProfileInfoRow(
          icon: ProfileIcons.cycle,
          label: 'Привычка',
          value: habit,
        ),
      ProfileInfoRow(
        icon: LucideIcons.sun,
        label: 'Время',
        value: _preferredTimeLabel(viewerPreferredTime),
      ),
      ProfileInfoRow(
        icon: LucideIcons.users,
        label: 'Формат',
        value: sharedGroups.isNotEmpty ? 'Команда' : 'Самостоятельно',
      ),
      if (showRegion && profile.regionName?.isNotEmpty == true)
        ProfileInfoRow(
          icon: LucideIcons.mapPin,
          label: 'Регион',
          value: profile.regionName!,
        ),
      if (showGroups && sharedGroups.isNotEmpty)
        ProfileInfoRow(
          icon: ProfileIcons.invite,
          label: 'Общие группы',
          value: sharedGroups.take(2).join(', '),
        ),
    ];

    final compatibility = buildCompatibility(
      profile: profile,
      habitNames: habitNames,
      sharedGroups: sharedGroups,
      viewerPreferredTime: viewerPreferredTime,
    );

    return PublicProfileProjection(
      displayName: displayName,
      subtitle: subtitle.isEmpty ? null : subtitle,
      photoUrl: absolutePhotoUrl(profile.photoUrl),
      about: about?.isEmpty == true ? null : about,
      tags: tags,
      metrics: metrics,
      aboutData: aboutData,
      publicStats: publicStats,
      infoRows: infoRows,
      compatibility: compatibility,
      statusBadge: isRestricted ? 'Приватный' : statusBadge,
      showChart: showMetrics,
      isRestricted: isRestricted,
    );
  }
}

ProfileAboutData buildOwnAboutData({
  required UserModel user,
  Iterable<String> habitNames = const [],
  GroupModel? activeGroup,
  int? cycleDay,
  Map<String, dynamic>? preferences,
}) {
  final habits = habitNames.map((h) => h.trim()).where((h) => h.isNotEmpty);
  final habit = habits.isNotEmpty ? habits.first : null;
  final bio = sanitizeProfileBio(user.about);
  final prefs = preferences ?? const {};
  final timeOfDay = prefs[ProfilePreferences.preferredTimeOfDayKey] as String?;
  final supportStyle = prefs[ProfilePreferences.supportStyleKey] as String?;

  final facts = <ProfileAboutFact>[
    ProfileAboutFact(
      icon: LucideIcons.clock,
      label: 'Время',
      value: ProfilePreferences.preferredTimeLabel(timeOfDay),
      accent: ProfilePalette.brandSoft,
    ),
    ProfileAboutFact(
      icon: LucideIcons.users,
      label: 'Формат',
      value: activeGroup != null ? 'Команда' : 'Самостоятельно',
      accent: ProfilePalette.mint,
    ),
    ProfileAboutFact(
      icon: LucideIcons.heartHandshake,
      label: 'Поддержка',
      value: ProfilePreferences.supportStyleLabel(supportStyle),
      accent: ProfilePalette.coral,
    ),
    ProfileAboutFact(
      icon: LucideIcons.calendar,
      label: 'В PRIME с',
      value: profileMemberSinceLabel(user.createdAt),
      accent: ProfilePalette.coolGrey,
    ),
  ];

  final focus = habit != null
      ? (cycleDay != null && cycleDay > 0
          ? 'День $cycleDay/30 · $habit'
          : habit)
      : 'Выбрать первую привычку';

  final filled = [
    if (bio.isNotEmpty) 1 else 0,
    if (habit != null) 1 else 0,
    if (user.regionName?.isNotEmpty == true) 1 else 0,
    if (user.about.length > 20) 1 else 0,
    if (timeOfDay != null) 1 else 0,
    if (supportStyle != null) 1 else 0,
  ].fold<int>(0, (a, b) => a + b);

  final completeness = ((filled / 6) * 100).round().clamp(0, 100);

  return ProfileAboutData(
    bio: bio.isEmpty ? null : bio,
    currentFocus: focus,
    currentHabit: habit,
    cycleGoal: cycleDay != null && cycleDay > 0
        ? 'Цель: завершить 30-дневный цикл'
        : null,
    facts: facts,
    tags: profileHabitTagsFromNames(habits),
    teamStatus: activeGroup != null
        ? 'Уже в команде'
        : (habit != null ? 'Ищу команду' : null),
    isOwner: true,
    completenessPercent: completeness,
  );
}

ProfileAboutData buildPublicAboutData({
  required UserPublic profile,
  required List<String> habitNames,
  required bool showBio,
  required bool showRegion,
  required bool showAge,
  required bool showHabits,
  required bool showGroups,
  required List<String> sharedGroups,
  required bool inCycle,
}) {
  final bio = showBio ? sanitizeProfileBio(profile.about) : null;
  final habit = habitNames.isNotEmpty ? habitNames.first : null;

  final facts = <ProfileAboutFact>[
    if (showHabits && habit != null)
      ProfileAboutFact(
        icon: ProfileIcons.cycle,
        label: 'Привычка',
        value: habit,
        accent: ProfilePalette.brandSoft,
      ),
    ProfileAboutFact(
      icon: LucideIcons.clock,
      label: 'Время',
      value: _preferredTimeLabel(null),
      accent: ProfilePalette.mint,
    ),
    ProfileAboutFact(
      icon: LucideIcons.users,
      label: 'Формат',
      value: sharedGroups.isNotEmpty ? 'Команда' : 'Самостоятельно',
    ),
    if (showRegion && profile.regionName?.isNotEmpty == true)
      ProfileAboutFact(
        icon: LucideIcons.mapPin,
        label: 'Регион',
        value: profile.regionName!,
      )
    else if (showAge && profile.age != null)
      ProfileAboutFact(
        icon: LucideIcons.cake,
        label: 'Возраст',
        value: '${profile.age} лет',
      ),
  ];

  return ProfileAboutData(
    bio: bio?.isEmpty == true ? null : bio,
    currentFocus: habit,
    currentHabit: habit,
    facts: facts.take(4).toList(),
    tags: showHabits ? profileHabitTagsFromNames(habitNames) : const [],
    teamStatus: inCycle
        ? 'В цикле'
        : (sharedGroups.isEmpty ? 'Ищет команду' : null),
    isPartiallyPrivate: !showBio || !showRegion,
  );
}

ProfileCompatibility buildCompatibility({
  required UserPublic profile,
  required List<String> habitNames,
  required List<String> sharedGroups,
  String? viewerPreferredTime,
}) {
  final reasons = <String>[];

  if (habitNames.isNotEmpty) {
    reasons.add('Общая привычка: ${habitNames.first}');
  }
  if (sharedGroups.isNotEmpty) {
    reasons.add('Общая группа: ${sharedGroups.first}');
  }
  if (viewerPreferredTime != null) {
    reasons.add('Совпадает предпочитаемое время: ${_preferredTimeLabel(viewerPreferredTime)}');
  } else {
    reasons.add('Подходит утренний ритм');
  }
  if (profile.successfulDays >= 7) {
    reasons.add('Похожий темп: ${profile.successfulDays} успешных дней');
  }
  reasons.add('Одинаковый формат поддержки: по делу');

  final label = reasons.length >= 3
      ? 'Хорошо совпадаете'
      : (reasons.isEmpty ? 'Пока мало данных' : 'Есть точки соприкосновения');

  return ProfileCompatibility(
    summaryLabel: label,
    reasons: reasons.take(5).toList(),
  );
}

String _preferredTimeLabel(String? raw) {
  switch (raw) {
    case 'evening':
      return 'Вечер';
    case 'day':
      return 'День';
    case 'morning':
    default:
      return 'Утро';
  }
}

/// Own-profile metadata rows — deprecated, use [ProfileAboutData].
List<ProfileAboutRow> ownProfileAboutRows({
  required UserModel user,
  Iterable<String> habitNames = const [],
}) {
  return [];
}

List<ProfileMetricPill> buildPublicProfileMetrics({
  int? primes,
  int? successfulDays,
}) {
  return [
    if (successfulDays != null)
      ProfileMetricPill(
        label: 'Дней подряд',
        value: successfulDays > 0 ? '$successfulDays дн.' : '0 дн.',
        variant: ProfileMetricPillVariant.gold,
      ),
    if (primes != null)
      ProfileMetricPill(
        label: 'Праймы',
        value: '$primes',
        variant: ProfileMetricPillVariant.charcoal,
      ),
    ProfileMetricPill(
      label: AppCopy.profileProgressLabel,
      value: successfulDays != null && successfulDays > 0
          ? '${successfulDays % 30}/30'
          : AppCopy.profileProgressEmpty,
      variant: ProfileMetricPillVariant.hatched,
    ),
    ProfileMetricPill(
      label: 'Стаб. 7д',
      value: successfulDays != null && successfulDays > 0 ? '—' : '—',
      variant: ProfileMetricPillVariant.glass,
    ),
  ];
}

String profileMemberSinceLabel(DateTime date) {
  const months = [
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
