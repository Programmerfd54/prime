import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/errors/app_failure.dart';
import '../core/errors/failure_mapper.dart';
import '../data/api_client.dart';
import '../design/routes.dart';
import '../design/haptics.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../l10n/copy.dart';
import '../ui/components/app_header.dart';
import '../ui/components/app_inline_error.dart';
import '../ui/components/app_primary_button.dart';
import '../ui/components/app_text_button.dart';
import '../ui/components/app_text_field.dart';
import '../ui/components/auth/auth_presentation.dart';
import 'reset_password_screen.dart';

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
  String? _info;

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
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final result =
          await context.read<ApiClient>().forgotPassword(_email.text.trim());
      if (!mounted) return;
      final token = result['reset_token'] as String?;
      if (token != null && token.isNotEmpty) {
        await Navigator.of(context).pushReplacement(
          PrimeRoute.sharedAxis(
            builder: (_) => ResetPasswordScreen(initialToken: token),
          ),
        );
        return;
      }
      setState(() {
        _info = result['message'] as String? ??
            'Если аккаунт существует, используйте код восстановления.';
      });
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
                  'Укажите email аккаунта — подготовим код для смены пароля.',
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
                  if (_info != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const AuthFieldHint(
                      text: 'Проверьте почту или введите код вручную.',
                      tone: AuthFieldHintTone.neutral,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(_info!, style: AppTypography.bodySecondary),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextButton(
                      label: 'У меня есть код',
                      onPressed: () {
                        Navigator.of(context).push(
                          PrimeRoute.sharedAxis(
                            builder: (_) => const ResetPasswordScreen(),
                          ),
                        );
                      },
                    ),
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
