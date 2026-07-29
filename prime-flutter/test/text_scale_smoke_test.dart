import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/config/theme.dart';
import 'package:prime/design/tokens.dart';
import 'package:prime/l10n/copy.dart';
import 'package:prime/models/skill.dart';
import 'package:prime/ui/components/editorial/app_group_editorial.dart';
import 'package:prime/ui/components/editorial/app_habit_catalog.dart';
import 'package:prime/ui/components/editorial/app_public_profile.dart';
import 'package:prime/ui/components/editorial/app_social_inbox.dart';
import 'package:prime/ui/states/app_empty_state.dart';
import 'package:prime/ui/states/app_error_state.dart';

void main() {
  Future<void> pumpScaled(WidgetTester tester, Widget child) async {
    ThemeBinding.bind(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: child),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('AppEmptyState survives text scale 200%', (tester) async {
    await pumpScaled(
      tester,
      AppEmptyState(
        title: 'Пока нет личных чатов',
        subtitle: 'Найдите друга по никнейму',
        actionLabel: AppCopy.findFriend,
        onAction: () {},
      ),
    );
    expect(find.text('Пока нет личных чатов'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppErrorState survives text scale 200%', (tester) async {
    await pumpScaled(
      tester,
      const AppErrorState(
        message: 'Не удалось загрузить',
        correlationId: 'corr-scale',
      ),
    );
    expect(find.textContaining('corr-scale'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppSocialInboxRow survives text scale 200%', (tester) async {
    await pumpScaled(
      tester,
      const AppSocialInboxRow(
        title: 'Очень длинное имя пользователя для проверки',
        subtitle: 'Последнее сообщение тоже довольно длинное',
        initial: 'О',
        unread: 3,
      ),
    );
    expect(find.textContaining('Очень длинное'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppHabitListRow survives text scale 200%', (tester) async {
    final skill = SkillModel(
      id: 'morning-focus',
      name: 'Утренняя фокусировка',
      description: 'Короткое ежедневное действие',
      icon: 'star',
      category: SkillCategory.official,
      popularity: 1,
    );
    await pumpScaled(
      tester,
      AppHabitListRow(skill: skill, onTap: () {}),
    );
    expect(find.textContaining('Утренняя'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppGroupListRow survives text scale 200%', (tester) async {
    await pumpScaled(
      tester,
      const AppGroupListRow(
        title: 'Утренний фокус',
        statusLabel: 'активна',
        membersCount: 6,
        maxMembers: 6,
        active: true,
      ),
    );
    expect(find.textContaining('Утренний'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppPublicProfileHero survives text scale 200%', (tester) async {
    await pumpScaled(
      tester,
      const AppPublicProfileHero(
        name: 'Анна',
        nickname: 'anna_prime',
        location: 'Москва · 28 лет',
      ),
    );
    expect(find.text('Анна'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
