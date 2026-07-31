import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/api_client.dart';
import '../design/tokens.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../ui/components/app_header.dart';
import '../ui/components/app_primary_button.dart';
import '../ui/components/app_scaffold.dart';
import '../ui/components/app_snackbar.dart';
import '../ui/components/app_text_field.dart';
import '../ui/components/settings/app_settings_section.dart';

/// User-facing appeal against a moderation decision.
class ModerationAppealScreen extends StatefulWidget {
  const ModerationAppealScreen({
    super.key,
    required this.decisionId,
  });

  final String decisionId;

  @override
  State<ModerationAppealScreen> createState() => _ModerationAppealScreenState();
}

class _ModerationAppealScreenState extends State<ModerationAppealScreen> {
  final _explanationCtrl = TextEditingController();
  var _submitting = false;

  @override
  void dispose() {
    _explanationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await context.read<ApiClient>().submitModerationAppeal(
            decisionId: widget.decisionId,
            explanation: _explanationCtrl.text.trim(),
          );
      if (!mounted) return;
      showAppSnackBar(context, 'Апелляция отправлена на проверку');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showAppSnackBar(context, ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: buildAppBackBar(context, title: 'Апелляция'),
      body: AmbientCanvas(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            AppSettingsSection(
              title: 'Почему это ошибка?',
              footer: const Text(
                'Опишите, почему считаете ограничение несправедливым. '
                'На одно решение можно подать только одну апелляцию.',
              ),
              children: [
                AppTextField(
                  controller: _explanationCtrl,
                  label: 'Комментарий',
                  minLines: 4,
                  maxLines: 8,
                  textInputAction: TextInputAction.newline,
                ),
                const SizedBox(height: AppSpacing.md),
                AppPrimaryButton(
                  label: 'Отправить апелляцию',
                  loading: _submitting,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
