import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/routes.dart';
import '../../design/tokens.dart';
import '../../providers/auth_provider.dart';
import '../../ui/components/settings/app_settings_section.dart';
import '../../ui/components/profile/verified_email_badge.dart';
import '../../ui/components/settings/settings_presentation.dart';
import 'settings_change_password_screen.dart';

class SettingsAccountDetailScreen extends StatefulWidget {
  const SettingsAccountDetailScreen({super.key});

  @override
  State<SettingsAccountDetailScreen> createState() =>
      _SettingsAccountDetailScreenState();
}

class _SettingsAccountDetailScreenState extends State<SettingsAccountDetailScreen> {
  static const _notificationsKey = 'notifications_enabled';

  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationsSetting();
  }

  Future<void> _loadNotificationsSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.getBool(_notificationsKey) ?? true;
    });
  }

  Future<void> _setNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, value);
    if (!mounted) return;
    setState(() => _notificationsEnabled = value);
  }

  void _openChangePassword() {
    Navigator.of(context).push(
      PrimeRoute.sharedAxis(builder: (_) => const ChangePasswordScreen()),
    );
  }

  Future<void> _replayOnboarding() async {
    await context.read<AuthProvider>().replayOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return SettingsPageScaffold(
      title: 'Аккаунт',
      subtitle: 'Email, безопасность и уведомления на этом устройстве.',
      children: [
        AppSettingsSection(
          title: 'Данные входа',
          children: [
            if ((user?.email ?? '').isNotEmpty)
              AppSettingsTile(
                icon: Icons.email_outlined,
                title: 'Email',
                subtitle: user!.email,
                trailing: user.emailVerified
                    ? const VerifiedEmailBadge(size: 18)
                    : null,
              ),
            AppSettingsTile(
              icon: Icons.lock_reset_rounded,
              title: 'Сменить пароль',
              subtitle: 'Отдельный экран с проверкой надёжности',
              onTap: _openChangePassword,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSettingsSection(
          title: 'Уведомления',
          footer: const SettingsInfoBanner(
            text: 'Управляет push и локальными напоминаниями на этом устройстве.',
          ),
          children: [
            AppSettingsSwitchTile(
              icon: Icons.notifications_active_outlined,
              title: 'Уведомления',
              subtitle: _notificationsEnabled
                  ? 'Включены для заявок и событий'
                  : 'Отключены на этом устройстве',
              value: _notificationsEnabled,
              onChanged: _setNotificationsEnabled,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSettingsSection(
          title: 'Знакомство с приложением',
          children: [
            AppSettingsTile(
              icon: Icons.auto_stories_outlined,
              title: 'Снова посмотреть знакомство',
              subtitle: 'Показать экраны онбординга',
              onTap: _replayOnboarding,
            ),
          ],
        ),
      ],
    );
  }
}
