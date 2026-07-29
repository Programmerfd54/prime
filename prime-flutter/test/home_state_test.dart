import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/home/home_state.dart';
import 'package:prime/models/group.dart';

void main() {
  const base = HomeStateInput(
    hasActiveGroups: false,
    reportedToday: false,
    hasHistory: false,
    searching: false,
  );

  test('team matched wins over searching and active', () {
    final state = HomeStateResolver.resolve(
      const HomeStateInput(
        hasActiveGroups: true,
        reportedToday: false,
        hasHistory: true,
        searching: true,
        matchedGroupId: 'g1',
        peopleWaiting: 3,
      ),
    );
    expect(state.phase, HomePhase.teamMatched);
    expect(state.focusGroupId, 'g1');
  });

  test('searching when in queue without match', () {
    final state = HomeStateResolver.resolve(
      const HomeStateInput(
        hasActiveGroups: false,
        reportedToday: false,
        hasHistory: false,
        searching: true,
        peopleWaiting: 2,
        needed: 6,
        queueSkillName: 'Чтение',
      ),
    );
    expect(state.phase, HomePhase.searchingTeam);
    expect(state.hero.progressLabel, '2/6');
  });

  test('introduction before active report due', () {
    final state = HomeStateResolver.resolve(
      HomeStateInput(
        hasActiveGroups: false,
        reportedToday: false,
        hasHistory: false,
        searching: false,
        pendingGroup: const HomePendingGroup(
          groupId: 'intro-1',
          skillName: 'Фокус',
          status: GroupStatus.introduction,
        ),
      ),
    );
    expect(state.phase, HomePhase.groupIntroduction);
    expect(state.focusGroupId, 'intro-1');
  });

  test('rules pending after introduction cleared', () {
    final state = HomeStateResolver.resolve(
      HomeStateInput(
        hasActiveGroups: false,
        reportedToday: false,
        hasHistory: false,
        searching: false,
        pendingGroup: const HomePendingGroup(
          groupId: 'rules-1',
          skillName: 'Фокус',
          status: GroupStatus.rulesPending,
        ),
      ),
    );
    expect(state.phase, HomePhase.groupRulesPending);
  });

  test('report due vs complete for active groups', () {
    final due = HomeStateResolver.resolve(
      const HomeStateInput(
        hasActiveGroups: true,
        reportedToday: false,
        hasHistory: true,
        searching: false,
        streak: 5,
        primarySkillName: 'Чтение',
      ),
    );
    expect(due.phase, HomePhase.reportDue);
    expect(due.showReportComposer, isTrue);

    final done = HomeStateResolver.resolve(
      const HomeStateInput(
        hasActiveGroups: true,
        reportedToday: true,
        hasHistory: true,
        searching: false,
        streak: 5,
      ),
    );
    expect(done.phase, HomePhase.reportComplete);
    expect(done.showReportComposer, isTrue);
  });

  test('report complete waiting for team shows nudge', () {
    final state = HomeStateResolver.resolve(
      const HomeStateInput(
        hasActiveGroups: true,
        reportedToday: true,
        hasHistory: true,
        searching: false,
        streak: 5,
        teamDayStatus: 'pending',
        teamReady: 4,
        teamTotal: 6,
        waitingNames: ['Аня', 'Игорь'],
      ),
    );
    expect(state.phase, HomePhase.reportComplete);
    expect(state.hero.title, 'Отчёт принят');
    expect(state.hero.actionLabel, isNotNull);
    expect(state.hero.progressLabel, '4/6');
  });

  test('report complete when team day closed', () {
    final state = HomeStateResolver.resolve(
      const HomeStateInput(
        hasActiveGroups: true,
        reportedToday: true,
        hasHistory: true,
        searching: false,
        streak: 5,
        teamDayStatus: 'complete',
        teamReady: 6,
        teamTotal: 6,
      ),
    );
    expect(state.phase, HomePhase.reportComplete);
    expect(state.hero.title, contains('закрыт'));
    expect(state.hero.actionLabel, isNull);
  });

  test('returning user when history but no active group', () {
    final state = HomeStateResolver.resolve(
      const HomeStateInput(
        hasActiveGroups: false,
        reportedToday: false,
        hasHistory: true,
        searching: false,
        streak: 12,
      ),
    );
    expect(state.phase, HomePhase.returningUser);
    expect(state.showCalendar, isTrue);
    expect(state.showJourneyStrip, isFalse);
  });

  test('new user default', () {
    final state = HomeStateResolver.resolve(base);
    expect(state.phase, HomePhase.newUser);
    expect(state.showJourneyStrip, isTrue);
    expect(state.hero.actionLabel, isNotNull);
  });
}
