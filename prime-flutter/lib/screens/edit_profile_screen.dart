import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/errors/failure_mapper.dart';
import '../core/profile/profile_preferences.dart';
import '../data/api_client.dart';
import '../design/prime/prime_toast_overlay.dart';
import '../design/routes.dart';
import '../design/theme/prime_theme_context.dart';
import '../design/tokens.dart';
import 'avatar_screen.dart';
import '../design/typography.dart';
import '../l10n/copy.dart';
import '../providers/auth_provider.dart';
import '../ui/components/app_dropdown_field.dart';
import '../ui/components/app_primary_button.dart';
import '../ui/components/app_snackbar.dart';
import '../ui/components/app_textarea.dart';
import '../ui/components/profile/app_avatar.dart';
import '../ui/components/settings/settings_presentation.dart';
import '../ui/kit/components/prime_content_card.dart';
import '../ui/components/prime_text_field.dart';

/// V5 dedicated profile edit screen with grouped fields and inline validation.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  List<Map<String, dynamic>> _regions = [];
  String? _regionCode;
  String? _preferredTimeLabel;
  String? _supportStyleLabel;
  bool _loadingRegions = true;
  bool _loadingPrefs = true;
  bool _saving = false;
  String? _nameError;
  String? _nicknameError;
  String? _aboutError;
  String? _ageError;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl.text = user?.name ?? '';
    _nicknameCtrl.text = user?.nickname ?? '';
    _aboutCtrl.text = user?.about ?? '';
    _ageCtrl.text = user?.age?.toString() ?? '';
    _regionCode = user?.regionCode;
    _loadRegions();
    _loadPreferences();
  }

  Future<void> _loadRegions() async {
    try {
      final regions = await context.read<ApiClient>().listRegions();
      if (mounted) {
        setState(() {
          _regions = regions;
          _loadingRegions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRegions = false);
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await context.read<ApiClient>().getPreferences();
      if (!mounted) return;
      final timeRaw =
          prefs[ProfilePreferences.preferredTimeOfDayKey] as String?;
      final supportRaw = prefs[ProfilePreferences.supportStyleKey] as String?;
      setState(() {
        _preferredTimeLabel = ProfilePreferences.preferredTimeLabel(timeRaw);
        _supportStyleLabel = ProfilePreferences.supportStyleLabel(supportRaw);
        _loadingPrefs = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _preferredTimeLabel = ProfilePreferences.timeOptions.first.label;
          _supportStyleLabel = ProfilePreferences.supportOptions.first.label;
          _loadingPrefs = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nicknameCtrl.dispose();
    _aboutCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    var ok = true;
    setState(() {
      _nameError = null;
      _nicknameError = null;
      _aboutError = null;
      _ageError = null;
      _formError = null;
      if (_nameCtrl.text.trim().isEmpty) {
        _nameError = 'Укажите имя';
        ok = false;
      }
      final nickname = _nicknameCtrl.text.trim().toLowerCase();
      if (nickname.length < 3) {
        _nicknameError = 'Никнейм минимум 3 символа';
        ok = false;
      }
      final words = _aboutCtrl.text
          .trim()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
      if (words < 3) {
        _aboutError = 'Минимум 3 слова — команда увидит вас в подборе';
        ok = false;
      }
      final age = int.tryParse(_ageCtrl.text.trim());
      if (_ageCtrl.text.trim().isNotEmpty &&
          (age == null || age < 16 || age > 99)) {
        _ageError = 'Возраст от 16 до 99';
        ok = false;
      }
    });
    return ok;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() {
      _saving = true;
      _formError = null;
    });
    final auth = context.read<AuthProvider>();
    try {
      final selected = _regions.cast<Map<String, dynamic>?>().firstWhere(
            (item) => item?['code'] == _regionCode,
            orElse: () => null,
          );
      final updated = await auth.api.updateMe({
        'name': _nameCtrl.text.trim(),
        'nickname': _nicknameCtrl.text.trim().toLowerCase(),
        'about': _aboutCtrl.text.trim(),
        'age': int.tryParse(_ageCtrl.text.trim()),
        'region_code': _regionCode,
        if (selected != null) 'city': selected['name'],
      });
      await auth.applyUserUpdate(updated);

      final timeValue =
          ProfilePreferences.timeValueForLabel(_preferredTimeLabel ?? '');
      final supportValue =
          ProfilePreferences.supportValueForLabel(_supportStyleLabel ?? '');
      if (timeValue != null || supportValue != null) {
        await auth.api.updatePreferences({
          if (timeValue != null)
            ProfilePreferences.preferredTimeOfDayKey: timeValue,
          if (supportValue != null)
            ProfilePreferences.supportStyleKey: supportValue,
        });
      }

      if (mounted) {
        showAppSnackBar(context, 'Профиль сохранён', variant: PrimeToastVariant.success);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _formError = FailureMapper.from(e).message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      backgroundColor: p.canvas,
      appBar: AppBar(
        title: const Text('Редактировать профиль'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: Column(
              children: [
                AppAvatar(
                  name: user?.name ?? '',
                  photoUrl: user?.photoUrl,
                  radius: 44,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    PrimeRoute.sharedAxis(builder: (_) => const AvatarScreen()),
                  ),
                  child: const Text('Изменить фото'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimeContentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Основное', style: AppTypography.title2.copyWith(color: p.ink)),
                const SizedBox(height: AppSpacing.md),
                PrimeTextField(
                  controller: _nameCtrl,
                  label: 'Имя',
                  icon: Icons.person_outline,
                ),
                if (_nameError != null) ...[
                  const SizedBox(height: 4),
                  Text(_nameError!, style: AppTypography.caption.copyWith(color: p.coral)),
                ],
                const SizedBox(height: AppSpacing.sm),
                PrimeTextField(
                  controller: _nicknameCtrl,
                  label: 'Никнейм',
                  icon: Icons.alternate_email_outlined,
                ),
                if (_nicknameError != null) ...[
                  const SizedBox(height: 4),
                  Text(_nicknameError!, style: AppTypography.caption.copyWith(color: p.coral)),
                ],
                const SizedBox(height: AppSpacing.sm),
                AppTextarea(
                  controller: _aboutCtrl,
                  label: 'О себе',
                  hint:
                      'Например: бегаю по утрам, работаю удалённо, поддержка — коротко и по делу',
                  helperText:
                      'Команда из 6 человек увидит этот текст перед стартом',
                  minLines: 3,
                  maxLines: 6,
                ),
                const SizedBox(height: AppSpacing.sm),
                const _AboutFieldGuide(),
                if (_aboutError != null) ...[
                  const SizedBox(height: 4),
                  Text(_aboutError!, style: AppTypography.caption.copyWith(color: p.coral)),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimeContentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Ритм и поддержка', style: AppTypography.title2.copyWith(color: p.ink)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Эти параметры отображаются в блоке «О себе»',
                  style: AppTypography.caption.copyWith(color: p.inkSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Время', style: AppTypography.caption.copyWith(color: p.inkSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.xs),
                if (_loadingPrefs)
                  const LinearProgressIndicator()
                else
                  SettingsChoiceChips(
                    options: ProfilePreferences.timeOptions
                        .map((e) => e.label)
                        .toList(),
                    selected: _preferredTimeLabel,
                    enabled: !_saving,
                    onSelected: (value) =>
                        setState(() => _preferredTimeLabel = value),
                  ),
                const SizedBox(height: AppSpacing.md),
                Text('Поддержка', style: AppTypography.caption.copyWith(color: p.inkSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.xs),
                if (!_loadingPrefs)
                  SettingsChoiceChips(
                    options: ProfilePreferences.supportOptions
                        .map((e) => e.label)
                        .toList(),
                    selected: _supportStyleLabel,
                    enabled: !_saving,
                    onSelected: (value) =>
                        setState(() => _supportStyleLabel = value),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimeContentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Детали', style: AppTypography.title2.copyWith(color: p.ink)),
                const SizedBox(height: AppSpacing.md),
                PrimeTextField(
                  controller: _ageCtrl,
                  label: 'Возраст',
                  icon: Icons.cake_outlined,
                  keyboardType: TextInputType.number,
                ),
                if (_ageError != null) ...[
                  const SizedBox(height: 4),
                  Text(_ageError!, style: AppTypography.caption.copyWith(color: p.coral)),
                ],
                const SizedBox(height: AppSpacing.sm),
                if (_loadingRegions)
                  const LinearProgressIndicator()
                else if (_regions.isNotEmpty)
                  AppDropdownField<String>(
                    value: _regions.any((r) => r['code'] == _regionCode)
                        ? _regionCode
                        : null,
                    label: 'Область',
                    items: [
                      for (final region in _regions)
                        DropdownMenuItem(
                          value: region['code'] as String?,
                          child: Text(region['name'] as String? ?? ''),
                        ),
                    ],
                    onChanged: (value) => setState(() => _regionCode = value),
                  ),
              ],
            ),
          ),
          if (_formError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_formError!, style: AppTypography.caption.copyWith(color: p.coral)),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppPrimaryButton(
            label: AppCopy.save,
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

/// Short hints for «О себе» — maps to profile fact chips (время / поддержка / формат).
class _AboutFieldGuide extends StatelessWidget {
  const _AboutFieldGuide();

  static const _items = [
    (
      label: 'Время',
      hint: 'Когда удобно действовать и отчитываться — утро, день или вечер.',
    ),
    (
      label: 'Поддержка',
      hint: 'Как мотивировать: мягко, строго или коротко и по делу.',
    ),
    (
      label: 'Формат',
      hint: 'Зависит от участия в команде — выбирается автоматически.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.brandContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: p.brand.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Что стоит упомянуть',
              style: AppTypography.caption.copyWith(
                color: p.inkSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final item in _items) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.label}: ',
                    style: AppTypography.caption.copyWith(
                      color: p.brandSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.hint,
                      style: AppTypography.caption.copyWith(color: p.inkSecondary),
                    ),
                  ),
                ],
              ),
              if (item != _items.last) const SizedBox(height: AppSpacing.xxs),
            ],
          ],
        ),
      ),
    );
  }
}
