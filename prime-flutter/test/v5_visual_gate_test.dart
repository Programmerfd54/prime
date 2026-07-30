import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/home/home_state.dart';
import 'package:prime/design/prime/prime_toast_overlay.dart';
import 'package:prime/design/theme/prime_theme.dart';
import 'package:prime/models/group.dart';
import 'package:prime/ui/components/chat/app_chat_shell.dart';
import 'package:prime/ui/components/chat/app_chat_composer.dart';
import 'package:prime/ui/kit/components/prime_action_menu.dart';
import 'package:prime/ui/kit/presentation/gate_groups_active_presentation.dart';
import 'package:prime/ui/kit/presentation/gate_groups_presentation.dart';
import 'package:prime/ui/kit/presentation/home_waiting_companion.dart';

const _gateDir = 'goldens/v5_visual_gate';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) => MaterialApp(
        theme: PrimeTheme.dark(),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  testWidgets('V5 waiting companion golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(
        const HomeWaitingCompanion(
          skillName: 'Утренняя зарядка',
          peopleWaiting: 2,
          needed: 6,
          regionSearching: 14,
          skillSearching: 5,
          onlineInPool: 9,
          regionLabel: 'Москве',
          showFriendsCta: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HomeWaitingCompanion),
      matchesGoldenFile('$_gateDir/home_waiting_companion.png'),
    );
  });

  testWidgets('V5 groups search golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(
        GateGroupsPresentation(
          habitName: 'Утренняя зарядка',
          found: 2,
          total: 6,
          regionSearching: 14,
          skillSearching: 5,
          onlineInPool: 9,
          scopeIsRussia: false,
          canExpandSearch: true,
          status: WaitingRoomStatus(
            inQueue: true,
            peopleWaiting: 2,
            needed: 6,
            canExpandSearch: true,
            regionName: 'Москва',
          ),
          checklist: gateReadinessFromProfile(aboutReady: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GateGroupsPresentation),
      matchesGoldenFile('$_gateDir/groups_search_v5.png'),
    );
  });

  testWidgets('V5 confirmation card golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(
        GateGroupsConfirmationCard(
          confirmedCount: 4,
          total: 6,
          skillName: 'Утренний фокус',
          onConfirm: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GateGroupsConfirmationCard),
      matchesGoldenFile('$_gateDir/groups_confirmation_v5.png'),
    );
  });

  testWidgets('V5 chat shell golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PrimeTheme.dark(),
        home: AppChatShell(
          appBar: AppBar(title: const Text('Команда')),
          messageArea: const Center(child: Text('Сообщения')),
          composer: AppChatComposer(
            controller: ctrl,
            onSend: () {},
            onAttach: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppChatShell),
      matchesGoldenFile('$_gateDir/chat_shell_v5.png'),
    );
  });

  test('PrimeToast variants are defined', () {
    expect(PrimeToastVariant.values.length, 5);
    expect(PrimeActionMenuItem(label: 'Test', onTap: () {}).label, 'Test');
  });

  test('searching home state uses hero only without duplicate companion', () {
    final state = HomeStateResolver.resolve(
      const HomeStateInput(
        hasActiveGroups: false,
        reportedToday: false,
        hasHistory: false,
        searching: true,
        peopleWaiting: 2,
        needed: 6,
        queueSkillName: 'Бег',
      ),
    );
    expect(state.phase, HomePhase.searchingTeam);
    expect(state.showWaitingCompanion, isFalse);
    expect(state.hero.actionLabel, 'Открыть группы');
  });
}
