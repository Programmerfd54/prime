import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/tokens.dart';
import 'app_icon_button.dart';

/// Search field with optional leading prefix and trailing search action.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.prefixText,
    this.onSubmitted,
    this.onSearch,
    this.searching = false,
    this.maxLength,
    this.keyboardType,
    this.textInputAction = TextInputAction.search,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? prefixText;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onSearch;
  final bool searching;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted ?? (_) => onSearch?.call(),
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              prefixText: prefixText,
              counterText: '',
              filled: true,
              fillColor: AppColors.elevatedSurface.withValues(alpha: 0.55),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ),
        if (onSearch != null) ...[
          const SizedBox(width: AppSpacing.xs),
          AppIconButton(
            tooltip: 'Искать',
            icon: Icons.search,
            filled: true,
            loading: searching,
            onPressed: searching ? null : onSearch,
          ),
        ],
      ],
    );
  }
}
