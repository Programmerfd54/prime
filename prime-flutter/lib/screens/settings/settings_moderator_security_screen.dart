import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../design/tokens.dart';
import '../../design/visuals/ambient_and_progress.dart';
import '../../ui/components/app_header.dart';
import '../../ui/components/app_primary_button.dart';
import '../../ui/components/app_scaffold.dart';
import '../../ui/components/app_snackbar.dart';
import '../../ui/components/app_text_field.dart';
import '../../ui/components/settings/app_settings_section.dart';

/// Moderator-only TOTP enrollment and step-up verification.
class SettingsModeratorSecurityScreen extends StatefulWidget {
  const SettingsModeratorSecurityScreen({super.key});

  @override
  State<SettingsModeratorSecurityScreen> createState() =>
      _SettingsModeratorSecurityScreenState();
}

class _SettingsModeratorSecurityScreenState
    extends State<SettingsModeratorSecurityScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _otpauthUri;
  List<String> _backupCodes = const [];

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _startEnrollment() async {
    setState(() => _loading = true);
    try {
      final payload = await context.read<ApiClient>().enrollModeratorTotp();
      if (!mounted) return;
      setState(() {
        _otpauthUri = payload['otpauth_uri'] as String?;
        _backupCodes = const [];
      });
      showAppSnackBar(context, 'Сканируйте QR в приложении-аутентификаторе');
    } catch (e) {
      if (mounted) showAppSnackBar(context, ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmEnrollment() async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      showAppSnackBar(context, 'Введите 6-значный код');
      return;
    }
    setState(() => _loading = true);
    try {
      final payload = await context.read<ApiClient>().verifyModeratorTotp(
            code,
            confirmEnrollment: _otpauthUri != null,
          );
      if (!mounted) return;
      final codes = payload['backup_codes'];
      setState(() {
        _backupCodes = codes is List
            ? codes.map((item) => item.toString()).toList(growable: false)
            : const [];
        _otpauthUri = null;
      });
      _codeController.clear();
      showAppSnackBar(
        context,
        _backupCodes.isEmpty
            ? 'Двухфакторная аутентификация активирована'
            : 'Сохраните резервные коды в надёжном месте',
      );
    } catch (e) {
      if (mounted) showAppSnackBar(context, ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyBackupCodes() async {
    if (_backupCodes.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _backupCodes.join('\n')));
    if (!mounted) return;
    showAppSnackBar(context, 'Коды скопированы');
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: buildAppBackBar(context, title: 'Безопасность модератора'),
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
              title: 'Двухфакторная аутентификация',
              footer: const Text(
                'TOTP обязателен для доступа к операциям модератора. '
                'Passkeys можно зарегистрировать через веб-интерфейс ops.',
              ),
              children: [
                if (_otpauthUri != null)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: SelectableText(
                      _otpauthUri!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                AppPrimaryButton(
                  label: _otpauthUri == null ? 'Начать настройку TOTP' : 'Перегенерировать QR',
                  loading: _loading && _otpauthUri == null,
                  onPressed: _loading ? null : _startEnrollment,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _codeController,
                  label: 'Код из приложения',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppPrimaryButton(
                  label: _otpauthUri == null ? 'Подтвердить вход' : 'Завершить настройку',
                  loading: _loading && _otpauthUri != null,
                  onPressed: _loading ? null : _confirmEnrollment,
                ),
              ],
            ),
            if (_backupCodes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              AppSettingsSection(
                title: 'Резервные коды',
                footer: const Text('Каждый код можно использовать один раз.'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: SelectableText(_backupCodes.join('\n')),
                  ),
                  AppPrimaryButton(
                    label: 'Скопировать коды',
                    onPressed: _copyBackupCodes,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
