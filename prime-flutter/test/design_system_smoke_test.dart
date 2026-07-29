import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/config/theme.dart';
import 'package:prime/design/tokens.dart';
import 'package:prime/design/typography.dart';
import 'package:prime/ui/components/app_bottom_navigation.dart';
import 'package:prime/ui/components/app_primary_button.dart';
import 'package:prime/ui/components/app_secondary_button.dart';
import 'package:prime/ui/components/app_text_field.dart';

void main() {
  testWidgets('core DS components render under AppTheme.dark', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Column(
            children: [
              Text('ПРАЙМ', style: AppTypography.largeTitle),
              AppTextField(controller: controller, label: 'Email'),
              AppPrimaryButton(label: 'Продолжить', onPressed: () {}),
              AppSecondaryButton(label: 'Отмена', onPressed: () {}),
            ],
          ),
          bottomNavigationBar: AppBottomNavigation(
            selectedIndex: 2,
            onSelected: (_) {},
            items: const [
              AppBottomNavItem(
                icon: Icons.spa_outlined,
                selectedIcon: Icons.spa,
                label: 'Привычки',
              ),
              AppBottomNavItem(
                icon: Icons.groups_outlined,
                selectedIcon: Icons.groups,
                label: 'Группы',
              ),
              AppBottomNavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: 'Главная',
              ),
              AppBottomNavItem(
                icon: Icons.chat_bubble_outline,
                selectedIcon: Icons.chat_bubble,
                label: 'Чаты',
              ),
              AppBottomNavItem(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                label: 'Профиль',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('ПРАЙМ'), findsOneWidget);
    expect(find.text('Продолжить'), findsOneWidget);
    expect(find.text('Главная'), findsNothing);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(AppColors.primary, const Color(0xFF8B5CF6));
    expect(AppSpacing.bottomNavClearance, 96);
    expect(AppRadius.md, 16);
  });
}
