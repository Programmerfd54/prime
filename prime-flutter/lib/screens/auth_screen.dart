import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/auth/nickname_suggestions.dart';
import '../core/analytics/analytics.dart';
import '../core/errors/app_failure.dart';
import '../core/errors/failure_mapper.dart';
import '../core/security/password_strength.dart';
import '../data/api_client.dart';
import '../design/routes.dart';
import '../models/email_verification.dart';
import '../ui/components/auth/auth_presentation.dart';
import '../ui/components/app_checkbox.dart';
import '../ui/components/app_code_field.dart';
import '../design/haptics.dart';
import '../design/theme/prime_theme_context.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../l10n/copy.dart';
import '../providers/auth_provider.dart';
import 'forgot_password_screen.dart';
import '../ui/components/app_password_field.dart';
import '../ui/components/app_primary_button.dart';
import '../ui/components/app_secondary_button.dart';
import '../ui/components/app_text_button.dart';
import '../ui/components/app_inline_error.dart';
import '../ui/components/prime_text_field.dart';
import '../ui/components/app_snackbar.dart';

enum _NicknameAvailability { idle, checking, available, taken, inappropriate }

enum _NameAvailability { idle, checking, valid, inappropriate }

enum _EmailAvailability { idle, checking, available, taken, pendingVerification }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.startInLogin = false});

  /// Opens directly on the login form — used when the user asked to sign
  /// in from the onboarding flow instead of registering.
  final bool startInLogin;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  /// Review + terms step: submitting it creates the account.
  static const _summaryStep = 2;

  /// Email confirmation step: submitting it starts the session.
  static const _codeStep = 3;
  static const _codeLength = 6;

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _nickname = TextEditingController();
  final _code = TextEditingController();
  final _emailFocus = FocusNode();
  final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  /// Register is the primary path; login is a secondary toggle.
  bool _isLogin = false;
  int _registerStep = 0;
  bool _agreed = false;
  String? _error;
  String? _notice;
  bool _offerSwitchToLogin = false;
  _NicknameAvailability _nicknameStatus = _NicknameAvailability.idle;
  Timer? _nicknameDebounce;
  List<String> _nicknameSuggestions = const [];
  _NameAvailability _nameStatus = _NameAvailability.idle;
  Timer? _nameDebounce;
  _EmailAvailability _emailStatus = _EmailAvailability.idle;
  Timer? _emailDebounce;

  /// Address the confirmation code was sent to.
  String? _pendingEmail;
  int _resendSeconds = 0;
  Timer? _resendTimer;
  bool _submittingCode = false;
  /// True after the first successful `register` in this wizard session.
  bool _registrationPending = false;
  String? _registeredName;
  String? _registeredNickname;
  String? _registeredPassword;
  bool _offerContinueVerification = false;
  /// Login found correct password on an account awaiting email confirmation.
  bool _loginVerificationPending = false;
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.startInLogin;
    _nickname.addListener(_onNicknameChanged);
    _email.addListener(_onEmailChanged);
    _name.addListener(_onNameChanged);
    _password.addListener(_onFormChanged);
    _code.addListener(_onFormChanged);
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _openUrl('https://inpr1me.ru/terms');
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _openUrl('https://inpr1me.ru/privacy');
    if (!_isLogin) {
      Analytics.instance.registerStepViewed(0);
      _nicknameSuggestions = NicknameSuggestions.suggestNicknames('');
    }
  }

  @override
  void dispose() {
    _nicknameDebounce?.cancel();
    _emailDebounce?.cancel();
    _nameDebounce?.cancel();
    _resendTimer?.cancel();
    _nickname.removeListener(_onNicknameChanged);
    _email.removeListener(_onEmailChanged);
    _name.removeListener(_onNameChanged);
    _password.removeListener(_onFormChanged);
    _code.removeListener(_onFormChanged);
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _nickname.dispose();
    _code.dispose();
    _emailFocus.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  void _onEmailChanged() {
    _onFormChanged();
    if (_isLogin || _registerStep != 1) {
      if (_emailStatus != _EmailAvailability.idle) {
        setState(() => _emailStatus = _EmailAvailability.idle);
      }
      return;
    }
    _emailDebounce?.cancel();
    final email = _email.text.trim().toLowerCase();
    if (_validateEmail(email) != null) {
      setState(() => _emailStatus = _EmailAvailability.idle);
      return;
    }
    setState(() => _emailStatus = _EmailAvailability.checking);
    _emailDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_checkEmail(email));
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _onNameChanged() {
    _onFormChanged();
    _nameDebounce?.cancel();
    if (_isLogin || _registerStep != 0) {
      if (_nameStatus != _NameAvailability.idle) {
        setState(() => _nameStatus = _NameAvailability.idle);
      }
      return;
    }
    final name = _name.text.trim();
    if (_validateName(name) != null) {
      setState(() => _nameStatus = _NameAvailability.idle);
      return;
    }
    setState(() => _nameStatus = _NameAvailability.checking);
    _nameDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_checkName(name));
    });
  }

  Future<void> _checkName(String name) async {
    try {
      await context.read<ApiClient>().checkDisplayNameValid(name);
      if (!mounted || _name.text.trim() != name) return;
      setState(() => _nameStatus = _NameAvailability.valid);
    } on DioException catch (e) {
      if (!mounted || _name.text.trim() != name) return;
      final failure = FailureMapper.from(e);
      if (failure is ValidationFailure &&
          failure.message.contains('недопустим')) {
        setState(() => _nameStatus = _NameAvailability.inappropriate);
        return;
      }
      setState(() => _nameStatus = _NameAvailability.idle);
    } catch (_) {
      if (!mounted || _name.text.trim() != name) return;
      setState(() => _nameStatus = _NameAvailability.idle);
    }
  }

  void _onNicknameChanged() {
    _nicknameDebounce?.cancel();
    final nickname = _normalizedNickname;
    setState(() {
      _nicknameSuggestions = NicknameSuggestions.suggestNicknames(nickname);
    });
    if (_isLogin || !isValidNicknameFormat(nickname)) {
      setState(() => _nicknameStatus = _NicknameAvailability.idle);
      return;
    }
    setState(() => _nicknameStatus = _NicknameAvailability.checking);
    _nicknameDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_checkNickname(nickname));
    });
  }

  void _applyNicknameSuggestion(String suggestion) {
    _nickname.text = suggestion;
    _nickname.selection = TextSelection.collapsed(offset: suggestion.length);
    _onNicknameChanged();
  }

  Future<void> _checkNickname(String nickname) async {
    try {
      final forEmail = _nicknameAvailabilityEmail;
      final available = await context.read<ApiClient>().checkNicknameAvailable(
            nickname,
            forEmail: forEmail,
          );
      if (!mounted || _normalizedNickname != nickname) return;
      final reserved = _isOwnPendingNickname;
      setState(
        () => _nicknameStatus = (available || reserved)
            ? _NicknameAvailability.available
            : _NicknameAvailability.taken,
      );
    } on DioException catch (e) {
      if (!mounted || _normalizedNickname != nickname) return;
      final failure = FailureMapper.from(e);
      if (failure is ValidationFailure &&
          failure.message.contains('недопустим')) {
        setState(() => _nicknameStatus = _NicknameAvailability.inappropriate);
        return;
      }
      setState(() => _nicknameStatus = _NicknameAvailability.idle);
    } catch (_) {
      if (!mounted || _normalizedNickname != nickname) return;
      setState(() => _nicknameStatus = _NicknameAvailability.idle);
    }
  }

  Future<void> _checkEmail(String email) async {
    try {
      final result =
          await context.read<ApiClient>().checkEmailAvailable(email);
      if (!mounted || _email.text.trim().toLowerCase() != email) return;
      setState(() {
        if (result.available || _isOwnPendingEmail) {
          _emailStatus = _EmailAvailability.available;
        } else {
          _emailStatus = _EmailAvailability.taken;
        }
      });
    } catch (_) {
      if (!mounted || _email.text.trim().toLowerCase() != email) return;
      setState(() => _emailStatus = _EmailAvailability.idle);
    }
  }

  String? get _nicknameAvailabilityEmail {
    if (_isLogin) return null;
    final pending = _pendingEmail?.trim().toLowerCase();
    if (pending != null && pending.isNotEmpty) return pending;
    final draft = _email.text.trim().toLowerCase();
    return draft.isNotEmpty ? draft : null;
  }

  bool get _isOwnPendingNickname =>
      _registrationPending &&
      _registeredNickname != null &&
      _normalizedNickname == _registeredNickname;

  bool get _isOwnPendingEmail =>
      _registrationPending &&
      _pendingEmail != null &&
      _email.text.trim().toLowerCase() == _pendingEmail!.trim().toLowerCase();

  bool get _registrationDraftChanged {
    if (!_registrationPending) return true;
    final email = _email.text.trim().toLowerCase();
    return email != (_pendingEmail ?? '') ||
        _name.text.trim() != (_registeredName ?? '') ||
        _normalizedNickname != (_registeredNickname ?? '') ||
        _password.text != (_registeredPassword ?? '');
  }

  void _backRegisterStep({bool editFromCode = false}) {
    if (_registerStep <= 0) return;
    setState(() {
      _registerStep = editFromCode ? 0 : _registerStep - 1;
      _error = null;
      _notice = null;
    });
    if (_registerStep == 0) {
      if (_isOwnPendingNickname) {
        setState(() => _nicknameStatus = _NicknameAvailability.available);
      } else {
        _refreshNicknameAvailability();
      }
      _refreshNameValidity();
    } else if (_registerStep == 1) {
      _refreshEmailAvailability();
    }
  }

  void _refreshNicknameAvailability() {
    final nickname = _normalizedNickname;
    setState(() {
      _nicknameSuggestions = NicknameSuggestions.suggestNicknames(nickname);
    });
    if (_isOwnPendingNickname) {
      setState(() => _nicknameStatus = _NicknameAvailability.available);
      return;
    }
    if (!isValidNicknameFormat(nickname)) {
      setState(() => _nicknameStatus = _NicknameAvailability.idle);
      return;
    }
    setState(() => _nicknameStatus = _NicknameAvailability.checking);
    unawaited(_checkNickname(nickname));
  }

  void _refreshNameValidity() {
    final name = _name.text.trim();
    if (_validateName(name) != null) {
      setState(() => _nameStatus = _NameAvailability.idle);
      return;
    }
    setState(() => _nameStatus = _NameAvailability.checking);
    unawaited(_checkName(name));
  }

  void _refreshEmailAvailability() {
    final email = _email.text.trim().toLowerCase();
    if (_isOwnPendingEmail) {
      setState(() => _emailStatus = _EmailAvailability.available);
      return;
    }
    if (_validateEmail(email) != null) {
      setState(() => _emailStatus = _EmailAvailability.idle);
      return;
    }
    setState(() => _emailStatus = _EmailAvailability.checking);
    unawaited(_checkEmail(email));
  }

  Future<void> _submit() async {
    if (_loginVerificationPending) {
      await _submitCode();
      return;
    }

    if (!_isLogin && _registerStep == _codeStep) {
      await _submitCode();
      return;
    }

    if (!_isLogin && _registerStep < _summaryStep) {
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

    if (!_isLogin && _nicknameStatus == _NicknameAvailability.taken &&
        !_isOwnPendingNickname) {
      setState(() {
        _error = null;
        if (_registerStep != 0) _registerStep = 0;
      });
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
        Analytics.instance.authSuccess(register: false);
      } else {
        // Going back and tapping "Создать аккаунт" again must not hit register
        // twice — the account may already exist, waiting for the code.
        if (_registrationPending &&
            _pendingEmail == email &&
            !_registrationDraftChanged) {
          await _continuePendingRegistration(email);
          return;
        }
        final ticket = await auth.register(
          email,
          _password.text,
          name: _name.text.trim(),
          nickname: _normalizedNickname,
        );
        if (!mounted) return;
        _openCodeStep(email: email, ticket: ticket);
      }
    } catch (e) {
      if (!mounted) return;
      final failure = FailureMapper.from(e);
      if (_isLogin && failure is NotFoundFailure) {
        _switchToRegisterPreservingEmail();
        showAppSnackBar(context, failure.message);
        return;
      }
      if (failure is EmailNotVerifiedFailure) {
        await _startLoginVerification(email, notice: failure.message);
        return;
      }
      if (!_isLogin && failure is ConflictFailure) {
        final isNicknameConflict =
            failure.message.toLowerCase().contains('никнейм');
        if (isNicknameConflict) {
          setState(() {
            _error = null;
            _registerStep = 0;
            _nicknameStatus = _NicknameAvailability.taken;
            _offerSwitchToLogin = false;
            _offerContinueVerification = false;
          });
          return;
        }
        final resumed = await _tryResumePendingRegistration(email);
        if (resumed) return;
      }
      setState(() {
        _error = _authErrorMessage(failure, isLogin: _isLogin);
        _offerSwitchToLogin = !_isLogin && failure is ConflictFailure;
        _offerContinueVerification = false;
      });
    }
  }

  /// User went back from the code step and tapped "Создать аккаунт" again.
  Future<void> _continuePendingRegistration(String email) async {
    await AppHaptics.light();
    setState(() {
      _error = null;
      _offerSwitchToLogin = false;
      _offerContinueVerification = false;
    });
    await _resumeUnconfirmedSignup(
      email,
      notice: AppCopy.emailVerificationResumePending,
    );
  }

  /// Register returned 409 — often an unverified account from an earlier attempt.
  Future<bool> _tryResumePendingRegistration(String email) async {
    try {
      await _resumeUnconfirmedSignup(
        email,
        notice: AppCopy.emailVerificationResumePending,
      );
      return true;
    } catch (_) {
      // Stale API without resend/verify — the account may still exist.
    }

    final auth = context.read<AuthProvider>();
    try {
      await auth.login(email, _password.text);
      Analytics.instance.authSuccess(register: false);
      return true;
    } catch (e) {
      final failure = FailureMapper.from(e);
      if (failure is EmailNotVerifiedFailure) {
        setState(() {
          _registrationPending = true;
          _pendingEmail = email;
          _registerStep = _codeStep;
          _isLogin = false;
          _error = null;
          _notice = AppCopy.emailNotVerified;
          _offerSwitchToLogin = false;
          _offerContinueVerification = true;
        });
        Analytics.instance.registerStepViewed(_codeStep);
        return true;
      }
    }
    return false;
  }

  void _openCodeStep({
    required String email,
    required EmailVerificationTicket ticket,
  }) {
    _code.clear();
    setState(() {
      _pendingEmail = email;
      _registeredName = _name.text.trim();
      _registeredNickname = _normalizedNickname;
      _registeredPassword = _password.text;
      _registerStep = _codeStep;
      _registrationPending = true;
      _error = null;
      _notice = null;
      _offerSwitchToLogin = false;
      _offerContinueVerification = false;
    });
    Analytics.instance.registerStepViewed(_codeStep);
    _startResendCountdown(ticket.resendAvailableInSeconds);
  }

  /// Login with correct password on an account that was never confirmed.
  Future<void> _startLoginVerification(
    String email, {
    String? notice,
  }) async {
    _code.clear();
    setState(() {
      _loginVerificationPending = true;
      _pendingEmail = email;
      _error = null;
      _notice = notice ?? AppCopy.emailNotVerifiedLogin;
      _offerSwitchToLogin = false;
      _offerContinueVerification = false;
    });
    await _resendCode();
  }

  void _cancelLoginVerification() {
    _resendTimer?.cancel();
    setState(() {
      _loginVerificationPending = false;
      _pendingEmail = null;
      _code.clear();
      _notice = null;
      _error = null;
      _resendSeconds = 0;
    });
  }

  /// Register flow resume — keeps the registration wizard on the code step.
  Future<void> _resumeUnconfirmedSignup(
    String email, {
    String? notice,
  }) async {
    _code.clear();
    setState(() {
      _loginVerificationPending = false;
      _isLogin = false;
      _registerStep = _codeStep;
      _pendingEmail = email;
      _registrationPending = true;
      _error = null;
      _notice = notice ?? AppCopy.emailNotVerified;
      _offerSwitchToLogin = false;
      _offerContinueVerification = false;
    });
    Analytics.instance.registerStepViewed(_codeStep);
    await _resendCode();
  }

  void _startResendCountdown(int seconds) {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = seconds > 0 ? seconds : 0);
    if (_resendSeconds <= 0) return;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendSeconds -= 1;
        if (_resendSeconds <= 0) {
          _resendSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _submitCode() async {
    if (_submittingCode) return;
    final email = _pendingEmail ?? _email.text.trim().toLowerCase();
    final code = _code.text.trim();
    if (code.length != _codeLength) {
      setState(() => _error = AppCopy.emailVerificationCodeLength);
      return;
    }

    final auth = context.read<AuthProvider>();
    await AppHaptics.light();
    setState(() {
      _submittingCode = true;
      _error = null;
      _notice = null;
    });
    try {
      await auth.verifyEmail(email: email, code: code);
      Analytics.instance.authSuccess(register: true);
      if (mounted) {
        setState(() => _loginVerificationPending = false);
      }
    } catch (e) {
      if (!mounted) return;
      final failure = FailureMapper.from(e);
      setState(() {
        _code.clear();
        _error = failure is ConflictFailure
            ? AppCopy.emailAlreadyVerified
            : failure.message;
        _offerSwitchToLogin = failure is ConflictFailure;
      });
    } finally {
      if (mounted) setState(() => _submittingCode = false);
    }
  }

  Future<void> _resendCode() async {
    if (_resendSeconds > 0) return;
    final email = _pendingEmail ?? _email.text.trim().toLowerCase();
    setState(() {
      _error = null;
      _notice = null;
    });
    try {
      final ticket =
          await context.read<AuthProvider>().resendVerification(email);
      if (!mounted) return;
      setState(() => _notice = AppCopy.emailVerificationResent);
      _startResendCountdown(ticket.resendAvailableInSeconds);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = FailureMapper.from(e).message);
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
            _nameStatus == _NameAvailability.valid &&
            _nicknameStatus == _NicknameAvailability.available;
      case 1:
        return _validateEmail(_email.text) == null &&
            _validatePassword(_password.text) == null &&
            _emailStatus != _EmailAvailability.checking &&
            (_emailStatus == _EmailAvailability.available || _isOwnPendingEmail) &&
            _emailStatus != _EmailAvailability.pendingVerification;
      default:
        return true;
    }
  }

  String get _primaryActionLabel {
    if (_loginVerificationPending) return 'Подтвердить';
    if (_isLogin) return 'Войти';
    return switch (_registerStep) {
      0 || 1 => AppCopy.continueLabel,
      _summaryStep => 'Создать аккаунт',
      _ => 'Подтвердить',
    };
  }

  /// Only the wizard path collects name and nickname, so only it can step
  /// back from the code screen to fix them.
  bool get _canEditRegistrationData =>
      _validateName(_name.text) == null &&
      _validateNickname(_nickname.text) == null;

  bool get _canSubmit {
    if (_loginVerificationPending) {
      return _code.text.trim().length == _codeLength && !_submittingCode;
    }
    if (_isLogin) {
      return _validateEmail(_email.text) == null &&
          _validatePassword(_password.text) == null;
    }
    if (_registerStep == _codeStep) {
      return _code.text.trim().length == _codeLength && !_submittingCode;
    }
    if (_registerStep < _summaryStep) return _validateRegisterStep(_registerStep);
    if (!_agreed) return false;
    if (_validateName(_name.text) != null) return false;
    if (_validateNickname(_nickname.text) != null) return false;
    if (_nameStatus == _NameAvailability.checking ||
        _nameStatus == _NameAvailability.inappropriate) {
      return false;
    }
    if (_validateEmail(_email.text) != null) return false;
    if (_validatePassword(_password.text) != null) return false;
    if (_nicknameStatus == _NicknameAvailability.checking ||
        (_nicknameStatus == _NicknameAvailability.taken &&
            !_isOwnPendingNickname) ||
        _nicknameStatus == _NicknameAvailability.inappropriate) {
      return false;
    }
    if (_emailStatus == _EmailAvailability.checking ||
        (_emailStatus == _EmailAvailability.taken && !_isOwnPendingEmail) ||
        _emailStatus == _EmailAvailability.pendingVerification) {
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
    if (!_isLogin && _emailStatus == _EmailAvailability.taken) {
      return AppCopy.emailAlreadyRegistered;
    }
    if (!_isLogin && _emailStatus == _EmailAvailability.pendingVerification) {
      return AppCopy.emailPendingVerification;
    }
    return null;
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Введите имя';
    if (name.length < 2) return 'Имя должно быть длиннее';
    if (_nameStatus == _NameAvailability.inappropriate) {
      return 'Имя содержит недопустимые слова';
    }
    return null;
  }

  String? _validateNickname(String? value) {
    final nickname =
        (value ?? '').trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');
    if (nickname.isEmpty) return 'Введите никнейм';
    if (!isValidNicknameFormat(nickname)) {
      return nicknameFormatError;
    }
    if (_nicknameStatus == _NicknameAvailability.inappropriate) {
      return 'Никнейм содержит недопустимые слова';
    }
    if (_nicknameStatus == _NicknameAvailability.taken && !_isOwnPendingNickname) {
      return 'Никнейм уже занят';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (_isLogin) return PasswordStrengthAnalyzer.validateForLogin(value);
    return PasswordStrengthAnalyzer.validateForRegister(value);
  }

  void _toggleMode() {
    _resendTimer?.cancel();
    setState(() {
      _isLogin = !_isLogin;
      _loginVerificationPending = false;
      _registerStep = 0;
      _error = null;
      _notice = null;
      _offerSwitchToLogin = false;
      _offerContinueVerification = false;
      _agreed = false;
      _resendSeconds = 0;
      _code.clear();
      _registrationPending = false;
      _pendingEmail = null;
      _registeredName = null;
      _registeredNickname = null;
      _registeredPassword = null;
      _nicknameStatus = _NicknameAvailability.idle;
      _nameStatus = _NameAvailability.idle;
      _emailStatus = _EmailAvailability.idle;
    });
  }

  void _switchToRegisterPreservingEmail() {
    _resendTimer?.cancel();
    setState(() {
      _isLogin = false;
      _loginVerificationPending = false;
      _registerStep = 1;
      _error = null;
      _notice = null;
      _offerSwitchToLogin = false;
      _offerContinueVerification = false;
      _agreed = false;
      _resendSeconds = 0;
      _code.clear();
      _registrationPending = false;
      _pendingEmail = null;
      _registeredName = null;
      _registeredNickname = null;
      _registeredPassword = null;
      _nicknameStatus = _NicknameAvailability.idle;
      _nameStatus = _NameAvailability.idle;
      _emailStatus = _EmailAvailability.available;
    });
  }

  void _switchToLoginPreservingEmail() {
    _resendTimer?.cancel();
    setState(() {
      _isLogin = true;
      _loginVerificationPending = false;
      _registerStep = 0;
      _error = null;
      _notice = null;
      _offerSwitchToLogin = false;
      _offerContinueVerification = false;
      _agreed = false;
      _resendSeconds = 0;
      _code.clear();
      _registrationPending = false;
      _pendingEmail = null;
      _registeredName = null;
      _registeredNickname = null;
      _registeredPassword = null;
      _nicknameStatus = _NicknameAvailability.idle;
      _nameStatus = _NameAvailability.idle;
      _emailStatus = _EmailAvailability.idle;
    });
  }

  Future<void> _continueEmailVerificationFromRegister() async {
    final email = _email.text.trim().toLowerCase();
    if (_validateEmail(email) != null) return;
    await _resumeUnconfirmedSignup(
      email,
      notice: AppCopy.emailPendingVerification,
    );
  }

  String? get _emailHelper {
    if (_isLogin || _registerStep != 1) return null;
    return switch (_emailStatus) {
      _EmailAvailability.checking => 'Проверяем email…',
      _EmailAvailability.available => 'Email свободен',
      _EmailAvailability.taken => AppCopy.emailAlreadyRegistered,
      _EmailAvailability.pendingVerification => AppCopy.emailPendingVerification,
      _EmailAvailability.idle => null,
    };
  }

  AuthFieldHintTone get _emailHintTone => switch (_emailStatus) {
        _EmailAvailability.checking => AuthFieldHintTone.loading,
        _EmailAvailability.available => AuthFieldHintTone.positive,
        _EmailAvailability.taken => AuthFieldHintTone.negative,
        _EmailAvailability.pendingVerification => AuthFieldHintTone.neutral,
        _EmailAvailability.idle => AuthFieldHintTone.neutral,
      };

  String? get _nameHelper {
    if (_isLogin || _registerStep != 0) return null;
    return switch (_nameStatus) {
      _NameAvailability.checking => 'Проверяем имя…',
      _NameAvailability.inappropriate => 'Имя содержит недопустимые слова',
      _NameAvailability.valid || _NameAvailability.idle => null,
    };
  }

  AuthFieldHintTone get _nameHintTone => switch (_nameStatus) {
        _NameAvailability.checking => AuthFieldHintTone.loading,
        _NameAvailability.inappropriate => AuthFieldHintTone.negative,
        _NameAvailability.valid || _NameAvailability.idle =>
          AuthFieldHintTone.neutral,
      };

  String? get _nicknameHelper {
    if (_isLogin) return null;
    return switch (_nicknameStatus) {
      _NicknameAvailability.checking => 'Проверяем никнейм…',
      _NicknameAvailability.available =>
        _isOwnPendingNickname ? 'Ваш текущий никнейм' : 'Никнейм свободен',
      _NicknameAvailability.taken => 'Никнейм уже занят',
      _NicknameAvailability.inappropriate => 'Никнейм содержит недопустимые слова',
      _NicknameAvailability.idle => nicknameFormatHint,
    };
  }

  AuthFieldHintTone get _nicknameHintTone => switch (_nicknameStatus) {
        _NicknameAvailability.checking => AuthFieldHintTone.loading,
        _NicknameAvailability.available => AuthFieldHintTone.positive,
        _NicknameAvailability.taken ||
        _NicknameAvailability.inappropriate =>
          AuthFieldHintTone.negative,
        _NicknameAvailability.idle => AuthFieldHintTone.neutral,
      };

  String get _heroTitle {
    if (_loginVerificationPending) return 'Подтвердите почту';
    if (_isLogin) return 'С возвращением';
    return switch (_registerStep) {
      0 => 'Как вас представить',
      1 => 'Контакты и доступ',
      _summaryStep => 'Почти готово',
      _ => 'Подтвердите почту',
    };
  }

  String get _heroSubtitle {
    if (_loginVerificationPending) {
      return 'Отправили код из 6 цифр на ${_pendingEmail ?? _email.text.trim()}. '
          'Аккаунт уже создан — осталось подтвердить почту, чтобы войти.';
    }
    if (_isLogin) {
      return 'Продолжите привычки и общение в команде.';
    }
    return switch (_registerStep) {
      0 => 'Имя видно команде. Никнейм уникален — по нему найдут друзья. $nicknameFormatHint',
      1 => 'Email для входа. Пароль проверим на силу — слабый не пропустим.',
      _summaryStep =>
        'Проверьте данные и примите условия — затем отправим код на почту.',
      _ => 'Отправили код из 6 цифр на ${_pendingEmail ?? 'вашу почту'}. '
          'Введите его — так мы убедимся, что почта ваша.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().loading;

    return AuthPageShell(
      loading: loading,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthHeroBanner(
                compact: _isLogin || _loginVerificationPending,
                title: _heroTitle,
                subtitle: _heroSubtitle,
                badge: (_isLogin || _loginVerificationPending) ? null : 'Регистрация',
              ),
              const SizedBox(height: AppSpacing.lg),
              if (!_isLogin && !_loginVerificationPending) ...[
                AuthRegisterStepper(step: _registerStep),
                const SizedBox(height: AppSpacing.lg),
              ],
              AuthFormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      if (_nameHelper != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        AuthFieldHint(
                          text: _nameHelper!,
                          tone: _nameHintTone,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      PrimeTextField(
                        key: const ValueKey('auth-register-nickname'),
                        controller: _nickname,
                        label: 'Никнейм',
                        icon: Icons.alternate_email,
                        keyboardType: TextInputType.visiblePassword,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        autocorrect: false,
                        enableSuggestions: false,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                          LengthLimitingTextInputFormatter(
                            NicknameSuggestions.maxLength,
                          ),
                        ],
                        validator: _validateNickname,
                      ),
                      if (_nicknameHelper != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        AuthFieldHint(
                          text: _nicknameHelper!,
                          tone: _nicknameHintTone,
                        ),
                      ],
                      if (_nicknameSuggestions.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Идеи:',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                            for (final suggestion in _nicknameSuggestions)
                              ActionChip(
                                label: Text('@$suggestion'),
                                onPressed: () =>
                                    _applyNicknameSuggestion(suggestion),
                              ),
                            ActionChip(
                              label: const Icon(Icons.refresh_rounded, size: 16),
                              onPressed: () {
                                setState(() {
                                  _nicknameSuggestions =
                                      NicknameSuggestions.suggestNicknames(
                                    _normalizedNickname,
                                  );
                                });
                              },
                            ),
                          ],
                        ),
                      ],
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
                      if (_emailHelper != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AuthFieldHint(
                          text: _emailHelper!,
                          tone: _emailHintTone,
                        ),
                      ],
                      if (_emailStatus == _EmailAvailability.pendingVerification) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AppSecondaryButton(
                          label: AppCopy.continueEmailVerification,
                          onPressed: _continueEmailVerificationFromRegister,
                        ),
                      ],
                      if (_emailStatus == _EmailAvailability.taken) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AppSecondaryButton(
                          label: AppCopy.switchToLogin,
                          onPressed: _switchToLoginPreservingEmail,
                        ),
                      ],
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
                    if (_loginVerificationPending) ...[
                      AppCodeField(
                        key: const ValueKey('auth-login-code'),
                        controller: _code,
                        length: _codeLength,
                        onCompleted: (_) => unawaited(_submitCode()),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AuthFieldHint(
                        text: _resendSeconds > 0
                            ? AppCopy.emailVerificationResendIn(_resendSeconds)
                            : 'Письма нет? Проверьте папку «Спам» '
                                'или отправьте код снова.',
                        tone: _resendSeconds > 0
                            ? AuthFieldHintTone.loading
                            : AuthFieldHintTone.neutral,
                      ),
                      if (_resendSeconds == 0) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AppSecondaryButton(
                          label: 'Отправить код снова',
                          icon: Icons.refresh_rounded,
                          onPressed: _resendCode,
                        ),
                      ],
                    ],
                    if (_isLogin && !_loginVerificationPending) ...[
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
                    if (!_isLogin && _registerStep == _summaryStep) ...[
                      AuthRegisterSummary(
                        name: _name.text.trim(),
                        nickname: _normalizedNickname,
                        email: _email.text.trim().toLowerCase(),
                      ),
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
                              color: context.prime.inkSecondary,
                            ),
                            children: [
                              const TextSpan(text: 'Я принимаю '),
                              TextSpan(
                                text: 'пользовательское соглашение',
                                style: TextStyle(
                                  color: context.prime.brandSoft,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: _termsRecognizer,
                              ),
                              const TextSpan(text: ' и '),
                              TextSpan(
                                text: 'политику конфиденциальности',
                                style: TextStyle(
                                  color: context.prime.brandSoft,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: _privacyRecognizer,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (!_isLogin && _registerStep == _codeStep) ...[
                      AppCodeField(
                        key: const ValueKey('auth-register-code'),
                        controller: _code,
                        length: _codeLength,
                        onCompleted: (_) => unawaited(_submitCode()),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AuthFieldHint(
                        text: _resendSeconds > 0
                            ? AppCopy.emailVerificationResendIn(_resendSeconds)
                            : 'Письма нет? Проверьте папку «Спам» '
                                'или отправьте код снова.',
                        tone: _resendSeconds > 0
                            ? AuthFieldHintTone.loading
                            : AuthFieldHintTone.neutral,
                      ),
                      if (_resendSeconds == 0) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AppSecondaryButton(
                          label: 'Отправить код снова',
                          icon: Icons.refresh_rounded,
                          onPressed: _resendCode,
                        ),
                      ],
                    ],
                    if (_notice != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AuthFieldHint(
                        text: _notice!,
                        tone: AuthFieldHintTone.positive,
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AppInlineError(message: _error!),
                    ],
                    if (_offerSwitchToLogin) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AppSecondaryButton(
                        label: AppCopy.switchToLogin,
                        icon: Icons.login_rounded,
                        onPressed: _switchToLoginPreservingEmail,
                      ),
                    ],
                    if (_offerContinueVerification) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AppSecondaryButton(
                        label: AppCopy.continueVerification,
                        icon: Icons.mark_email_read_outlined,
                        onPressed: () => unawaited(
                          _resumeUnconfirmedSignup(
                            _pendingEmail ?? _email.text.trim().toLowerCase(),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    AppPrimaryButton(
                      label: _primaryActionLabel,
                      onPressed: _canSubmit ? _submit : null,
                    ),
                    if (!_isLogin &&
                        !_loginVerificationPending &&
                        _registerStep > 0 &&
                        (_registerStep != _codeStep ||
                            _canEditRegistrationData)) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AuthFooterLink(
                        label: _registerStep == _codeStep
                            ? 'Изменить данные'
                            : AppCopy.back,
                        onPressed: () => _backRegisterStep(
                          editFromCode: _registerStep == _codeStep,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_loginVerificationPending) ...[
                AuthFooterLink(
                  label: 'Вернуться ко входу',
                  onPressed: _cancelLoginVerification,
                ),
              ] else
                AuthFooterLink(
                  label: _isLogin
                      ? 'Нет аккаунта? Создать'
                      : 'Уже есть аккаунт? Войти',
                  onPressed: _toggleMode,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
