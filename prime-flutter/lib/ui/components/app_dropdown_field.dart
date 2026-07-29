import 'package:flutter/material.dart';

import '../../design/tokens.dart';

class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.hint,
    this.validator,
    this.isExpanded = true,
    this.suffixIcon,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final String? hint;
  final FormFieldValidator<T>? validator;
  final bool isExpanded;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      isExpanded: isExpanded,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.elevatedSurface.withValues(alpha: 0.55),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
