import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/security/password_strength.dart';
import '../../data/api_client.dart';
import '../../design/typography.dart';
import '../../design/tokens.dart';
import '../../design/visuals/ambient_and_progress.dart';
import '../../ui/components/app_header.dart';
import '../../ui/components/app_password_field.dart';
import '../../ui/components/app_primary_button.dart';
import '../../ui/components/app_scaffold.dart';
import '../../ui/components/app_snackbar.dart';
import '../../ui/components/settings/app_settings_section.dart';

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
      Navigator.of(context).pop();
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
            AppSpacing.xxl,
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
