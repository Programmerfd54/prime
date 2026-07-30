import 'package:flutter/material.dart';

import '../../../models/report.dart';
import '../../../models/user.dart';
import '../../../l10n/copy.dart';
import 'profile_editorial_widgets.dart';
import 'profile_tabs.dart';

/// V4 Visual Gate — owner profile hero + tabs (filled).
class GateProfilePresentation extends StatelessWidget {
  const GateProfilePresentation({
    super.key,
    required this.user,
    this.calendar,
    this.habitTags = const [],
    this.selectedTab = OwnProfileTab.overview,
    this.tabBody,
  });

  final UserModel user;
  final CalendarOut? calendar;
  final List<ProfileHabitTag> habitTags;
  final OwnProfileTab selectedTab;
  final Widget? tabBody;

  @override
  Widget build(BuildContext context) {
    final cycleDay = calendar == null ? 0 : (calendar!.successfulDays % 30);
    final consistency7 = calendar == null
        ? 0
        : _consistencyPercent(calendar!, window: 7);
    final subtitle = [
      if (user.nickname.isNotEmpty) '@${user.nickname}',
      if (user.regionName?.isNotEmpty == true) user.regionName,
      if (user.age != null) '${user.age} лет',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileHeroCard(
          displayName: user.name.isEmpty ? 'Профиль' : user.name,
          subtitle: subtitle.isEmpty ? null : subtitle,
          photoUrl: user.photoUrl,
          about: user.about.trim().isEmpty ? null : user.about.trim(),
          tags: habitTags,
          metrics: [
            ProfileMetricPill(
              label: 'Дней подряд',
              value: '${calendar?.currentStreak ?? 0} дн.',
              variant: ProfileMetricPillVariant.gold,
            ),
            ProfileMetricPill(
              label: 'Праймы',
              value: '${user.primePoints}',
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
          ],
          calendar: calendar,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: ProfileTabBar(
            tabs: const ['Обзор', 'Прогресс', 'Привычки', 'Достижения'],
            selectedIndex: selectedTab.index,
            onSelected: (_) {},
          ),
        ),
        if (tabBody != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: tabBody!,
          ),
      ],
    );
  }

  static int _consistencyPercent(CalendarOut calendar, {required int window}) {
    final days = calendar.days;
    if (days.isEmpty) return 0;
    final slice = days.length > window ? days.sublist(days.length - window) : days;
    final met = slice.where((d) => d.reported).length;
    return ((met / slice.length) * 100).round();
  }
}
