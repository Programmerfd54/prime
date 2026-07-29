import 'package:flutter/material.dart';

import 'app_text_field.dart';

/// Multi-line text input built on [AppTextField].
class AppTextarea extends StatelessWidget {
  const AppTextarea({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.focusNode,
    this.minLines = 3,
    this.maxLines = 6,
    this.textInputAction = TextInputAction.newline,
    this.validator,
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final FocusNode? focusNode;
  final int minLines;
  final int maxLines;
  final TextInputAction textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: label,
      hint: hint,
      helperText: helperText,
      errorText: errorText,
      focusNode: focusNode,
      keyboardType: TextInputType.multiline,
      textInputAction: textInputAction,
      minLines: minLines,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
    );
  }
}
