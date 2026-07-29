import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/security/password_strength.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import 'app_text_field.dart';

class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    super.key,
    required this.controller,
    this.label = 'Пароль',
    this.focusNode,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onChanged,
    this.showRequirements = false,
  });

  final TextEditingController controller;
  final String label;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final bool showRequirements;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted || !widget.showRequirements) return;
    setState(() {});
  }

  Color _barColor(PasswordStrength strength) => switch (strength) {
        PasswordStrength.veryWeak => AppColors.error,
        PasswordStrength.weak => AppColors.warning,
        PasswordStrength.medium => AppColors.focusBlue,
        PasswordStrength.strong => AppColors.success,
      };

  @override
  Widget build(BuildContext context) {
    final password = widget.controller.text;
    final result = PasswordStrengthAnalyzer.analyze(password);
    final accent = _barColor(result.strength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: widget.controller,
          label: widget.label,
          focusNode: widget.focusNode,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          validator: widget.validator,
          onChanged: widget.onChanged,
          obscureText: _obscured,
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'\s')),
          ],
          prefixIcon: Icon(
            Icons.lock_outline,
            color: AppColors.textSecondary,
          ),
          suffixIcon: IconButton(
            tooltip: _obscured ? 'Показать пароль' : 'Скрыть пароль',
            onPressed: () => setState(() => _obscured = !_obscured),
            icon: Icon(
              _obscured
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        if (widget.showRequirements) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: AnimatedContainer(
                    duration: AppDurations.fast,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      color: i < result.filledBars
                          ? accent
                          : AppColors.borderStrong,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            password.isEmpty ? 'Сила пароля' : result.label,
            style: AppTypography.caption.copyWith(
              color: password.isEmpty ? AppColors.textMuted : accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (result.hint != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              result.hint!,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ],
    );
  }
}
