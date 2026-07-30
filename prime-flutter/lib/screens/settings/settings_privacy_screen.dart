import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/failure_mapper.dart';
import '../../core/profile/privacy_presets.dart';
import '../../core/profile/privacy_settings.dart';
import '../../design/haptics.dart';
import '../../design/theme/prime_theme_context.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../providers/auth_provider.dart';
import '../../ui/components/app_snackbar.dart';
import '../../ui/components/settings/app_settings_section.dart';
import '../../ui/components/settings/settings_presentation.dart';
import '../../ui/kit/components/prime_content_card.dart';

class SettingsPrivacyScreen extends StatefulWidget {
  const SettingsPrivacyScreen({super.key});

  @override
  State<SettingsPrivacyScreen> createState() => _SettingsPrivacyScreenState();
}

class _SettingsPrivacyScreenState extends State<SettingsPrivacyScreen> {
  bool _privacySaving = false;
  bool _manualExpanded = false;

  static const _privacyLabels = <String, String>{
    'show_bio': 'О себе',
    'show_age': 'Возраст',
    'show_region': 'Регион',
    'show_streak': 'Серия и успешные дни',
    'show_achievements': 'Праймы и достижения',
    'show_habits': 'Активные привычки',
    'show_groups': 'Группы',
  };

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
      final updated = await auth.api.updateMe({'privacy_settings': next});
      await auth.applyUserUpdate(updated);
    } catch (e) {
      if (mounted) showAppSnackBar(context, FailureMapper.from(e).message);
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

  String _previewLine(Map<String, bool> settings) {
    final visible = [
      if (settings['show_bio'] ?? true) 'О себе',
      if (settings['show_age'] ?? true) 'Возраст',
      if (settings['show_region'] ?? true) 'Регион',
      if (settings['show_streak'] ?? true) 'Серии',
      if (settings['show_achievements'] ?? true) 'Праймы',
    ];
    return visible.isEmpty ? 'Ничего не видно посторонним' : visible.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final settings = user?.privacySettings ?? {};
    final p = context.prime;
    final preset = detectPrivacyPreset(settings);

    return SettingsPageScaffold(
      title: 'Приватность',
      subtitle: 'Кто видит что в вашем публичном профиле.',
      children: [
        AppSettingsSection(
          title: 'Быстрый пресет',
          footer: Text(
            _privacySaving ? 'Сохраняем…' : 'Пресет можно уточнить вручную ниже.',
            style: AppTypography.caption.copyWith(color: p.inkMuted),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SettingsSegmentedControl<PrivacyPreset>(
                options: PrivacyPreset.values,
                selected: preset,
                enabled: !_privacySaving,
                labelBuilder: (v) => privacyPresetLabels[v]!,
                onSelected: (v) {
                  AppHaptics.selection();
                  _applyPrivacyPreset(v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSettingsSection(
          title: 'Превью',
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: PrimeContentCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Публичный профиль покажет',
                      style: AppTypography.caption.copyWith(color: p.brandSoft),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _previewLine(settings),
                      style: AppTypography.bodySecondary.copyWith(color: p.inkSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsDisclosure(
          title: 'Настроить вручную',
          subtitle: 'Отдельный переключатель для каждого поля',
          expanded: _manualExpanded,
          onToggle: () => setState(() => _manualExpanded = !_manualExpanded),
          child: Column(
            children: [
              for (final entry in _privacyLabels.entries)
                AppSettingsSwitchTile(
                  icon: Icons.visibility_outlined,
                  title: entry.value,
                  subtitle: 'Видно в публичном профиле',
                  value: settings[entry.key] ??
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
    );
  }
}
