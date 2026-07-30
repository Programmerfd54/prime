import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/profile/theme_mode_controller.dart';
import '../../design/theme/prime_theme_context.dart';
import '../../design/tokens.dart';
import '../../ui/components/settings/app_settings_section.dart';
import '../../ui/components/settings/settings_presentation.dart';

class SettingsAppearanceScreen extends StatelessWidget {
  const SettingsAppearanceScreen({super.key});

  static const _options = [
    ThemeMode.dark,
    ThemeMode.light,
    ThemeMode.system,
  ];

  static String _label(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => 'Тёмная',
        ThemeMode.light => 'Светлая',
        ThemeMode.system => 'Как в системе',
      };

  static IconData _icon(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => Icons.dark_mode_outlined,
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.system => Icons.settings_suggest_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final themeCtrl = context.watch<ThemeModeController>();
    final p = context.prime;

    return SettingsPageScaffold(
      title: 'Внешний вид',
      subtitle: 'Выберите тему интерфейса — применится сразу.',
      children: [
        AppSettingsSection(
          title: 'Тема',
          footer: const SettingsInfoBanner(
            text: '«Как в системе» следует настройкам iOS или Android.',
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SettingsSegmentedControl<ThemeMode>(
                options: _options,
                selected: themeCtrl.mode,
                labelBuilder: _label,
                onSelected: themeCtrl.setMode,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSettingsSection(
          title: 'Варианты',
          children: [
            for (final mode in _options)
              AppSettingsTile(
                icon: _icon(mode),
                title: _label(mode),
                subtitle: themeCtrl.mode == mode ? 'Сейчас активна' : null,
                trailing: themeCtrl.mode == mode
                    ? Icon(Icons.check_circle_rounded, color: p.brand, size: 22)
                    : null,
                onTap: () => themeCtrl.setMode(mode),
              ),
          ],
        ),
      ],
    );
  }
}
