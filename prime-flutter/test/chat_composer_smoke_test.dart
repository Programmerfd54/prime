import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/config/theme.dart';
import 'package:prime/design/tokens.dart';
import 'package:prime/ui/components/chat/app_chat_composer.dart';

void main() {
  testWidgets('AppChatComposer shows file attachment preview', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: AppChatComposer(
            controller: controller,
            onSend: () {},
            onAttach: () {},
            pending: PendingAttachment(
              bytes: Uint8List.fromList([1, 2, 3, 4]),
              filename: 'notes.pdf',
              mimeType: 'application/pdf',
              isImage: false,
            ),
            onRemovePending: () {},
          ),
        ),
      ),
    );

    expect(find.text('notes.pdf'), findsOneWidget);
    expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
  });

  testWidgets('AppChatComposer send enabled with pending attachment', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var sent = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: AppChatComposer(
            controller: controller,
            onSend: () => sent = true,
            onAttach: () {},
            pending: PendingAttachment(
              bytes: Uint8List.fromList([1]),
              filename: 'doc.pdf',
              mimeType: 'application/pdf',
              isImage: false,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Отправить'));
    await tester.pump();
    expect(sent, isTrue);
  });
}
