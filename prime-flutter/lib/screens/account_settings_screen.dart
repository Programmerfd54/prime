import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/errors/failure_mapper.dart';
import '../core/profile/privacy_presets.dart';
import '../core/profile/privacy_settings.dart';
import '../core/profile/theme_mode_controller.dart';
import '../core/security/password_strength.dart';
import '../data/api_client.dart';
import '../design/glass.dart';
import '../design/haptics.dart';
import '../design/routes.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../ui/components/app_chip.dart';
import '../providers/auth_provider.dart';
import '../ui/components/app_dialog.dart';
import '../ui/components/app_header.dart';
import '../ui/components/app_password_field.dart';
import '../ui/components/app_primary_button.dart';
import '../ui/components/app_scaffold.dart';
import '../ui/components/app_snackbar.dart';
import '../ui/components/settings/app_settings_section.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  static const _notificationsKey = 'notifications_enabled';
  static const _supportEmail = 'support@inpr1me.ru';
  static const _supportChatUrl = 'https://t.me/inpr1me_support';

  bool _notificationsEnabled = true;
  bool _privacySaving = false;
  bool _manualPrivacyExpanded = false;
  String? _actionWindow;
  bool _actionWindowLoading = true;

  static const _privacyLabels = <String, String>{
    'show_bio': 'О себе',
    'show_age': 'Возраст',
    'show_region': 'Регион',
    'show_streak': 'Серия и успешные дни',
    'show_achievements': 'Праймы и достижения',
    'show_habits': 'Активные привычки',
    'show_groups': 'Группы',
  };

  @override
  void initState() {
    super.initState();
    _loadNotificationsSetting();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadActionWindow());
  }

  Future<void> _loadActionWindow() async {
    try {
      final prefs = await context.read<ApiClient>().getPreferences();
      if (!mounted) return;
      setState(() {
        _actionWindow = prefs['preferred_action_window'] as String?;
        _actionWindowLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _actionWindowLoading = false);
    }
  }

  Future<void> _saveActionWindow(String? value) async {
    if (value == null || value.isEmpty) return;
    setState(() => _actionWindow = value);
    try {
      await context.read<ApiClient>().updatePreferences({
        'preferred_action_window': value,
      });
    } catch (e) {
      if (mounted) _showMessage(FailureMapper.from(e).message);
    }
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

  Future<void> _applyPrivacyPreset(PrivacyPreset preset) async {
    if (_privacySaving) return;
    await _updatePrivacyMap(privacyPresetValues(preset));
  }

  Future<void> _updatePrivacyMap(Map<String, bool> next) async {
    if (_privacySaving) return;
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    setState(() => _privacySaving = true);
    try {
      await auth.api.updateMe({'privacy_settings': next});
      await auth.refreshUser();
    } catch (e) {
      if (mounted) {
        _showMessage(FailureMapper.from(e).message);
      }
    } finally {
      if (mounted) setState(() => _privacySaving = false);
    }
  }

  Future<void> _updatePrivacy(String key, bool value) async {
    if (_privacySaving) return;
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;
    final next = Map<String, bool>.from(user.privacySettings);
    next[key] = value;
    await _updatePrivacyMap(next);
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Удалить аккаунт?',
      body:
          'Аккаунт будет деактивирован, email освобождён. Это действие необратимо.',
      cancelLabel: 'Отмена',
      confirmLabel: 'Удалить',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<ApiClient>().deleteAccount();
      if (!mounted) return;
      await context.read<AuthProvider>().logout();
    } catch (e) {
      if (mounted) _showMessage(FailureMapper.from(e).message);
    }
  }

  void _openChangePassword() {
    Navigator.of(context).push(
      PrimeRoute.sharedAxis(builder: (_) => const ChangePasswordScreen()),
    );
  }

  void _showMessage(String message) {
    showAppSnackBar(context, message);
  }

  Future<void> _openUri(Uri uri, String fallbackText) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) return;
    await Clipboard.setData(ClipboardData(text: fallbackText));
    _showMessage('Не удалось открыть ссылку. Скопировал в буфер.');
  }

  Future<void> _openSupportEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': 'ПРАЙМ: обращение в поддержку',
        'body': 'Здравствуйте! Опишите проблему здесь:',
      },
    );
    await _openUri(uri, _supportEmail);
  }

  Future<void> _openSupportChat() async {
    await _openUri(Uri.parse(_supportChatUrl), _supportChatUrl);
  }

  Future<void> _copySupportChat() async {
    await Clipboard.setData(const ClipboardData(text: _supportChatUrl));
    if (!mounted) return;
    _showMessage('Ссылка на поддержку скопирована');
  }

  Future<void> _replayOnboarding() async {
    await context.read<AuthProvider>().replayOnboarding();
  }

  Future<void> _logout() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Выйти из аккаунта?',
      body: 'Вы выйдете из аккаунта на этом устройстве. Данные на сервере останутся.',
      cancelLabel: 'Остаться',
      confirmLabel: 'Выйти',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    await context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return AppScaffold(
      appBar: buildAppBackBar(context, title: 'Настройки'),
      body: AmbientCanvas(
        child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          AppSettingsSection(
            title: 'Аккаунт',
            children: [
              if ((user?.email ?? '').isNotEmpty)
                AppSettingsTile(
                  icon: Icons.email_outlined,
                  title: 'Email',
                  subtitle: user!.email,
                ),
              AppSettingsSwitchTile(
                icon: Icons.notifications_active_outlined,
                title: 'Уведомления',
                subtitle: _notificationsEnabled
                    ? 'Включены для заявок и событий'
                    : 'Отключены на этом устройстве',
                value: _notificationsEnabled,
                onChanged: _setNotificationsEnabled,
              ),
              AppSettingsTile(
                icon: Icons.lock_reset,
                title: 'Сменить пароль',
                subtitle: 'Отдельный экран с проверкой',
                onTap: _openChangePassword,
              ),
              AppSettingsTile(
                icon: Icons.auto_stories_outlined,
                title: 'Снова посмотреть знакомство',
                subtitle: 'Показать экраны онбординга',
                onTap: _replayOnboarding,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSettingsSection(
            title: 'Внешний вид',
            children: [
              Builder(
                builder: (context) {
                  final themeCtrl = context.watch<ThemeModeController>();
                  final label = switch (themeCtrl.mode) {
                    ThemeMode.light => 'Светлая',
                    ThemeMode.dark => 'Тёмная',
                    ThemeMode.system => 'Как в системе',
                  };
                  return AppSettingsTile(
                    icon: Icons.brightness_6_outlined,
                    title: 'Тема',
                    subtitle: label,
                    onTap: () async {
                      final next = await showModalBottomSheet<ThemeMode>(
                        context: context,
                        builder: (ctx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.dark_mode_outlined),
                                title: const Text('Тёмная'),
                                trailing: themeCtrl.mode == ThemeMode.dark
                                    ? Icon(Icons.check, color: AppColors.primary)
                                    : null,
                                onTap: () =>
                                    Navigator.pop(ctx, ThemeMode.dark),
                              ),
                              ListTile(
                                leading: const Icon(Icons.light_mode_outlined),
                                title: const Text('Светлая'),
                                trailing: themeCtrl.mode == ThemeMode.light
                                    ? Icon(Icons.check, color: AppColors.primary)
                                    : null,
                                onTap: () =>
                                    Navigator.pop(ctx, ThemeMode.light),
                              ),
                              ListTile(
                                leading: const Icon(Icons.settings_suggest_outlined),
                                title: const Text('Как в системе'),
                                trailing: themeCtrl.mode == ThemeMode.system
                                    ? Icon(Icons.check, color: AppColors.primary)
                                    : null,
                                onTap: () =>
                                    Navigator.pop(ctx, ThemeMode.system),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (next != null) await themeCtrl.setMode(next);
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSettingsSection(
            title: 'Приватность профиля',
            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _privacySaving
                      ? 'Сохраняем…'
                      : 'Кто видит что в публичном профиле',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppSpacing.sm),
                GlassContainer(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  fillOpacity: 0.04,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Превью публичного профиля',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primarySoft,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        () {
                          final visible = [
                            if (user?.privacySettings['show_bio'] ?? true)
                              'О себе',
                            if (user?.privacySettings['show_age'] ?? true)
                              'Возраст',
                            if (user?.privacySettings['show_region'] ?? true)
                              'Регион',
                            if (user?.privacySettings['show_streak'] ?? true)
                              'Серии',
                            if (user?.privacySettings['show_achievements'] ??
                                true)
                              'Праймы',
                          ];
                          return visible.isEmpty
                              ? 'Ничего не видно'
                              : visible.join(' · ');
                        }(),
                        style: AppTypography.bodySecondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            children: [
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final preset in PrivacyPreset.values)
                    AppChip(
                      label: privacyPresetLabels[preset]!,
                      selected: detectPrivacyPreset(
                            user?.privacySettings ?? {},
                          ) ==
                          preset,
                      onTap: _privacySaving
                          ? null
                          : () {
                              AppHaptics.selection();
                              _applyPrivacyPreset(preset);
                            },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: _manualPrivacyExpanded,
                  onExpansionChanged: (v) =>
                      setState(() => _manualPrivacyExpanded = v),
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    'Настроить вручную',
                    style: AppTypography.body,
                  ),
                  children: [
                    for (final entry in _privacyLabels.entries)
                      AppSettingsSwitchTile(
                        icon: Icons.visibility_outlined,
                        title: entry.value,
                        subtitle: 'Видно в публичном профиле',
                        value: user?.privacySettings[entry.key] ??
                            defaultPrivacySettings[entry.key] ??
                            true,
                        onChanged: (value) {
                          if (_privacySaving) return;
                          _updatePrivacy(entry.key, value);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSettingsSection(
            title: 'Ритуал',
            footer: const Text(
              'Окно, когда вам удобнее делать ежедневное действие.',
              style: AppTypography.caption,
            ),
            children: [
              if (_actionWindowLoading)
                const AppSettingsTile(
                  icon: Icons.schedule,
                  title: 'Загрузка…',
                )
              else
                AppSettingsTile(
                  icon: Icons.schedule,
                  title: 'Предпочитаемое окно',
                  subtitle: _actionWindow ?? 'Не задано',
                  onTap: () async {
                    final picked = await showDialog<String>(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        title: const Text('Окно действия'),
                        children: [
                          for (final option in [
                            '07:00-09:00',
                            '12:00-14:00',
                            '18:00-20:00',
                            '21:00-23:00',
                          ])
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(ctx, option),
                              child: Text(option),
                            ),
                        ],
                      ),
                    );
                    if (picked != null) await _saveActionWindow(picked);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSettingsSection(
            title: 'Поддержка',
            children: [
              AppSettingsTile(
                icon: Icons.alternate_email,
                title: 'Почта техподдержки',
                subtitle: _supportEmail,
                onTap: _openSupportEmail,
              ),
              AppSettingsTile(
                icon: Icons.bug_report_outlined,
                title: 'Написать о проблеме',
                subtitle: 'Откроем чат поддержки',
                onTap: _openSupportChat,
              ),
              AppSettingsTile(
                icon: Icons.copy,
                title: 'Скопировать чат поддержки',
                subtitle: _supportChatUrl,
                onTap: _copySupportChat,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSettingsSection(
            title: 'Сессия',
            children: [
              AppSettingsTile(
                icon: Icons.logout,
                title: 'Выйти из аккаунта',
                subtitle: 'Данные на сервере сохранятся',
                onTap: _logout,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSettingsSection(
            title: 'Опасная зона',
            children: [
              AppSettingsTile(
                icon: Icons.delete_outline,
                title: 'Удалить аккаунт',
                subtitle: 'Деактивирует профиль на сервере',
                destructive: true,
                onTap: _deleteAccount,
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    return PasswordStrengthAnalyzer.validateForRegister(value);
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<ApiClient>().changePassword(
            _currentPassword.text,
            _newPassword.text,
          );
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      if (!mounted) return;
      showAppSnackBar(context, 'Пароль изменён');
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: buildAppBackBar(context, title: 'Смена пароля'),
      body: AmbientCanvas(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            AppSettingsSection(
              title: 'Новый пароль',
              footer: const Text(
                'Пароль должен содержать минимум 8 символов, букву и цифру.',
                style: AppTypography.caption,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.disabled,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppPasswordField(
                          controller: _currentPassword,
                          label: 'Текущий пароль',
                          textInputAction: TextInputAction.next,
                          validator: (value) => value == null || value.isEmpty
                              ? 'Введите текущий пароль'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppPasswordField(
                          controller: _newPassword,
                          label: 'Новый пароль',
                          textInputAction: TextInputAction.next,
                          showRequirements: true,
                          validator: _validatePassword,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppPasswordField(
                          controller: _confirmPassword,
                          label: 'Повторите новый пароль',
                          textInputAction: TextInputAction.done,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Повторите новый пароль';
                            }
                            if (value != _newPassword.text) {
                              return 'Пароли не совпадают';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppPrimaryButton(
                          label: 'Сохранить пароль',
                          icon: Icons.lock_reset,
                          loading: _saving,
                          onPressed: _saving ? null : _changePassword,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
