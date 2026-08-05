import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/auth/nickname_suggestions.dart';
import '../core/errors/failure_mapper.dart';
import '../data/api_client.dart';
import '../design/haptics.dart';
import '../design/routes.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../ui/kit/components/prime_content_card.dart';
import '../ui/kit/presentation/profile_surfaces.dart';
import '../l10n/copy.dart';
import '../providers/auth_provider.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../ui/components/app_dropdown_field.dart';
import '../ui/components/app_chip.dart';
import '../ui/components/app_inline_error.dart';
import '../ui/components/app_primary_button.dart';
import '../ui/components/app_textarea.dart';
import '../ui/components/editorial/app_auth_hero.dart';
import '../ui/components/prime_text_field.dart';
import '../ui/states/app_loading_state.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nickname = TextEditingController();
  final _about = TextEditingController();
  final _age = TextEditingController();
  final _nameFocus = FocusNode();
  final _nicknameFocus = FocusNode();
  final _aboutFocus = FocusNode();
  final _ageFocus = FocusNode();
  List<Map<String, dynamic>> _regions = [];
  String? _regionCode;
  bool _regionsLoading = true;
  bool _saving = false;
  bool _initialized = false;
  bool _autovalidate = false;
  bool _fromRegistration = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final user = context.read<AuthProvider>().user;
    _name.text = user?.name ?? '';
    _nickname.text = user?.nickname ?? '';
    _about.text = user?.about ?? '';
    _regionCode = user?.regionCode;
    _age.text = user?.age?.toString() ?? '';
    _fromRegistration =
        (_name.text.trim().isNotEmpty || _nickname.text.trim().isNotEmpty);
    _initialized = true;
    _about.addListener(() {
      if (mounted) setState(() {});
    });
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    try {
      final regions = await context.read<ApiClient>().listRegions();
      if (mounted) {
        setState(() {
          _regions = regions;
          if (_regionCode == null) {
            final legacyName = context.read<AuthProvider>().user?.city;
            for (final item in regions) {
              if (item['name'] == legacyName) {
                _regionCode = item['code'] as String;
                break;
              }
            }
          }
          _regionsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _regionsLoading = false;
          _error = FailureMapper.from(e).message;
        });
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _nickname.dispose();
    _about.dispose();
    _age.dispose();
    _nameFocus.dispose();
    _nicknameFocus.dispose();
    _aboutFocus.dispose();
    _ageFocus.dispose();
    super.dispose();
  }

  int get _aboutWordCount {
    final text = _about.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  Future<void> _save() async {
    setState(() => _autovalidate = true);
    if (!_formKey.currentState!.validate()) return;
    await AppHaptics.light();
    setState(() {
      _saving = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final selectedRegion = _regions.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['code'] == _regionCode,
          orElse: () => null,
        );
    try {
      final payload = <String, dynamic>{
        'name': _name.text.trim(),
        'nickname': _nickname.text.trim().replaceFirst(RegExp(r'^@'), ''),
        'about': _about.text.trim(),
        'region_code': _regionCode,
        'city': selectedRegion?['name'],
        'age': int.tryParse(_age.text),
      };
      final updated = await auth.api.updateMe(payload);
      await auth.applyUserUpdate(updated);
    } catch (e) {
      if (mounted) {
        setState(() => _error = FailureMapper.from(e).message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _requiredText(String? value, String message) {
    return value == null || value.trim().isEmpty ? message : null;
  }

  String? _validateAge(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Укажите возраст';
    final age = int.tryParse(text);
    if (age == null) return 'Введите число';
    if (age < 13 || age > 120) return 'Возраст от 13 до 120';
    return null;
  }

  String? _validateNickname(String? value) {
    final nickname = (value ?? '').trim().replaceFirst(RegExp(r'^@'), '');
    if (nickname.isEmpty) return 'Укажите никнейм';
    if (!isValidNicknameFormat(nickname)) {
      return nicknameFormatError;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final words = _aboutWordCount;
    final wordProgress = (words / 50).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: ProfileSurfaces.canvas,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Создание профиля', style: AppTypography.titleSerif),
        actions: [
          TextButton(
            onPressed: () => context.read<AuthProvider>().logout(),
            child: Text(
              'Выйти',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
      body: _saving
          ? const AppLoadingState(label: 'Сохранение…')
          : AmbientCanvas(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppBreakpoints.maxContentWidth,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: _autovalidate
                          ? AutovalidateMode.onUserInteraction
                          : AutovalidateMode.disabled,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AppAuthHero(
                            compact: true,
                            title: 'Расскажите о себе',
                            subtitle:
                                'Короткий профиль читает команда из 6 перед стартом. Поля можно уточнить позже.',
                          ),
                          if (_fromRegistration) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Из регистрации — можно изменить',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.primarySoft,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          PrimeContentCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                          PrimeTextField(
                            controller: _name,
                            focusNode: _nameFocus,
                            label: 'Имя',
                            icon: Icons.person_outline,
                            keyboardType: TextInputType.name,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            validator: (v) => _requiredText(v, 'Укажите имя'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          PrimeTextField(
                            controller: _nickname,
                            focusNode: _nicknameFocus,
                            label: 'Никнейм',
                            icon: Icons.alternate_email,
                            hint: 'По этому никнейму друзья смогут найти вас',
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
                          const SizedBox(height: AppSpacing.md),
                          AppTextarea(
                            controller: _about,
                            focusNode: _aboutFocus,
                            label: 'О себе',
                            hint:
                                'Например: люблю бег по утрам, работаю удалённо, хочу больше дисциплины',
                            helperText:
                                'Необязательно сейчас. Перед поиском команды — от 50 слов.',
                            minLines: 3,
                            maxLines: 5,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            child: LinearProgressIndicator(
                              value: wordProgress,
                              minHeight: 4,
                              backgroundColor: AppColors.borderStrong,
                              color: words >= 50
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            words >= 50
                                ? '$words слов — готово к поиску команды'
                                : '$words / 50 слов до поиска команды',
                            style: AppTypography.caption.copyWith(
                              color: words >= 50
                                  ? AppColors.success
                                  : AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              for (final prompt in const [
                                'Люблю утренние пробежки',
                                'Работаю удалённо',
                                'Хочу больше дисциплины',
                                'Читаю каждый день',
                              ])
                                AppChip(
                                  label: prompt,
                                  onTap: () {
                                    final current = _about.text.trim();
                                    _about.text = current.isEmpty
                                        ? prompt
                                        : '$current. $prompt';
                                    _about.selection = TextSelection.collapsed(
                                      offset: _about.text.length,
                                    );
                                    setState(() {});
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: AppDropdownField<String>(
                                  key: ValueKey(
                                      'region-${_regionCode ?? 'none'}-${_regions.length}'),
                                  value: _regions.any(
                                          (item) => item['code'] == _regionCode)
                                      ? _regionCode
                                      : null,
                                  label: 'Область',
                                  suffixIcon: _regionsLoading
                                      ? const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
                                      : null,
                                  items: _regions
                                      .map(
                                        (item) => DropdownMenuItem<String>(
                                          value: item['code'] as String,
                                          child: Text(
                                            item['name'] as String,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: _regionsLoading
                                      ? null
                                      : (value) =>
                                          setState(() => _regionCode = value),
                                  validator: (value) =>
                                      value == null ? 'Выберите область' : null,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: PrimeTextField(
                                  controller: _age,
                                  focusNode: _ageFocus,
                                  label: 'Возраст',
                                  icon: Icons.cake_outlined,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
                                  ],
                                  validator: _validateAge,
                                ),
                              ),
                            ],
                          ),
                          if (_error != null) AppInlineError(message: _error!),
                          const SizedBox(height: AppSpacing.xl),
                          AppPrimaryButton(
                            label: AppCopy.continueLabel,
                            onPressed: _save,
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
    );
  }
}
