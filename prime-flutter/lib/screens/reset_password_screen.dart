import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/errors/app_failure.dart';
import '../core/errors/failure_mapper.dart';
import '../core/security/password_strength.dart';
import '../data/api_client.dart';
import '../design/haptics.dart';
import '../design/tokens.dart';
import '../l10n/copy.dart';
import '../ui/components/app_header.dart';
import '../ui/components/app_inline_error.dart';
import '../ui/components/app_password_field.dart';
import '../ui/components/app_primary_button.dart';
import '../ui/components/app_snackbar.dart';
import '../ui/components/auth/auth_presentation.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.code,
  });

  final String email;
  final String code;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
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
            email: widget.email,
            code: widget.code,
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
    return AuthPageShell(
      appBar: buildAppBackBar(context, title: 'Новый пароль'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeroBanner(
              compact: true,
              badge: 'Безопасность',
              title: 'Новый пароль',
              subtitle:
                  'Код подтверждён. Придумайте надёжный пароль для входа.',
            ),
            const SizedBox(height: AppSpacing.lg),
            AuthFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppPasswordField(
                    controller: _password,
                    showRequirements: true,
                    validator: _validatePassword,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppInlineError(message: _error!),
                  ],
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
    );
  }
}
