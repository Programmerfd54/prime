import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/design/theme/prime_theme.dart';
import 'package:prime/models/group.dart';
import 'package:prime/ui/kit/presentation/gate_groups_presentation.dart';

void main() {
  testWidgets('GateGroupsPresentation shows team slots row', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: PrimeTheme.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: GateGroupsPresentation(
              habitName: 'Утренняя зарядка',
              found: 2,
              total: 6,
              status: WaitingRoomStatus(
                inQueue: true,
                peopleWaiting: 2,
                needed: 6,
                slots: const [
                  WaitingRoomSlot(letter: 'A'),
                  WaitingRoomSlot(letter: 'B'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Слоты команды'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });
}
