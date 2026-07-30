import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/failure_mapper.dart';
import '../../data/api_client.dart';
import '../../design/tokens.dart';
import '../../ui/components/app_snackbar.dart';
import '../../ui/components/settings/app_settings_section.dart';
import '../../ui/components/settings/settings_presentation.dart';

class SettingsRitualScreen extends StatefulWidget {
  const SettingsRitualScreen({super.key});

  @override
  State<SettingsRitualScreen> createState() => _SettingsRitualScreenState();
}

class _SettingsRitualScreenState extends State<SettingsRitualScreen> {
  static const _windows = [
    '07:00-09:00',
    '12:00-14:00',
    '18:00-20:00',
    '21:00-23:00',
  ];

  String? _actionWindow;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadActionWindow();
  }

  Future<void> _loadActionWindow() async {
    try {
      final prefs = await context.read<ApiClient>().getPreferences();
      if (!mounted) return;
      setState(() {
        _actionWindow = prefs['preferred_action_window'] as String?;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveActionWindow(String value) async {
    setState(() {
      _actionWindow = value;
      _saving = true;
    });
    try {
      await context.read<ApiClient>().updatePreferences({
        'preferred_action_window': value,
      });
      if (mounted) showAppSnackBar(context, 'Окно действия сохранено');
    } catch (e) {
      if (mounted) showAppSnackBar(context, FailureMapper.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: 'Ритуал',
      subtitle: 'Когда вам удобнее делать ежедневное действие — это помогает подбору команды.',
      children: [
        AppSettingsSection(
          title: 'Предпочитаемое окно',
          footer: const SettingsInfoBanner(
            text: 'Мы учитываем окно при подборе людей с похожим ритмом дня.',
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _loading
                  ? const AppSettingsTile(
                      icon: Icons.schedule,
                      title: 'Загрузка…',
                    )
                  : SettingsChoiceChips(
                      options: _windows,
                      selected: _actionWindow,
                      enabled: !_saving,
                      onSelected: _saveActionWindow,
                    ),
            ),
          ],
        ),
      ],
    );
  }
}
