import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/home/home_state.dart';
import 'package:prime/core/sync/realtime_client.dart';
import 'package:prime/data/api_client.dart';
import 'package:provider/provider.dart';
import 'package:prime/design/theme/prime_theme.dart';
import 'package:prime/models/direct_chat.dart';
import 'package:prime/models/report.dart';
import 'package:prime/models/user.dart';
import 'package:prime/ui/kit/presentation/gate_chats_presentation.dart';
import 'package:prime/ui/kit/presentation/gate_conversation_presentation.dart';
import 'package:prime/ui/kit/presentation/gate_groups_presentation.dart';
import 'package:prime/ui/kit/presentation/gate_home_presentation.dart';
import 'package:prime/ui/kit/presentation/gate_notifications_presentation.dart';
import 'package:prime/ui/kit/presentation/gate_groups_active_presentation.dart';
import 'package:prime/ui/kit/presentation/gate_profile_presentation.dart';
import 'package:prime/ui/kit/presentation/profile_about_card.dart';
import 'package:prime/ui/kit/presentation/profile_editorial_widgets.dart';
import 'package:prime/ui/kit/presentation/profile_surfaces.dart';
import 'package:prime/ui/kit/presentation/profile_tabs.dart';
import 'package:prime/ui/kit/presentation/profile_view_model.dart';
import 'package:prime/ui/kit/tokens/kit_layout.dart';

const _gateDir = 'goldens/v4_visual_gate';

UserModel _filledUser() => UserModel(
      id: 'filled-id',
      email: 'demo-filled@example.com',
      nickname: 'demofilled',
      name: 'Мария К.',
      about: 'Утренний ритм · команда · маленькие шаги каждый день.',
      photoUrl: null,
      city: 'Москва',
      regionCode: '77',
      regionName: 'Москва',
      age: 28,
      profileCompleted: true,
      primePoints: 48,
      successfulDays: 21,
      canCreateCustomSkills: false,
      isModerator: false,
      createdAt: DateTime(2026, 7, 8),
    );

UserModel _newUser() => UserModel(
      id: 'new-id',
      email: 'demo-empty@example.com',
      nickname: 'alex',
      name: 'Алекс',
      about: '',
      photoUrl: null,
      city: 'Москва',
      regionCode: '77',
      regionName: 'Москва',
      age: 26,
      profileCompleted: true,
      primePoints: 0,
      successfulDays: 0,
      canCreateCustomSkills: false,
      isModerator: false,
      createdAt: DateTime(2026, 7, 29),
    );

UserPublic _friend() => UserPublic(
      id: 'friend-id',
      nickname: 'ivan',
      name: 'Ivan',
      about: '',
      photoUrl: '',
      city: 'Москва',
      regionCode: '77',
      regionName: 'Москва',
      age: 27,
      primePoints: 12,
      successfulDays: 14,
    );

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

final _gateRealtime = RealtimeClient(ApiClient());

Widget _harness({required Widget child, Size size = const Size(390, 844)}) {
  return ChangeNotifierProvider<RealtimeClient>.value(
    value: _gateRealtime,
    child: MaterialApp(
      theme: PrimeTheme.dark(),
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(
          backgroundColor: ProfileSurfaces.canvas,
          body: SingleChildScrollView(
            padding: KitLayout.scrollBottomInset,
            child: child,
          ),
        ),
      ),
    ),
  );
}

Widget _conversationHarness({required Widget child}) {
  return ChangeNotifierProvider<RealtimeClient>.value(
    value: _gateRealtime,
    child: MaterialApp(
      theme: PrimeTheme.dark(),
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: Scaffold(
          backgroundColor: ProfileSurfaces.canvas,
          body: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('V4 visual gate', () {
    testWidgets('01 home active cycle', (tester) async {
      await tester.pumpWidget(
        _harness(
          child: GateHomePresentation(
            user: _filledUser(),
            dateLabel: 'Среда, 29 июля',
            homeState: HomeStateResolver.resolve(
              const HomeStateInput(
                hasActiveGroups: true,
                reportedToday: false,
                hasHistory: true,
                searching: false,
                teamReady: 4,
                teamTotal: 6,
                streak: 6,
                primarySkillName: 'Утренний фокус',
              ),
            ),
            streak: 6,
            primes: 48,
            successDays: 21,
            teamReady: 4,
            teamTotal: 6,
            teamPulse: null,
            directChats: const [],
            onAvatarTap: () {},
            onPrimaryAction: () {},
            onOpenGroup: () {},
            onOpenChats: () {},
            onPrimesTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('$_gateDir/01_home_active.png'),
      );
    });

    testWidgets('02 groups searching', (tester) async {
      await tester.pumpWidget(
        _harness(
          child: GateGroupsPresentation(
            habitName: 'Одна глава',
            found: 1,
            checklist: const [
              GateReadinessItem(
                title: 'О себе',
                subtitle: 'Заполнено — команда видит вас',
                done: true,
              ),
              GateReadinessItem(
                title: 'Время дня',
                subtitle: 'Помогает подобрать совместимость',
                done: false,
                actionLabel: 'Выбрать',
              ),
              GateReadinessItem(
                title: 'Пригласить друга',
                subtitle: 'Добавляет конкретного участника',
                done: false,
                actionLabel: 'Пригласить',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('$_gateDir/02_groups_searching.png'),
      );
    });

    testWidgets('03 chats list filled', (tester) async {
      await tester.pumpWidget(
        _harness(
          child: GateChatsPresentation(
            chats: [
              gateDemoChat(_friend(), body: 'Приглашаю в пару по привычке…', unread: 1),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('$_gateDir/03_chats_filled.png'),
      );
    });

    testWidgets('04 conversation filled', (tester) async {
      await tester.pumpWidget(
        _conversationHarness(
          child: GateConversationPresentation(
            friend: _friend(),
            messages: const [
              GateMessage(body: 'Привет!', outbound: true),
              GateMessage(body: 'Привет!', outbound: false),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('$_gateDir/04_conversation_filled.png'),
      );
    });

    testWidgets('05 profile owner filled', (tester) async {
      final user = _filledUser();
      final about = buildOwnAboutData(
        user: user,
        habitNames: const ['Утренний фокус'],
        cycleDay: 21,
      );
      await tester.pumpWidget(
        _harness(
          child: GateProfilePresentation(
            user: user,
            calendar: _calendar21(),
            habitTags: profileHabitTagsFromNames(['Утренний фокус']),
            selectedTab: OwnProfileTab.overview,
            tabBody: ProfileAboutCard(data: about),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('$_gateDir/05_profile_owner_filled.png'),
      );
    });

    testWidgets('06 home new user', (tester) async {
      await tester.pumpWidget(
        _harness(
          child: GateHomePresentation(
            user: _newUser(),
            dateLabel: 'Среда, 29 июля',
            homeState: HomeStateResolver.resolve(
              const HomeStateInput(
                hasActiveGroups: false,
                reportedToday: false,
                hasHistory: false,
                searching: false,
                teamReady: 0,
                teamTotal: 0,
                streak: 0,
              ),
            ),
            streak: 0,
            primes: 0,
            successDays: 0,
            teamReady: 0,
            teamTotal: 0,
            teamPulse: null,
            directChats: const [],
            onAvatarTap: () {},
            onPrimaryAction: () {},
            onOpenGroup: () {},
            onOpenChats: () {},
            onPrimesTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('$_gateDir/06_home_new_user.png'),
      );
    });

    testWidgets('07 chats empty personal', (tester) async {
      await tester.pumpWidget(
        _harness(
          child: GateChatsPresentation(
            chats: const [],
            segmentIndex: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('$_gateDir/07_chats_empty.png'),
      );
    });

    testWidgets('08 notifications empty', (tester) async {
      await tester.pumpWidget(
        _harness(
          child: const GateNotificationCenterSheet(
            items: [],
            unreadCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('$_gateDir/08_notifications_empty.png'),
      );
    });

    testWidgets('09 groups confirmation', (tester) async {
      await tester.pumpWidget(
        _harness(
          child: GateGroupsConfirmationCard(
            skillName: 'Утренний фокус',
            onConfirm: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('$_gateDir/09_groups_confirmation.png'),
      );
    });
  });
}
