import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/design/theme/prime_theme.dart';
import 'package:prime/design/theme/prime_colors.dart';
import 'package:prime/design/tokens.dart';
import 'package:prime/design/visuals/habit_art.dart';
import 'package:prime/ui/components/editorial/app_hero_module.dart';
import 'package:prime/ui/components/app_primary_button.dart';
import 'package:prime/ui/kit/components/prime_content_card.dart';
import 'package:prime/ui/kit/tokens/kit_typography.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapLight(Widget child) {
    ThemeBinding.bind(Brightness.light);
    final theme = PrimeTheme.light();
    return MediaQuery(
      data: const MediaQueryData(size: Size(390, 520), disableAnimations: true),
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          backgroundColor: theme.extension<PrimeColors>()!.canvas,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('light theme: hero module golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrapLight(
        const AppHeroModule(
          title: 'Сегодняшний шаг',
          body: 'Короткое действие — держит ритм',
          artKind: HabitArtKind.focus,
          badge: 'День 3 из 30',
          actionLabel: 'Отметить',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/light_hero_module.png'),
    );
  });

  testWidgets('light theme: content card golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrapLight(
        PrimeContentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Настройки', style: KitTypography.cardTitle),
              const SizedBox(height: 8),
              Text(
                'Секции и переключатели на светлой поверхности.',
                style: KitTypography.bodySecondary,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PrimeContentCard),
      matchesGoldenFile('goldens/light_content_card.png'),
    );
  });

  testWidgets('light theme: primary button renders', (tester) async {
    await tester.pumpWidget(
      wrapLight(
        AppPrimaryButton(
          label: 'Найти команду',
          onPressed: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Найти команду'), findsOneWidget);
    expect(Theme.of(tester.element(find.text('Найти команду'))).brightness,
        Brightness.light);
  });

  testWidgets('dark and light canvases differ', (tester) async {
    ThemeBinding.bind(Brightness.dark);
    final dark = AppColors.background;
    ThemeBinding.bind(Brightness.light);
    final light = AppColors.background;
    expect(dark, isNot(equals(light)));
    expect(light, const Color(0xFFF8F7FA));
  });
}
