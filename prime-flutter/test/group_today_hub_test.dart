import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/models/group.dart';
import 'package:prime/models/user.dart';
import 'package:prime/ui/components/editorial/app_group_today_hub.dart';

import 'prime_test_harness.dart';

MemberModel member({
  required String userId,
  required String name,
  required String reportStatus,
  String? checkInKind,
}) {
  return MemberModel(
    id: 'member-$userId',
    userId: userId,
    role: MemberRole.member,
    confirmedParticipation: true,
    acceptedRules: true,
    active: true,
    streak: 2,
    bestStreak: 5,
    reportStatus: reportStatus,
    checkInKind: checkInKind,
    profile: UserPublic(
      id: userId,
      nickname: name.toLowerCase(),
      name: name,
      about: '',
    ),
  );
}

GroupModel activeGroup(List<MemberModel> members) {
  return GroupModel(
    id: 'group-1',
    name: 'Утренний фокус',
    skillId: 'morning-focus',
    status: GroupStatus.active,
    revision: 3,
    isPrivate: true,
    isCrossRegion: false,
    maxMembers: members.length,
    cycleDay: 6,
    membersCount: members.length,
    members: members,
  );
}

void main() {
  testWidgets('today hub exposes one main action and live team statuses',
      (tester) async {
    var reportPressed = 0;
    var checkIn = '';
    MemberModel? supported;
    final group = activeGroup([
      member(
        userId: 'me',
        name: 'Даниил',
        reportStatus: 'not_ready',
        checkInKind: 'starting',
      ),
      member(
        userId: 'friend',
        name: 'Анна',
        reportStatus: 'not_ready',
        checkInKind: 'support',
      ),
      member(
        userId: 'ready',
        name: 'Макс',
        reportStatus: 'ready',
      ),
    ]);

    await tester.pumpWidget(
      primeTestApp(
        size: const Size(390, 1100),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AppGroupTodayHub(
              group: group,
              currentUserId: 'me',
              reportSending: false,
              checkInSending: false,
              onReport: () => reportPressed++,
              onCheckIn: (value) => checkIn = value,
              onSupport: (value) => supported = value,
              onOpenChat: () {},
              onShowProgress: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('День цикла · 6 из 30'), findsOneWidget);
    expect(find.text('Отчёты сегодня · 1 из 3'), findsOneWidget);
    expect(find.text('Даниил · вы'), findsOneWidget);
    expect(find.text('Нужна поддержка'), findsWidgets);
    expect(find.text('Отправить отчёт'), findsOneWidget);

    await tester.tap(find.text('Отправить отчёт'));
    expect(reportPressed, 1);
    await tester.tap(find.text('Выполнил'));
    expect(checkIn, 'done');
    await tester.tap(find.byTooltip('Поддержать'));
    expect(supported?.userId, 'friend');
  });

  testWidgets('reported user gets support CTA until team day is complete',
      (tester) async {
    MemberModel? supported;
    final group = activeGroup([
      member(userId: 'me', name: 'Даниил', reportStatus: 'ready'),
      member(userId: 'friend', name: 'Анна', reportStatus: 'not_ready'),
    ]);

    await tester.pumpWidget(
      primeTestApp(
        size: const Size(390, 1000),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AppGroupTodayHub(
              group: group,
              currentUserId: 'me',
              reportSending: false,
              checkInSending: false,
              onReport: () {},
              onCheckIn: (_) {},
              onSupport: (value) => supported = value,
              onOpenChat: () {},
              onShowProgress: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Поддержать 1 участника'), findsOneWidget);
    await tester.tap(find.text('Поддержать 1 участника'));
    expect(supported?.userId, 'friend');
  });
}
