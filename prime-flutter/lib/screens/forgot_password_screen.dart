import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/errors/app_failure.dart';
import '../core/errors/failure_mapper.dart';
import '../data/api_client.dart';
import '../design/routes.dart';
import '../design/haptics.dart';
import '../design/tokens.dart';
import '../l10n/copy.dart';
import '../ui/components/app_header.dart';
import '../ui/components/app_inline_error.dart';
import '../ui/components/app_primary_button.dart';
import '../ui/components/app_text_field.dart';
import '../ui/components/auth/auth_presentation.dart';
import 'reset_password_code_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _email;
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _loading) return;
    await AppHaptics.light();
    final email = _email.text.trim().toLowerCase();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response =
          await context.read<ApiClient>().forgotPassword(email);
      if (!mounted) return;
      final cooldownRaw = response['resend_available_in_seconds'];
      final waitSeconds = cooldownRaw is int
          ? cooldownRaw
          : cooldownRaw is num
              ? cooldownRaw.round()
              : 0;
      await Navigator.of(context).pushReplacement(
        PrimeRoute.sharedAxis(
          builder: (_) => ResetPasswordCodeScreen(
            email: email,
            initialResendCooldownSeconds: waitSeconds,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final failure = FailureMapper.from(e);
      final message = failure is NotFoundFailure
          ? AppCopy.passwordResetUnavailable
          : failure.message;
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageShell(
      appBar: buildAppBackBar(context, title: 'Восстановление'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeroBanner(
              compact: true,
              badge: 'Безопасность',
              title: 'Восстановление пароля',
              subtitle:
                  'Укажите email аккаунта — отправим код из 6 цифр для смены пароля.',
            ),
            const SizedBox(height: AppSpacing.lg),
            AuthFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _email,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return 'Введите email';
                      if (!email.contains('@')) return 'Некорректный email';
                      return null;
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppInlineError(message: _error!),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  AppPrimaryButton(
                    label: AppCopy.continueLabel,
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
