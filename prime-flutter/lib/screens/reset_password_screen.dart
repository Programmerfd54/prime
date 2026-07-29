import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/errors/app_failure.dart';
import '../core/errors/failure_mapper.dart';
import '../core/security/password_strength.dart';
import '../data/api_client.dart';
import '../design/glass.dart';
import '../design/haptics.dart';
import '../design/tokens.dart';
import '../l10n/copy.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../ui/components/app_header.dart';
import '../ui/components/app_inline_error.dart';
import '../ui/components/app_password_field.dart';
import '../ui/components/app_primary_button.dart';
import '../ui/components/app_snackbar.dart';
import '../ui/components/editorial/app_auth_hero.dart';
import '../ui/components/app_text_field.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.initialToken = ''});

  final String initialToken;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late final TextEditingController _token;
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _token = TextEditingController(text: widget.initialToken);
  }

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    return PasswordStrengthAnalyzer.validateForRegister(value);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _loading) return;
    await AppHaptics.light();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<ApiClient>().resetPassword(
            token: _token.text.trim(),
            newPassword: _password.text,
          );
      if (!mounted) return;
      showAppSnackBar(context, 'Пароль обновлён. Войдите с новым паролем.');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      final failure = FailureMapper.from(e);
      final message = switch (failure) {
        NotFoundFailure() => AppCopy.passwordResetUnavailable,
        ValidationFailure(:final message) when message.contains('недействителен') =>
          AppCopy.passwordResetInvalidToken,
        ValidationFailure() => AppCopy.passwordResetInvalidToken,
        _ => failure.message,
      };
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildAppBackBar(context, title: 'Новый пароль'),
      body: SafeArea(
        child: AmbientCanvas(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppAuthHero(
                    compact: true,
                    title: 'Новый пароль',
                    subtitle:
                        'Введите код восстановления и надёжный новый пароль.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  GlassContainer(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    glow: AppGlow.violet(opacity: 0.12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                AppTextField(
                  controller: _token,
                  label: 'Код восстановления',
                  validator: (value) {
                    if ((value ?? '').trim().length < 16) {
                      return 'Введите код из письма или ответа сервера';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppPasswordField(
                  controller: _password,
                  showRequirements: true,
                  validator: _validatePassword,
                ),
                if (_error != null) AppInlineError(message: _error!),
                const SizedBox(height: AppSpacing.md),
                AppPrimaryButton(
                  label: 'Сохранить пароль',
                  loading: _loading,
                  onPressed: _loading ? null : _submit,
                ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
