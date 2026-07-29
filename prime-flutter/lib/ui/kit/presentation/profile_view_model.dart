import 'package:flutter/material.dart';

import '../../../core/media/media_urls.dart';
import '../../../models/user.dart';
import 'profile_editorial_widgets.dart';
import 'profile_sections.dart';
import 'profile_utils.dart';
class PublicProfileProjection {
  const PublicProfileProjection({
    required this.displayName,
    this.subtitle,
    this.photoUrl,
    this.about,
    this.tags = const [],
    this.metrics = const [],
    this.aboutRows = const [],
    this.showChart = false,
    this.isRestricted = false,
  });

  final String displayName;
  final String? subtitle;
  final String? photoUrl;
  final String? about;
  final List<ProfileHabitTag> tags;
  final List<ProfileMetricPill> metrics;
  final List<ProfileAboutRow> aboutRows;
  final bool showChart;
  final bool isRestricted;

  factory PublicProfileProjection.from({
    required UserPublic profile,
    List<String> habitNames = const [],
    List<String> sharedGroups = const [],
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

    final aboutRows = <ProfileAboutRow>[
      if (showRegion && profile.regionName?.isNotEmpty == true)
        ProfileAboutRow(
          icon: Icons.location_on_outlined,
          label: 'Регион',
          value: profile.regionName!,
        ),
      if (showAge && profile.age != null)
        ProfileAboutRow(
          icon: Icons.cake_outlined,
          label: 'Возраст',
          value: '${profile.age} лет',
        ),
      if (showHabits && habitNames.isNotEmpty)
        ProfileAboutRow(
          icon: Icons.bolt_outlined,
          label: 'Привычки',
          value: habitNames.take(5).join(', '),
        ),
      if (showGroups && sharedGroups.isNotEmpty)
        ProfileAboutRow(
          icon: Icons.groups_outlined,
          label: 'Общие группы',
          value: sharedGroups.join(', '),
        ),
    ];

    return PublicProfileProjection(
      displayName: displayName,
      subtitle: subtitle.isEmpty ? null : subtitle,
      photoUrl: absolutePhotoUrl(profile.photoUrl),
      about: about?.isEmpty == true ? null : about,
      tags: tags,
      metrics: metrics,
      aboutRows: aboutRows,
      showChart: showMetrics,
      isRestricted: isRestricted,
    );
  }
}

/// Own-profile metadata rows (non-hero fields).
List<ProfileAboutRow> ownProfileAboutRows({
  required UserModel user,
  Iterable<String> habitNames = const [],
}) {
  final rows = <ProfileAboutRow>[
    ProfileAboutRow(
      icon: Icons.calendar_today_outlined,
      label: 'В PRIME с',
      value: profileMemberSinceLabel(user.createdAt),
    ),
  ];
  if (user.regionName?.isNotEmpty == true) {
    rows.add(
      ProfileAboutRow(
        icon: Icons.location_on_outlined,
        label: 'Регион',
        value: user.regionName!,
      ),
    );
  }
  if (user.age != null) {
    rows.add(
      ProfileAboutRow(
        icon: Icons.cake_outlined,
        label: 'Возраст',
        value: '${user.age} лет',
      ),
    );
  }
  final habits = habitNames.map((h) => h.trim()).where((h) => h.isNotEmpty);
  if (habits.isNotEmpty) {
    rows.add(
      ProfileAboutRow(
        icon: Icons.bolt_outlined,
        label: 'Привычки',
        value: habits.take(5).join(', '),
      ),
    );
  }
  if (user.city?.isNotEmpty == true && user.city != user.regionName) {
    rows.add(
      ProfileAboutRow(
        icon: Icons.place_outlined,
        label: 'Город',
        value: user.city!,
      ),
    );
  }
  return rows;
}
