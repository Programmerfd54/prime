import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/design/theme/prime_theme.dart';
import 'package:prime/l10n/copy.dart';
import 'package:prime/models/notification.dart';
import 'package:prime/ui/kit/presentation/gate_groups_active_presentation.dart';
import 'package:prime/ui/kit/presentation/gate_groups_presentation.dart';
import 'package:prime/ui/kit/presentation/gate_notifications_presentation.dart';
import 'package:prime/ui/kit/presentation/profile_surfaces.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    theme: PrimeTheme.dark(),
    home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844)),
      child: Scaffold(
        backgroundColor: ProfileSurfaces.canvas,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('V4 functional gate', () {
    testWidgets('groups confirmation fires onConfirm', (tester) async {
      var confirmed = false;
      await tester.pumpWidget(
        _harness(
          GateGroupsConfirmationCard(
            skillName: 'Утренний фокус',
            onConfirm: () => confirmed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppCopy.confirmParticipation));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
    });

    testWidgets('groups searching expand and stop callbacks', (tester) async {
      var expanded = false;
      var stopped = false;
      await tester.pumpWidget(
        _harness(
          GateGroupsPresentation(
            habitName: 'Утренний фокус',
            found: 1,
            total: 6,
            canExpandSearch: true,
            scopeIsRussia: false,
            onExpandSearch: () => expanded = true,
            onStopSearch: () => stopped = true,
            checklist: const [
              GateReadinessItem(
                title: 'Профиль',
                subtitle: 'Заполнен',
                done: true,
              ),
              GateReadinessItem(
                title: 'О себе',
                subtitle: '50 слов',
                done: false,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Расширить'));
      await tester.pumpAndSettle();
      expect(expanded, isTrue);
      await tester.tap(find.text('Остановить'));
      await tester.pumpAndSettle();
      expect(stopped, isTrue);
    });

    testWidgets('notification sheet mark-all and friend accept', (tester) async {
      var markedAll = false;
      PrimeNotification? accepted;
      final notification = PrimeNotification(
        id: 'n1',
        type: PrimeNotificationType.friendRequest,
        title: 'Заявка в друзья',
        body: 'Иван хочет добавить вас',
        createdAt: DateTime(2026, 7, 29),
        read: false,
        payload: {'from_user_id': 'u1'},
      );

      await tester.pumpWidget(
        _harness(
          SizedBox(
            height: 420,
            child: GateNotificationCenterSheet(
              items: [notification],
              unreadCount: 1,
              onMarkAllRead: () => markedAll = true,
              onAcceptFriend: (n) => accepted = n,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Прочитать все'));
      await tester.pumpAndSettle();
      expect(markedAll, isTrue);
      await tester.tap(find.text('Принять'));
      await tester.pumpAndSettle();
      expect(accepted?.id, 'n1');
    });
  });
}
