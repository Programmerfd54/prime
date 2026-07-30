import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/config/theme.dart';
import 'package:prime/l10n/copy.dart';
import 'package:prime/models/achievement.dart';
import 'package:prime/models/report.dart';
import 'package:prime/models/user.dart';
import 'package:prime/ui/kit/presentation/profile_about_card.dart';
import 'package:prime/ui/kit/presentation/profile_compatibility.dart';
import 'package:prime/ui/kit/presentation/profile_editorial_widgets.dart';
import 'package:prime/ui/kit/presentation/profile_sections.dart';
import 'package:prime/ui/kit/presentation/profile_surfaces.dart';
import 'package:prime/ui/kit/presentation/profile_tabs.dart';
import 'package:prime/ui/kit/presentation/profile_view_model.dart';
import 'package:prime/ui/kit/tokens/kit_layout.dart';

const _gateDir = 'goldens/profile_v3';

CalendarOut _calendar21() {
  final today = DateTime(2026, 7, 29);
  final days = <CalendarDay>[];
  for (var i = 0; i < 28; i++) {
    final d = today.subtract(Duration(days: 27 - i));
    days.add(
      CalendarDay(
        date: d,
        status: i % 5 != 0 ? 'ready' : 'missed',
        reported: i % 5 != 0,
        completed: i % 5 != 0,
        primeAwarded: i % 7 == 0,
        contentText: '',
        attachments: const [],
        reports: const [],
      ),
    );
  }
  return CalendarOut(
    days: days,
    today: today,
    trackingStartDate: days.first.date,
    currentStreak: 6,
    bestStreak: 12,
    successfulDays: 21,
    primePoints: 48,
    cyclePacePercent: 70,
  );
}

UserModel _filledUser() => UserModel(
      id: 'filled-id',
      email: 'demo-filled@example.com',
      nickname: 'demofilled',
      name: 'Мария К.',
      about:
          'Утренний ритм · команда · маленькие шаги каждый день. 22-й день цикла — держим темп вместе.',
      photoUrl: '/uploads/avatars/demo-a3.jpg',
      city: 'Москва',
      regionCode: '77',
      regionName: 'Москва',
      age: 28,
      profileCompleted: true,
      primePoints: 48,
      successfulDays: 21,
      canCreateCustomSkills: false,
      isModerator: false,
      streakShields: 1,
      shieldPending: false,
      createdAt: DateTime(2026, 7, 8),
    );

UserModel _emptyUser() => UserModel(
      id: 'empty-id',
      email: 'demo-empty@example.com',
      nickname: 'demoempty',
      name: 'Аня Новая',
      about: '',
      city: 'Москва',
      regionCode: '77',
      regionName: 'Москва',
      age: 22,
      profileCompleted: false,
      primePoints: 0,
      successfulDays: 0,
      canCreateCustomSkills: false,
      isModerator: false,
      createdAt: DateTime(2026, 7, 26),
    );

UserPublic _publicWithPhoto() => UserPublic(
      id: 'friend-id',
      nickname: 'demofriend',
      name: 'Даша',
      about: 'Подруга Марии · утренний фокус',
      photoUrl: '/uploads/avatars/demo-a5.jpg',
      city: 'Москва',
      regionCode: '77',
      regionName: 'Москва',
      age: 27,
      primePoints: 12,
      successfulDays: 14,
      privacySettings: const {
        'show_bio': true,
        'show_region': true,
        'show_age': true,
        'show_habits': true,
        'show_streak': true,
        'show_achievements': true,
        'show_groups': true,
      },
    );

UserPublic _publicNoPhoto() => UserPublic(
      id: 'empty-id',
      nickname: 'demoempty',
      name: 'Аня Новая',
      about: '',
      photoUrl: '',
      city: 'Москва',
      regionCode: '77',
      regionName: 'Москва',
      age: 22,
      primePoints: 0,
      successfulDays: 0,
      privacySettings: const {
        'show_bio': true,
        'show_region': true,
        'show_age': true,
        'show_habits': true,
        'show_streak': true,
        'show_achievements': true,
        'show_groups': true,
      },
    );

List<AchievementModel> _achievements() => [
      AchievementModel(
        id: '1',
        code: 'student',
        name: 'Ученик',
        description: '30 дней в PRIME',
        requiredDays: 30,
        icon: 'medal',
        unlocked: false,
      ),
      AchievementModel(
        id: '2',
        code: 'master',
        name: 'Мастер',
        description: '90 дней',
        requiredDays: 90,
        icon: 'medal',
        unlocked: false,
      ),
    ];

Widget _harness({
  required Size size,
  required Widget child,
  Widget? bottomBar,
}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(
        backgroundColor: ProfileSurfaces.canvas,
        body: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: KitLayout.navBottomClearance),
          child: child,
        ),
        bottomNavigationBar: bottomBar,
      ),
    ),
  );
}

Widget _ownHero(UserModel user, CalendarOut calendar) {
  return ProfileHeroCard(
    displayName: user.name,
    subtitle: '@${user.nickname} · ${user.regionName} · ${user.age} лет',
    statusLine: 'Утренний фокус',
    photoUrl: user.photoUrl,
    tags: profileHabitTagsFromNames(['Утренний фокус', 'Чтение']),
    metrics: [
      ProfileMetricPill(
        label: 'Дней подряд',
        value: '${calendar.currentStreak} дн.',
        variant: ProfileMetricPillVariant.gold,
      ),
      ProfileMetricPill(
        label: 'Праймы',
        value: '${user.primePoints}',
        variant: ProfileMetricPillVariant.charcoal,
      ),
      ProfileMetricPill(
        label: AppCopy.profileProgressLabel,
        value: '21/30',
        variant: ProfileMetricPillVariant.hatched,
      ),
      ProfileMetricPill(
        label: 'Стаб. 7д',
        value: '86%',
        variant: ProfileMetricPillVariant.glass,
      ),
    ],
    calendar: calendar,
  );
}

Widget _ownTabShell({
  required OwnProfileTab tab,
  required ProfileAboutData aboutData,
  CalendarOut? calendar,
}) {
  Widget body;
  switch (tab) {
    case OwnProfileTab.overview:
      body = ProfileAboutCard(data: aboutData);
    case OwnProfileTab.progress:
      body = Column(
        children: [
          ProfileCurrentCycleSection(
            successfulDays: 21,
            currentStreak: 6,
            primePoints: 48,
            bestStreak: 12,
            cyclePacePercent: 70,
            calendar: calendar,
            habitName: 'Утренний фокус',
            memberPhotoUrls: const [],
            reportedToday: true,
          ),
          const SizedBox(height: 16),
          ProfileAnalyticsSection(calendar: calendar, insights: const []),
        ],
      );
    case OwnProfileTab.habits:
      body = ProfileHabitTagsRow(
        tags: profileHabitTagsFromNames(['Утренний фокус', 'Чтение']),
      );
    case OwnProfileTab.achievements:
      body = ProfileAchievementsSection(
        achievements: _achievements(),
        successfulDays: 21,
      );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ProfileTabBar(
        tabs: const ['Обзор', 'Прогресс', 'Привычки', 'Достижения'],
        selectedIndex: tab.index,
        onSelected: (_) {},
      ),
      const SizedBox(height: 12),
      body,
    ],
  );
}

Widget _publicHero(PublicProfileProjection projection) {
  return ProfileHeroCard(
    displayName: projection.displayName,
    subtitle: projection.subtitle,
    photoUrl: projection.photoUrl,
    tags: projection.tags,
    metrics: projection.metrics,
    mode: ProfileHeroMode.public,
    statusBadge: projection.statusBadge,
    showChart: projection.showChart,
  );
}

Widget _publicTabShell({
  required PublicProfileTab tab,
  required PublicProfileProjection projection,
}) {
  Widget body;
  switch (tab) {
    case PublicProfileTab.overview:
      body = Column(
        children: [
          ProfilePublicStatsRow(stats: projection.publicStats),
          const SizedBox(height: 12),
          ProfileInfoRows(rows: projection.infoRows),
          const SizedBox(height: 12),
          ProfileAboutCard(data: projection.aboutData),
        ],
      );
    case PublicProfileTab.compatibility:
      body = ProfileCompatibilitySection(
        compatibility: projection.compatibility,
      );
    case PublicProfileTab.habits:
      body = ProfileHabitTagsRow(tags: projection.tags);
    case PublicProfileTab.achievements:
      body = ProfileAchievementsSection(
        achievements: _achievements(),
        successfulDays: projection.aboutData.currentHabit != null ? 14 : 0,
      );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ProfileTabBar(
        tabs: const ['Обзор', 'Совместимость', 'Привычки', 'Достижения'],
        selectedIndex: tab.index,
        onSelected: (_) {},
      ),
      const SizedBox(height: 12),
      body,
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('profile v3 gate §41', () {
    testWidgets('01 own filled overview', (tester) async {
      final user = _filledUser();
      final calendar = _calendar21();
      final about = buildOwnAboutData(
        user: user,
        habitNames: const ['Утренний фокус'],
        cycleDay: 21,
      );
      await tester.pumpWidget(
        _harness(
          size: const Size(390, 844),
          child: Column(
            children: [
              _ownHero(user, calendar),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _ownTabShell(
                  tab: OwnProfileTab.overview,
                  aboutData: about,
                  calendar: calendar,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('$_gateDir/01_own_filled_overview.png'),
      );
    });

    testWidgets('02 own about filled', (tester) async {
      final about = buildOwnAboutData(
        user: _filledUser(),
        habitNames: const ['Утренний фокус'],
        cycleDay: 21,
      );
      await tester.pumpWidget(
        _harness(
          size: const Size(390, 844),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ProfileAboutCard(data: about),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('$_gateDir/02_own_about_filled.png'),
      );
    });

    testWidgets('03 own completeness', (tester) async {
      final about = buildOwnAboutData(user: _emptyUser(), habitNames: const []);
      await tester.pumpWidget(
        _harness(
          size: const Size(390, 844),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ProfileAboutCard(
              data: about,
              onFillProfile: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('$_gateDir/03_own_completeness.png'),
      );
    });

    testWidgets('04 public with photo', (tester) async {
      final projection = PublicProfileProjection.from(
        profile: _publicWithPhoto(),
        habitNames: const ['Утренний фокус'],
        sharedGroups: const ['Команда Марии'],
      );
      await tester.pumpWidget(
        _harness(
          size: const Size(390, 844),
          bottomBar: ProfileActionBar(
            primaryLabel: 'Написать',
            onPrimary: () {},
            secondaryLabel: 'Пригласить',
            onSecondary: () {},
            onSave: () {},
            onShare: () {},
            onReport: () {},
          ),
          child: Column(
            children: [
              _publicHero(projection),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _publicTabShell(
                  tab: PublicProfileTab.overview,
                  projection: projection,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('$_gateDir/04_public_with_photo.png'),
      );
    });

    testWidgets('05 public no photo', (tester) async {
      final projection = PublicProfileProjection.from(
        profile: _publicNoPhoto(),
      );
      await tester.pumpWidget(
        _harness(
          size: const Size(390, 844),
          child: _publicHero(projection),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('$_gateDir/05_public_no_photo.png'),
      );
    });

    testWidgets('06 public overview', (tester) async {
      final projection = PublicProfileProjection.from(
        profile: _publicWithPhoto(),
        habitNames: const ['Утренний фокус'],
        sharedGroups: const ['Команда Марии'],
      );
      await tester.pumpWidget(
        _harness(
          size: const Size(390, 844),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _publicTabShell(
              tab: PublicProfileTab.overview,
              projection: projection,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('$_gateDir/06_public_overview.png'),
      );
    });

    testWidgets('07 public compatibility', (tester) async {
      final projection = PublicProfileProjection.from(
        profile: _publicWithPhoto(),
        habitNames: const ['Утренний фокус'],
        sharedGroups: const ['Команда Марии'],
        viewerPreferredTime: 'morning',
      );
      await tester.pumpWidget(
        _harness(
          size: const Size(390, 844),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _publicTabShell(
              tab: PublicProfileTab.compatibility,
              projection: projection,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('$_gateDir/07_public_compatibility.png'),
      );
    });

    testWidgets('08 public more menu', (tester) async {
      await tester.pumpWidget(
        _harness(
          size: const Size(390, 844),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ProfilePalette.charcoal,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: ProfilePalette.coolGrey.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.alternate_email),
                    title: const Text('Скопировать @demofriend'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_add_outlined),
                    title: const Text('Пригласить'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.block),
                    title: const Text('Скрыть'),
                  ),
                  ListTile(
                    leading: Icon(Icons.flag, color: Colors.red.shade300),
                    title: Text(
                      'Пожаловаться',
                      style: TextStyle(color: Colors.red.shade300),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('$_gateDir/08_public_more_menu.png'),
      );
    });

    testWidgets('09 own progress 21d', (tester) async {
      final calendar = _calendar21();
      await tester.pumpWidget(
        _harness(
          size: const Size(390, 844),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _ownTabShell(
              tab: OwnProfileTab.progress,
              aboutData: buildOwnAboutData(user: _filledUser()),
              calendar: calendar,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('$_gateDir/09_own_progress_21d.png'),
      );
    });

    testWidgets('10 own achievements', (tester) async {
      await tester.pumpWidget(
        _harness(
          size: const Size(390, 844),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _ownTabShell(
              tab: OwnProfileTab.achievements,
              aboutData: buildOwnAboutData(user: _filledUser()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('$_gateDir/10_own_achievements.png'),
      );
    });

    testWidgets('11 compact phone', (tester) async {
      final user = _filledUser();
      await tester.pumpWidget(
        _harness(
          size: const Size(375, 812),
          child: Column(
            children: [
              _ownHero(user, _calendar21()),
              Padding(
                padding: const EdgeInsets.all(12),
                child: _ownTabShell(
                  tab: OwnProfileTab.overview,
                  aboutData: buildOwnAboutData(user: user, cycleDay: 21),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('$_gateDir/11_compact_phone.png'),
      );
    });

    testWidgets('12 web medium', (tester) async {
      final user = _filledUser();
      await tester.pumpWidget(
        _harness(
          size: const Size(900, 844),
          child: Column(
            children: [
              _ownHero(user, _calendar21()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _ownTabShell(
                  tab: OwnProfileTab.overview,
                  aboutData: buildOwnAboutData(user: user, cycleDay: 21),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('$_gateDir/12_web_medium.png'),
      );
    });
  });
}
