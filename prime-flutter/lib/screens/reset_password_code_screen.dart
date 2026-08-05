import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/errors/app_failure.dart';
import '../core/errors/failure_mapper.dart';
import '../data/api_client.dart';
import '../design/haptics.dart';
import '../design/routes.dart';
import '../design/tokens.dart';
import '../l10n/copy.dart';
import '../ui/components/app_code_field.dart';
import '../ui/components/app_header.dart';
import '../ui/components/app_inline_error.dart';
import '../ui/components/app_primary_button.dart';
import '../ui/components/app_secondary_button.dart';
import '../ui/components/auth/auth_presentation.dart';
import 'reset_password_screen.dart';

class ResetPasswordCodeScreen extends StatefulWidget {
  const ResetPasswordCodeScreen({
    super.key,
    required this.email,
    this.initialResendCooldownSeconds = 0,
  });

  final String email;
  final int initialResendCooldownSeconds;

  @override
  State<ResetPasswordCodeScreen> createState() => _ResetPasswordCodeScreenState();
}

class _ResetPasswordCodeScreenState extends State<ResetPasswordCodeScreen> {
  static const _codeLength = 6;

  final _code = TextEditingController();
  Timer? _resendTimer;
  bool _loading = false;
  bool _resending = false;
  int _resendSeconds = 0;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _code.addListener(_onCodeChanged);
    if (widget.initialResendCooldownSeconds > 0) {
      _startResendCountdown(widget.initialResendCooldownSeconds);
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _code.removeListener(_onCodeChanged);
    _code.dispose();
    super.dispose();
  }

  void _startResendCountdown(int seconds) {
    _resendTimer?.cancel();
    if (seconds <= 0) {
      setState(() => _resendSeconds = 0);
      return;
    }
    setState(() => _resendSeconds = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds -= 1);
    });
  }

  int _resendCooldownFromResponse(Map<String, dynamic> response) {
    final value = response['resend_available_in_seconds'];
    if (value is int) return value;
    if (value is num) return value.round();
    return 0;
  }

  void _onCodeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    if (code.length != _codeLength || _loading) return;
    await AppHaptics.light();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<ApiClient>().verifyResetCode(
            email: widget.email,
            code: code,
          );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        PrimeRoute.sharedAxis(
          builder: (_) => ResetPasswordScreen(
            email: widget.email,
            code: code,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final failure = FailureMapper.from(e);
      final message = switch (failure) {
        ValidationFailure(:final message) when message.contains('Неверный') =>
          message,
        ValidationFailure() => AppCopy.passwordResetInvalidToken,
        _ => failure.message,
      };
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || _resendSeconds > 0) return;
    await AppHaptics.selection();
    setState(() {
      _resending = true;
      _error = null;
      _notice = null;
    });
    try {
      final response =
          await context.read<ApiClient>().forgotPassword(widget.email);
      if (!mounted) return;
      final cooldown = _resendCooldownFromResponse(response);
      if (cooldown > 0) {
        _startResendCountdown(cooldown);
        setState(() {
          _notice = AppCopy.rateLimitWithRetry(cooldown);
        });
        return;
      }
      _startResendCountdown(cooldown);
      setState(() {
        _code.clear();
        _notice = 'Отправили новый код на ${widget.email}.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = FailureMapper.from(e).message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _code.text.trim().length == _codeLength && !_loading;

    return AuthPageShell(
      appBar: buildAppBackBar(context, title: 'Код восстановления'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeroBanner(
            compact: true,
            badge: 'Безопасность',
            title: 'Код восстановления',
            subtitle:
                'Отправили код из $_codeLength цифр на ${widget.email}. '
                'Подтвердите его, чтобы задать новый пароль.',
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthFormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCodeField(
                  controller: _code,
                  length: _codeLength,
                  onCompleted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.sm),
                const AuthFieldHint(
                  text: 'Письма нет? Проверьте папку «Спам» или отправьте код снова.',
                  tone: AuthFieldHintTone.neutral,
                ),
                if (_notice != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AuthFieldHint(
                    text: _notice!,
                    tone: AuthFieldHintTone.neutral,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppInlineError(message: _error!),
                ],
                const SizedBox(height: AppSpacing.sm),
                AppSecondaryButton(
                  label: _resendSeconds > 0
                      ? 'Отправить снова через $_resendSeconds с'
                      : 'Отправить код снова',
                  icon: Icons.refresh_rounded,
                  loading: _resending,
                  onPressed: (_resending || _resendSeconds > 0) ? null : _resend,
                ),
                const SizedBox(height: AppSpacing.md),
                AppPrimaryButton(
                  label: 'Подтвердить',
                  loading: _loading,
                  onPressed: canSubmit ? _submit : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
