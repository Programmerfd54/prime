import 'package:flutter/material.dart';

import '../../../design/typography.dart';

/// Parses *italic* segments inside editorial headlines.
class EditorialTitleText extends StatelessWidget {
  const EditorialTitleText({
    super.key,
    required this.text,
    this.style,
    this.italicStyle,
    this.color = Colors.white,
    this.maxLines = 2,
  });

  final String text;
  final TextStyle? style;
  final TextStyle? italicStyle;
  final Color color;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final base = (style ?? AppTypography.titleSerif).copyWith(color: color);
    final italic =
        (italicStyle ?? AppTypography.serifItalic).copyWith(color: color);
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*([^*]+)\*');
    var last = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > last) {
        spans.add(
            TextSpan(text: text.substring(last, match.start), style: base));
      }
      spans.add(TextSpan(text: match.group(1), style: italic));
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: base));
    }
    return Text.rich(
      TextSpan(
        children: spans.isEmpty ? [TextSpan(text: text, style: base)] : spans,
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
