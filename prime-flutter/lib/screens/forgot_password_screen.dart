import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/errors/app_failure.dart';
import '../core/errors/failure_mapper.dart';
import '../data/api_client.dart';
import '../design/glass.dart';
import '../design/routes.dart';
import '../design/haptics.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../l10n/copy.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../ui/components/app_header.dart';
import '../ui/components/app_inline_error.dart';
import '../ui/components/app_primary_button.dart';
import '../ui/components/app_text_button.dart';
import '../ui/components/editorial/app_auth_hero.dart';
import '../ui/components/app_text_field.dart';
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
      // 404 here means the running API build lacks the reset route — not "email missing".
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildAppBackBar(context, title: 'Восстановление пароля'),
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
                    title: 'Восстановление пароля',
                    subtitle:
                        'Укажите email аккаунта. Мы подготовим код для смены пароля.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  GlassContainer(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    glow: AppGlow.violet(opacity: 0.12),
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
                if (_error != null) AppInlineError(message: _error!),
                if (_info != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _info!,
                    style: AppTypography.bodySecondary,
                  ),
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
        ),
        ),
      ),
    );
  }
}
