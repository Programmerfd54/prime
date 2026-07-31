import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/validation/about_quality.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../providers/auth_provider.dart';
import '../app_dialog.dart';
import '../app_primary_button.dart';
import '../app_textarea.dart';

enum AboutBeforeTeamReason { search, pairInvite }

/// Returns `true` when about is ready or was saved successfully.
Future<bool> ensureAboutBeforeTeam(
  BuildContext context, {
  AboutBeforeTeamReason reason = AboutBeforeTeamReason.search,
}) async {
  final auth = context.read<AuthProvider>();
  final about = auth.user?.about ?? '';
  if (AboutQuality.junkReason(about) == null) {
    return true;
  }
  return showAboutBeforeTeamSheet(context, reason: reason);
}

Future<bool> showAboutBeforeTeamSheet(
  BuildContext context, {
  AboutBeforeTeamReason reason = AboutBeforeTeamReason.search,
}) async {
  final auth = context.read<AuthProvider>();
  final controller = TextEditingController(text: auth.user?.about ?? '');
  final savedText = await showAppBottomSheet<String>(
    context: context,
    child: Builder(
      builder: (sheetContext) {
        String? localError;
        var saving = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final words = AboutQuality.wordCount(controller.text);
            final subtitle = reason == AboutBeforeTeamReason.pairInvite
                ? 'Чтобы принять приглашение в пару, команда должна узнать вас при знакомстве.'
                : 'Перед поиском команды участники прочитают ваш текст в introduction room.';
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
                      'Расскажите о себе — команда увидит это при знакомстве',
                      style: AppTypography.title1,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(subtitle, style: AppTypography.bodySecondary),
                    const SizedBox(height: AppSpacing.md),
                    const _WhyAboutBullets(),
                    const SizedBox(height: AppSpacing.md),
                    AppTextarea(
                      controller: controller,
                      label: 'О себе',
                      hint:
                          'Например: работаю удалённо, ищу поддержку вечером, '
                          'люблю честную обратную связь…',
                      minLines: 5,
                      maxLines: 8,
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Слов: $words / ${AboutQuality.minWords}',
                      style: AppTypography.caption.copyWith(
                        color: words >= AboutQuality.minWords
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        localError!,
                        style: AppTypography.bodySecondary.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    AppPrimaryButton(
                      label: 'Сохранить и продолжить',
                      loading: saving,
                      onPressed: saving
                          ? null
                          : () {
                              final junk =
                                  AboutQuality.junkReason(controller.text);
                              if (junk != null) {
                                setModalState(() => localError = junk);
                                return;
                              }
                              final trimmed = controller.text.trim();
                              setModalState(() {
                                saving = true;
                                localError = null;
                              });
                              // Close the sheet before AuthProvider notifies —
                              // otherwise the chat screen rebuilds while the
                              // sheet is still mounted and can crash (ui-*).
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop(trimmed);
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
  controller.dispose();

  if (savedText == null || !context.mounted) {
    return false;
  }
  await auth.applyAboutLocally(savedText);
  auth.persistAboutInBackground(savedText);
  return true;
}

class _WhyAboutBullets extends StatelessWidget {
  const _WhyAboutBullets();

  @override
  Widget build(BuildContext context) {
    const items = [
      'Участники поймут ваш ритм, мотивацию и ожидания от команды',
      'Подбор совместимых людей идёт быстрее, когда профиль живой',
      'Текст показывается при знакомстве — не нужно повторять одно и то же',
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
