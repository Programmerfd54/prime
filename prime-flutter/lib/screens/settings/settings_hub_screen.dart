import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/failure_mapper.dart';
import '../../core/profile/privacy_presets.dart';
import '../../core/profile/theme_mode_controller.dart';
import '../../data/api_client.dart';
import '../../design/routes.dart';
import '../../design/tokens.dart';
import '../../design/visuals/ambient_and_progress.dart';
import '../../providers/auth_provider.dart';
import '../../ui/components/app_dialog.dart';
import '../../ui/components/app_header.dart';
import '../../ui/components/app_scaffold.dart';
import '../../ui/components/app_snackbar.dart';
import '../../ui/components/settings/app_settings_section.dart';
import '../../ui/components/settings/settings_presentation.dart';
import '../../ui/kit/tokens/kit_surfaces.dart';
import 'settings_account_detail_screen.dart';
import 'settings_appearance_screen.dart';
import 'settings_privacy_screen.dart';
import 'settings_ritual_screen.dart';
import 'settings_support_screen.dart';

/// Settings hub — category navigation with live summaries.
class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final themeCtrl = context.watch<ThemeModeController>();
    final themeLabel = switch (themeCtrl.mode) {
      ThemeMode.light => 'Светлая',
      ThemeMode.dark => 'Тёмная',
      ThemeMode.system => 'Как в системе',
    };

    return AppScaffold(
      appBar: buildAppBackBar(context, title: 'Настройки'),
      body: AmbientCanvas(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            const SettingsHubHeader(),
            const SizedBox(height: AppSpacing.lg),
            SettingsUserStrip(
              name: user?.name ?? user?.nickname ?? '',
              email: user?.email,
              photoUrl: user?.photoUrl,
            ),
            const SizedBox(height: AppSpacing.lg),
            SettingsHubCard(
              icon: Icons.person_outline_rounded,
              title: 'Аккаунт',
              subtitle: _accountSummary(user?.email),
              onTap: () => Navigator.of(context).push(
                PrimeRoute.sharedAxis(
                  builder: (_) => const SettingsAccountDetailScreen(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SettingsHubCard(
              icon: Icons.palette_outlined,
              title: 'Внешний вид',
              subtitle: themeLabel,
              accent: KitAccent.blue,
              onTap: () => Navigator.of(context).push(
                PrimeRoute.sharedAxis(
                  builder: (_) => const SettingsAppearanceScreen(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SettingsHubCard(
              icon: Icons.shield_outlined,
              title: 'Приватность профиля',
              subtitle: _privacySummary(user?.privacySettings ?? {}),
              accent: KitAccent.mint,
              onTap: () => Navigator.of(context).push(
                PrimeRoute.sharedAxis(
                  builder: (_) => const SettingsPrivacyScreen(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SettingsHubCard(
              icon: Icons.schedule_rounded,
              title: 'Ритуал',
              subtitle: 'Окно для ежедневного действия',
              accent: KitAccent.amber,
              onTap: () => Navigator.of(context).push(
                PrimeRoute.sharedAxis(
                  builder: (_) => const SettingsRitualScreen(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SettingsHubCard(
              icon: Icons.support_agent_outlined,
              title: 'Поддержка',
              subtitle: 'Почта и чат техподдержки',
              accent: KitAccent.neutral,
              onTap: () => Navigator.of(context).push(
                PrimeRoute.sharedAxis(
                  builder: (_) => const SettingsSupportScreen(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSettingsSection(
              title: 'Сессия',
              children: [
                AppSettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Выйти из аккаунта',
                  subtitle: 'Данные на сервере сохранятся',
                  onTap: () => _logout(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSettingsSection(
              title: 'Опасная зона',
              children: [
                AppSettingsTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Удалить аккаунт',
                  subtitle: 'Деактивирует профиль на сервере',
                  destructive: true,
                  onTap: () => _deleteAccount(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _accountSummary(String? email) {
    if (email != null && email.isNotEmpty) return email;
    return 'Пароль, уведомления, знакомство';
  }

  String _privacySummary(Map<String, bool> settings) {
    final preset = detectPrivacyPreset(settings);
    if (preset != null) return privacyPresetLabels[preset]!;
    return 'Настроено вручную';
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Выйти из аккаунта?',
      body:
          'Вы выйдете из аккаунта на этом устройстве. Данные на сервере останутся.',
      cancelLabel: 'Остаться',
      confirmLabel: 'Выйти',
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<AuthProvider>().logout();
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Удалить аккаунт?',
      body:
          'Аккаунт будет деактивирован, email освобождён. Это действие необратимо.',
      cancelLabel: 'Отмена',
      confirmLabel: 'Удалить',
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<ApiClient>().deleteAccount();
      if (!context.mounted) return;
      await context.read<AuthProvider>().logout();
    } catch (e) {
      if (context.mounted) {
        showAppSnackBar(context, FailureMapper.from(e).message);
      }
    }
  }
}
