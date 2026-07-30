import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../design/theme/prime_theme_context.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';

/// Premium text field — tonal fill, leading icon, accent focus ring.
///
/// Keeps [FormField] value in sync with [controller] so autofill / programmatic
/// prefills validate correctly (not against a stale null FormField value).
class PrimeTextField extends StatefulWidget {
  const PrimeTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.minLines,
    this.obscureText = false,
    this.suffixIcon,
    this.enabled = true,
    this.autofillHints,
    this.inputFormatters,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.light = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final int? minLines;
  final bool obscureText;
  final Widget? suffixIcon;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final bool autocorrect;
  final bool enableSuggestions;
  final bool light;

  @override
  State<PrimeTextField> createState() => _PrimeTextFieldState();
}

class _PrimeTextFieldState extends State<PrimeTextField> {
  late FocusNode _focus;
  var _ownedFocus = false;
  FormFieldState<String>? _fieldState;
  var _syncScheduled = false;

  void _onControllerChanged() => _syncFormValue();

  /// [FormField.didChange] calls [FormState.setState]. Never invoke it while
  /// the tree is building / laying out (e.g. from [didUpdateWidget]).
  void _syncFormValue() {
    final state = _fieldState;
    if (state == null) return;
    if (state.value == widget.controller.text) return;

    final phase = SchedulerBinding.instance.schedulerPhase;
    final safe = phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks;
    if (safe) {
      _applyFormValue();
      return;
    }
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback(_onPostFrameSync);
  }

  void _onPostFrameSync(Duration _) {
    _syncScheduled = false;
    if (!mounted) return;
    _applyFormValue();
  }

  void _applyFormValue() {
    final state = _fieldState;
    if (state == null || !mounted) return;
    final text = widget.controller.text;
    if (state.value != text) {
      state.didChange(text);
    }
  }

  void _attachFocus(FocusNode node) {
    _focus = node;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    if (widget.focusNode == null) {
      _ownedFocus = true;
      _attachFocus(FocusNode());
    } else {
      _attachFocus(widget.focusNode!);
    }
  }

  @override
  void didUpdateWidget(PrimeTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _syncFormValue();
    }
    if (oldWidget.focusNode == widget.focusNode) return;

    if (_ownedFocus) {
      _focus.dispose();
    }

    if (widget.focusNode == null) {
      _ownedFocus = true;
      _attachFocus(FocusNode());
    } else {
      _ownedFocus = false;
      _attachFocus(widget.focusNode!);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    // Drop pending form sync so it cannot touch a defunct FormField.
    _syncScheduled = false;
    _fieldState = null;
    if (_ownedFocus) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild on focus via ListenableBuilder — never setState from a FocusNode
    // listener (FocusManager can notify after this State is disposed).
    return ListenableBuilder(
      listenable: _focus,
      builder: (context, _) {
        final focused = _focus.hasFocus;
        final p = context.prime;
        final fill = widget.light
            ? AppColors.surfaceLightWarm
            : p.surfaceSoft;
        final labelColor = widget.light
            ? (focused ? AppColors.primaryDeep : AppColors.textOnLightMuted)
            : (focused ? p.brandSoft : p.inkMuted);
        final textColor =
            widget.light ? AppColors.textOnLight : p.ink;
        final borderColor = focused
            ? p.brand
            : (widget.light ? AppColors.borderOnLight : p.hairline);

        return FormField<String>(
          initialValue: widget.controller.text,
          validator: (value) =>
              widget.validator?.call(value ?? widget.controller.text),
          builder: (state) {
            _fieldState = state;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  child: AnimatedContainer(
                    duration: AppDurations.fast,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      border: Border.all(color: borderColor, width: 1.5),
                      boxShadow: focused
                          ? [
                              BoxShadow(
                                color: p.brand.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      enabled: widget.enabled,
                      keyboardType: widget.keyboardType,
                      textInputAction: widget.textInputAction,
                      obscureText: widget.obscureText,
                      maxLines: widget.obscureText ? 1 : widget.maxLines,
                      minLines: widget.minLines,
                      autocorrect: widget.autocorrect,
                      enableSuggestions: widget.enableSuggestions,
                      autofillHints: widget.autofillHints,
                      inputFormatters: widget.inputFormatters,
                      style: AppTypography.body.copyWith(color: textColor),
                      onChanged: (v) {
                        state.didChange(v);
                        widget.onChanged?.call(v);
                      },
                      decoration: InputDecoration(
                        labelText: widget.label,
                        hintText: widget.hint,
                        labelStyle:
                            AppTypography.caption.copyWith(color: labelColor),
                        floatingLabelStyle: AppTypography.caption.copyWith(
                          color: labelColor,
                          fontWeight: FontWeight.w600,
                        ),
                        hintStyle: AppTypography.bodySecondary.copyWith(
                          color: widget.light
                              ? AppColors.textOnLightMuted
                              : p.inkMuted,
                        ),
                        prefixIcon: widget.icon == null
                            ? null
                            : Icon(
                                widget.icon,
                                color: focused ? p.brand : p.inkMuted,
                              ),
                        suffixIcon: widget.suffixIcon,
                        filled: true,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                      ),
                    ),
                  ),
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xs,
                      AppSpacing.xxs,
                      AppSpacing.xs,
                      0,
                    ),
                    child: Text(
                      state.errorText!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
