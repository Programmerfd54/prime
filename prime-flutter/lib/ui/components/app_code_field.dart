import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/theme/prime_theme_context.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';

/// One-time code input rendered as separate cells.
///
/// A single transparent [TextField] sits on top of the cells so system
/// autofill, paste and backspace behave exactly like a normal field.
class AppCodeField extends StatefulWidget {
  const AppCodeField({
    super.key,
    required this.controller,
    this.length = 6,
    this.focusNode,
    this.enabled = true,
    this.autofocus = true,
    this.onCompleted,
  });

  final TextEditingController controller;
  final int length;
  final FocusNode? focusNode;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onCompleted;

  @override
  State<AppCodeField> createState() => _AppCodeFieldState();
}

class _AppCodeFieldState extends State<AppCodeField> {
  late FocusNode _focus;
  var _ownedFocus = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    if (widget.focusNode == null) {
      _ownedFocus = true;
      _focus = FocusNode();
    } else {
      _focus = widget.focusNode!;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    if (_ownedFocus) _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    return ListenableBuilder(
      listenable: _focus,
      builder: (context, _) {
        final focused = _focus.hasFocus;
        return Stack(
          children: [
            Row(
              children: [
                for (var i = 0; i < widget.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _CodeCell(
                      digit: i < code.length ? code[i] : '',
                      active: focused &&
                          (i == code.length ||
                              (i == widget.length - 1 &&
                                  code.length == widget.length)),
                    ),
                  ),
                ],
              ],
            ),
            Positioned.fill(
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                autocorrect: false,
                enableSuggestions: false,
                enableInteractiveSelection: false,
                showCursor: false,
                cursorColor: Colors.transparent,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                // The real digits are drawn by the cells underneath.
                style: const TextStyle(
                  color: Colors.transparent,
                  fontSize: 1,
                  height: 1,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) {
                  if (value.length == widget.length) {
                    widget.onCompleted?.call(value);
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CodeCell extends StatelessWidget {
  const _CodeCell({required this.digit, required this.active});

  final String digit;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final filled = digit.isNotEmpty;
    return AnimatedContainer(
      duration: AppDurations.fast,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? p.brandContainer : p.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: active ? p.brand : p.hairline,
          width: active ? 1.5 : 1,
        ),
        boxShadow: active ? AppGlow.violet(opacity: 0.18) : null,
      ),
      child: Text(
        digit,
        style: AppTypography.title1.copyWith(
          color: filled ? p.ink : p.inkMuted,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
