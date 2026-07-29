import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../design/tokens.dart';
import '../../design/typography.dart';

/// Checkbox with optional rich/plain label and ≥48dp tap area.
///
/// Internals delegate to Forui [FCheckbox] when a theme is present; public API
/// stays identical so call sites and tests do not change.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.child,
  });

  final bool value;
  final ValueChanged<bool?>? onChanged;
  final String? label;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final labelWidget = child ??
        (label == null
            ? null
            : Text(
                label!,
                style: AppTypography.bodySecondary.copyWith(
                  fontSize: 13,
                  height: 1.35,
                ),
              ));

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppControlHeights.iconButton),
      child: FCheckbox(
        value: value,
        onChange: onChanged == null
            ? null
            : (checked) => onChanged!(checked),
        enabled: onChanged != null,
        label: labelWidget,
      ),
    );
  }
}
