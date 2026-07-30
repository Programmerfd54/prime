import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/profile/profile_preferences.dart';
import '../../../data/api_client.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../app_dialog.dart';
import '../app_primary_button.dart';
import '../settings/settings_presentation.dart';

/// Rhythm + support style picker for team matching.
Future<bool> showRhythmSupportSheet(BuildContext context) async {
  final api = context.read<ApiClient>();
  Map<String, dynamic> prefs = const {};
  try {
    prefs = await api.getPreferences();
  } catch (_) {}

  if (!context.mounted) return false;

  final timeRaw = prefs[ProfilePreferences.preferredTimeOfDayKey] as String?;
  final supportRaw = prefs[ProfilePreferences.supportStyleKey] as String?;

  var timeLabel = ProfilePreferences.preferredTimeLabel(timeRaw);
  var supportLabel = ProfilePreferences.supportStyleLabel(supportRaw);
  if (timeRaw == null) {
    timeLabel = ProfilePreferences.timeOptions.first.label;
  }
  if (supportRaw == null) {
    supportLabel = ProfilePreferences.supportOptions.first.label;
  }

  final result = await showAppBottomSheet<bool>(
    context: context,
    child: Builder(
      builder: (sheetContext) {
        var saving = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final supportValue =
                ProfilePreferences.supportValueForLabel(supportLabel);
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Ритм и поддержка',
                      style: AppTypography.title1,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Команда увидит это при знакомстве — так проще '
                      'найти людей с похожим расписанием и стилем общения.',
                      style: AppTypography.bodySecondary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const _WhyRhythmBullets(),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Когда удобнее заниматься',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SettingsChoiceChips(
                      options: ProfilePreferences.timeOptions
                          .map((e) => e.label)
                          .toList(),
                      selected: timeLabel,
                      enabled: !saving,
                      onSelected: (value) =>
                          setModalState(() => timeLabel = value),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Тип поддержки в команде',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SettingsChoiceChips(
                      options: ProfilePreferences.supportOptions
                          .map((e) => e.label)
                          .toList(),
                      selected: supportLabel,
                      enabled: !saving,
                      onSelected: (value) =>
                          setModalState(() => supportLabel = value),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      ProfilePreferences.supportStyleDescription(supportValue),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppPrimaryButton(
                      label: 'Сохранить',
                      loading: saving,
                      onPressed: saving
                          ? null
                          : () async {
                              final timeValue = ProfilePreferences
                                  .timeValueForLabel(timeLabel);
                              final supportValue = ProfilePreferences
                                  .supportValueForLabel(supportLabel);
                              if (timeValue == null || supportValue == null) {
                                return;
                              }
                              setModalState(() => saving = true);
                              try {
                                await api.updatePreferences({
                                  ProfilePreferences.preferredTimeOfDayKey:
                                      timeValue,
                                  ProfilePreferences.supportStyleKey:
                                      supportValue,
                                });
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop(true);
                                }
                              } catch (_) {
                                setModalState(() => saving = false);
                              }
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
  return result == true;
}

class _WhyRhythmBullets extends StatelessWidget {
  const _WhyRhythmBullets();

  @override
  Widget build(BuildContext context) {
    const items = [
      'Время дня — чтобы отчёты и созвоны не мешали работе или сну',
      'Тип поддержки — чтобы напоминания и общение были комфортными',
      'Данные учитываются при подборе и показываются в introduction room',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: AppTypography.bodySecondary),
                Expanded(
                  child: Text(item, style: AppTypography.bodySecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
