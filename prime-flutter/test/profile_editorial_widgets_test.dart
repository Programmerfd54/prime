import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/config/theme.dart';
import 'package:prime/ui/kit/presentation/profile_editorial_widgets.dart';
import 'package:prime/ui/kit/presentation/profile_utils.dart';
import 'package:prime/ui/kit/presentation/profile_view_model.dart';
import 'package:prime/models/user.dart';

void main() {
  test('sanitizeProfileBio removes lorem ipsum', () {
    expect(
      sanitizeProfileBio('Lorem ipsum dolor sit amet'),
      isEmpty,
    );
    expect(sanitizeProfileBio('  Реальный текст  '), 'Реальный текст');
  });

  test('PublicProfileProjection respects privacy flags', () {
    final profile = UserPublic(
      id: '1',
      nickname: 'alex',
      name: 'Alex',
      about: 'Привет',
      age: 28,
      regionName: 'Москва',
      privacySettings: {
        'show_bio': false,
        'show_age': false,
        'show_region': false,
        'show_habits': false,
        'show_streak': false,
        'show_achievements': false,
        'show_groups': false,
      },
    );
    final vm = PublicProfileProjection.from(profile: profile);
    expect(vm.isRestricted, isTrue);
    expect(vm.about, isNull);
    expect(vm.metrics, isEmpty);
  });

  testWidgets('ProfileHeroCard renders name and tags', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileHeroCard(
              displayName: 'Daniil',
              subtitle: '@daniil · Москва',
              tags: profileHabitTagsFromNames(['Фокус', 'Чтение']),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Daniil'), findsOneWidget);
    expect(find.text('Фокус'), findsOneWidget);
    expect(find.text('Чтение'), findsOneWidget);
  });

  testWidgets('ProfileMetricPillsRow shows four labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ProfileMetricPillsRow(
            metrics: const [
              ProfileMetricPill(
                label: 'Дней подряд',
                value: '3 дн.',
                variant: ProfileMetricPillVariant.gold,
              ),
              ProfileMetricPill(
                label: 'Праймы',
                value: '12',
                variant: ProfileMetricPillVariant.charcoal,
              ),
              ProfileMetricPill(
                label: 'Циклы',
                value: '5/30',
                variant: ProfileMetricPillVariant.hatched,
              ),
              ProfileMetricPill(
                label: 'Стаб. 7д',
                value: '71%',
                variant: ProfileMetricPillVariant.glass,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Дней подряд'), findsOneWidget);
    expect(find.text('Праймы'), findsOneWidget);
    expect(find.text('Циклы'), findsOneWidget);
    expect(find.text('Стаб. 7д'), findsOneWidget);
    expect(find.text('3 дн.'), findsOneWidget);
  });
}
