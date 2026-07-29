import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/analytics/analytics.dart';
import '../core/errors/app_failure.dart';
import '../core/errors/failure_mapper.dart';
import '../core/security/password_strength.dart';
import '../data/api_client.dart';
import '../design/glass.dart';
import '../design/routes.dart';
import '../design/haptics.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/visuals/scene_art.dart';
import '../l10n/copy.dart';
import '../providers/auth_provider.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../ui/components/app_checkbox.dart';
import '../ui/components/app_inline_error.dart';
import '../ui/components/app_password_field.dart';
import '../ui/components/app_primary_button.dart';
import '../ui/components/app_secondary_button.dart';
import '../ui/components/app_text_button.dart';
import '../ui/components/editorial/app_auth_hero.dart';
import '../ui/components/prime_text_field.dart';
import '../ui/states/app_loading_state.dart';
import 'forgot_password_screen.dart';

enum _NicknameAvailability { idle, checking, available, taken }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.startInLogin = false});

  /// Opens directly on the login form — used when the user asked to sign
  /// in from the onboarding flow instead of registering.
  final bool startInLogin;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _nickname = TextEditingController();
  final _emailFocus = FocusNode();
  final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  final _nicknameRegex = RegExp(r'^[a-z0-9_][a-z0-9_.-]{2,31}$');

  /// Register is the primary path; login is a secondary toggle.
  bool _isLogin = false;
  int _registerStep = 0;
  bool _agreed = false;
  String? _error;
  bool _offerSwitchToLogin = false;
  _NicknameAvailability _nicknameStatus = _NicknameAvailability.idle;
  Timer? _nicknameDebounce;
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.startInLogin;
    _nickname.addListener(_onNicknameChanged);
    _email.addListener(_onFormChanged);
    _password.addListener(_onFormChanged);
    _name.addListener(_onFormChanged);
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _openUrl('https://inpr1me.ru/terms');
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _openUrl('https://inpr1me.ru/privacy');
    if (!_isLogin) {
      Analytics.instance.registerStepViewed(0);
    }
  }

  @override
  void dispose() {
    _nicknameDebounce?.cancel();
    _nickname.removeListener(_onNicknameChanged);
    _email.removeListener(_onFormChanged);
    _password.removeListener(_onFormChanged);
    _name.removeListener(_onFormChanged);
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _nickname.dispose();
    _emailFocus.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _onNicknameChanged() {
    _nicknameDebounce?.cancel();
    final nickname = _normalizedNickname;
    if (_isLogin || !_nicknameRegex.hasMatch(nickname)) {
      setState(() => _nicknameStatus = _NicknameAvailability.idle);
      return;
    }
    setState(() => _nicknameStatus = _NicknameAvailability.checking);
    _nicknameDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_checkNickname(nickname));
    });
  }

  Future<void> _checkNickname(String nickname) async {
    try {
      await context.read<ApiClient>().findUserByNickname(nickname);
      if (!mounted || _normalizedNickname != nickname) return;
      setState(() => _nicknameStatus = _NicknameAvailability.taken);
    } on DioException catch (e) {
      if (!mounted || _normalizedNickname != nickname) return;
      if (e.response?.statusCode == 404) {
        setState(() => _nicknameStatus = _NicknameAvailability.available);
      } else {
        setState(() => _nicknameStatus = _NicknameAvailability.idle);
      }
    } catch (_) {
      if (!mounted || _normalizedNickname != nickname) return;
      setState(() => _nicknameStatus = _NicknameAvailability.idle);
    }
  }

  Future<void> _submit() async {
    if (!_isLogin && _registerStep < 2) {
      if (!_validateRegisterStep(_registerStep)) return;
      await AppHaptics.selection();
      setState(() {
        _registerStep += 1;
        _error = null;
      });
      Analytics.instance.registerStepViewed(_registerStep);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    await AppHaptics.light();

    if (!_isLogin && !_agreed) {
      setState(() => _error = AppCopy.agreementRequired);
      return;
    }

    if (!_isLogin && _nicknameStatus == _NicknameAvailability.taken) {
      setState(() => _error = AppCopy.nicknameTaken);
      return;
    }

    setState(() {
      _error = null;
      _offerSwitchToLogin = false;
    });
    final auth = context.read<AuthProvider>();
    auth.clearSessionExpiredNotice();
    final email = _email.text.trim().toLowerCase();
    final register = !_isLogin;
    Analytics.instance.authStart(register: register);

    try {
      if (_isLogin) {
        await auth.login(email, _password.text);
      } else {
        await auth.register(
          email,
          _password.text,
          name: _name.text.trim(),
          nickname: _normalizedNickname,
        );
      }
      Analytics.instance.authSuccess(register: register);
    } catch (e) {
      if (!mounted) return;
      final failure = FailureMapper.from(e);
      setState(() {
        _error = _authErrorMessage(failure, isLogin: _isLogin);
        _offerSwitchToLogin = !_isLogin && failure is ConflictFailure;
      });
    }
  }

  String _authErrorMessage(AppFailure failure, {required bool isLogin}) {
    return switch (failure) {
      UnauthorizedFailure() when isLogin =>
        // Never show "session expired" for a failed password attempt.
        (failure.message == AppCopy.unauthorized || failure.message.isEmpty)
            ? AppCopy.invalidCredentials
            : failure.message,
      UnauthorizedFailure() => AppCopy.invalidCredentials,
      ConflictFailure() when !isLogin => AppCopy.emailAlreadyRegistered,
      ConflictFailure() when isLogin => AppCopy.conflict,
      NotFoundFailure() when isLogin => AppCopy.invalidCredentials,
      RateLimitFailure() => failure.message,
      NetworkFailure() || TimeoutFailure() => failure.message,
      ValidationFailure() => failure.message,
      ServiceUnavailableFailure() || ServerFailure() => failure.message,
      _ => failure.message,
    };
  }

  bool _validateRegisterStep(int step) {
    switch (step) {
      case 0:
        return _validateName(_name.text) == null &&
            _validateNickname(_nickname.text) == null &&
            _nicknameStatus != _NicknameAvailability.checking &&
            _nicknameStatus != _NicknameAvailability.taken;
      case 1:
        return _validateEmail(_email.text) == null &&
            _validatePassword(_password.text) == null;
      default:
        return true;
    }
  }

  String get _primaryActionLabel {
    if (_isLogin) return 'Войти';
    return switch (_registerStep) {
      0 || 1 => AppCopy.continueLabel,
      _ => 'Создать аккаунт',
    };
  }

  bool get _canSubmit {
    if (_isLogin) {
      return _validateEmail(_email.text) == null &&
          _validatePassword(_password.text) == null;
    }
    if (_registerStep < 2) return _validateRegisterStep(_registerStep);
    if (!_agreed) return false;
    if (_validateName(_name.text) != null) return false;
    if (_validateNickname(_nickname.text) != null) return false;
    if (_validateEmail(_email.text) != null) return false;
    if (_validatePassword(_password.text) != null) return false;
    if (_nicknameStatus == _NicknameAvailability.checking ||
        _nicknameStatus == _NicknameAvailability.taken) {
      return false;
    }
    return true;
  }

  String get _normalizedNickname =>
      _nickname.text.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');

  String? _validateEmail(String? value) {
    final email = value?.trim().toLowerCase() ?? '';
    if (email.isEmpty) return 'Введите email';
    if (!_emailRegex.hasMatch(email)) return 'Введите корректный email';
    return null;
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Введите имя';
    if (name.length < 2) return 'Имя должно быть длиннее';
    return null;
  }

  String? _validateNickname(String? value) {
    final nickname =
        (value ?? '').trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');
    if (nickname.isEmpty) return 'Введите никнейм';
    if (!_nicknameRegex.hasMatch(nickname)) {
      return '3–32 символа: a-z, 0-9, точка, дефис или _';
    }
    if (_nicknameStatus == _NicknameAvailability.taken) {
      return 'Никнейм уже занят';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (_isLogin) return PasswordStrengthAnalyzer.validateForLogin(value);
    return PasswordStrengthAnalyzer.validateForRegister(value);
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _registerStep = 0;
      _error = null;
      _offerSwitchToLogin = false;
      _agreed = false;
      _nicknameStatus = _NicknameAvailability.idle;
    });
  }

  void _switchToLoginPreservingEmail() {
    setState(() {
      _isLogin = true;
      _error = null;
      _offerSwitchToLogin = false;
      _agreed = false;
      _nicknameStatus = _NicknameAvailability.idle;
    });
  }

  String? get _nicknameHelper {
    if (_isLogin) return null;
    return switch (_nicknameStatus) {
      _NicknameAvailability.checking => 'Проверяем никнейм…',
      _NicknameAvailability.available => 'Никнейм свободен',
      _NicknameAvailability.taken => 'Никнейм уже занят',
      _NicknameAvailability.idle => 'Уникальный логин для поиска друзей',
    };
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().loading;
    final maxWidth = AppBreakpoints.maxContentWidth;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: loading
            ? const AppLoadingState(label: 'Подключаем PRIME…')
            : AmbientCanvas(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.xl,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: AutofillGroup(
                        child: Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.disabled,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppAuthHero(
                                compact: _isLogin,
                                title: _isLogin
                                    ? 'С возвращением'
                                    : switch (_registerStep) {
                                        0 => 'Как вас представить',
                                        1 => 'Контакты и доступ',
                                        _ => 'Создайте аккаунт',
                                      },
                                subtitle: _isLogin
                                    ? 'Продолжите привычки и общение в команде.'
                                    : switch (_registerStep) {
                                        0 =>
                                          'Имя видно команде. Никнейм уникален — по нему найдут друзья.',
                                        1 =>
                                          'Email для входа. Пароль проверим на силу — слабый не пропустим.',
                                        _ =>
                                          'Примите условия — и начните поиск команды.',
                                      },
                              ),
                              if (!_isLogin) ...[
                                const SizedBox(height: AppSpacing.md),
                                _RegisterStepBar(step: _registerStep),
                              ],
                              const SizedBox(height: AppSpacing.xl),
                              GlassContainer(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.xl),
                                glow: AppGlow.violet(opacity: 0.12),
                                fillOpacity: 0.05,
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                      if (!_isLogin && _registerStep == 0) ...[
                        PrimeTextField(
                          key: const ValueKey('auth-register-name'),
                          controller: _name,
                          label: 'Имя',
                          icon: Icons.person_outline,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          validator: _validateName,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        PrimeTextField(
                          key: const ValueKey('auth-register-nickname'),
                          controller: _nickname,
                          label: 'Никнейм',
                          icon: Icons.alternate_email,
                          hint: _nicknameHelper,
                          keyboardType: TextInputType.visiblePassword,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          autocorrect: false,
                          enableSuggestions: false,
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(RegExp(r'\s')),
                          ],
                          validator: _validateNickname,
                        ),
                      ],
                      if (!_isLogin && _registerStep == 1) ...[
                        PrimeTextField(
                          key: const ValueKey('auth-register-email'),
                          controller: _email,
                          focusNode: _emailFocus,
                          label: 'Email',
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newUsername],
                          autocorrect: false,
                          enableSuggestions: false,
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(RegExp(r'\s')),
                          ],
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppPasswordField(
                          key: const ValueKey('auth-register-password'),
                          controller: _password,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          showRequirements: true,
                          validator: _validatePassword,
                        ),
                      ],
                      if (_isLogin) ...[
                        const Center(
                          child: SceneArt(kind: SceneKind.welcome, size: 88),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        PrimeTextField(
                          key: const ValueKey('auth-login-email'),
                          controller: _email,
                          focusNode: _emailFocus,
                          label: 'Email',
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          autocorrect: false,
                          enableSuggestions: false,
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(RegExp(r'\s')),
                          ],
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppPasswordField(
                          key: const ValueKey('auth-login-password'),
                          controller: _password,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          showRequirements: false,
                          validator: _validatePassword,
                        ),
                      ],
                      if (_isLogin) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: AppTextButton(
                            label: 'Забыли пароль?',
                            onPressed: () {
                              Navigator.of(context).push(
                                PrimeRoute.sharedAxis(
                                  builder: (_) => ForgotPasswordScreen(
                                    initialEmail: _email.text.trim(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      if (!_isLogin && _registerStep == 2) ...[
                        const SizedBox(height: AppSpacing.md),
                        AppCheckbox(
                          value: _agreed,
                          onChanged: (v) => setState(() {
                            _agreed = v ?? false;
                          }),
                          child: Text.rich(
                            TextSpan(
                              style: AppTypography.bodySecondary.copyWith(
                                fontSize: 13,
                              ),
                              children: [
                                const TextSpan(text: 'Я принимаю '),
                                TextSpan(
                                  text: 'пользовательское соглашение',
                                  style: TextStyle(
                                    color: AppColors.primarySoft,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: _termsRecognizer,
                                ),
                                const TextSpan(text: ' и '),
                                TextSpan(
                                  text: 'политику конфиденциальности',
                                  style: TextStyle(
                                    color: AppColors.primarySoft,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: _privacyRecognizer,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (_error != null) AppInlineError(message: _error!),
                      if (_offerSwitchToLogin) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AppSecondaryButton(
                          label: AppCopy.switchToLogin,
                          icon: Icons.login_rounded,
                          onPressed: _switchToLoginPreservingEmail,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      AppPrimaryButton(
                        label: _primaryActionLabel,
                        onPressed: _canSubmit ? _submit : null,
                      ),
                      if (!_isLogin && _registerStep > 0) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Center(
                          child: AppTextButton(
                            label: AppCopy.back,
                            onPressed: () => setState(() {
                              _registerStep -= 1;
                              _error = null;
                            }),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Center(
                        child: AppTextButton(
                          label: _isLogin
                              ? 'Создать аккаунт'
                              : 'Уже есть аккаунт? Войти',
                          onPressed: _toggleMode,
                        ),
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
                ),
              ),
      ),
    );
  }
}

class _RegisterStepBar extends StatelessWidget {
  const _RegisterStepBar({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Шаг ${step + 1} из 3',
          style: AppTypography.caption.copyWith(color: AppColors.primarySoft),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: AppDurations.fast,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    color: i <= step
                        ? AppColors.primary
                        : AppColors.primaryContainer.withValues(alpha: 0.45),
                    boxShadow: i <= step
                        ? [
                            ...AppGlow.violet(
                              opacity: i == step ? 0.55 : 0.22,
                            ),
                            if (i == step)
                              ...AppGlow.magenta(opacity: 0.2),
                          ]
                        : null,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
