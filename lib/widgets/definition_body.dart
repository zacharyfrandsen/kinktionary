import 'package:flutter/material.dart';

/// Renders a definition body written in a small subset of Markdown:
///
///   * blank lines separate paragraphs
///   * lines starting with "- " or "• " become bullets
///   * **bold** and *italic* work inline
///
/// Keeping the source close to plain prose means the JSON stays easy to edit
/// by hand, while the screen still gets real typography: measured line
/// height, spacing between ideas and a bullet that hangs correctly when the
/// text wraps.
class DefinitionBody extends StatelessWidget {
  const DefinitionBody({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = style ?? theme.textTheme.bodyLarge ?? const TextStyle();
    final blocks = parseBlocks(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks)
          Padding(
            padding: EdgeInsets.only(bottom: block.bullet ? 8 : 12),
            child: block.bullet
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7, right: 10),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(child: _paragraph(block.text, base)),
                    ],
                  )
                : _paragraph(block.text, base),
          ),
      ],
    );
  }

  Widget _paragraph(String value, TextStyle base) => Text.rich(
        TextSpan(children: inlineSpans(value, base)),
        style: base,
      );

  /// Splits the body into paragraphs and bullets; wrapped lines inside a
  /// paragraph are joined back together with a space.
  static List<({bool bullet, String text})> parseBlocks(String raw) {
    final blocks = <({bool bullet, String text})>[];
    final paragraph = <String>[];

    void flush() {
      if (paragraph.isEmpty) return;
      blocks.add((bullet: false, text: paragraph.join(' ')));
      paragraph.clear();
    }

    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        flush();
        continue;
      }
      if (trimmed.startsWith('- ') || trimmed.startsWith('• ')) {
        flush();
        blocks.add((bullet: true, text: trimmed.substring(2).trim()));
        continue;
      }
      paragraph.add(trimmed);
    }
    flush();
    return blocks;
  }

  /// Applies **bold** and *italic* markers to a single block of text.
  static List<TextSpan> inlineSpans(String text, TextStyle base) {
    final spans = <TextSpan>[];
    var index = 0;
    for (final match in _emphasis.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }
      final raw = match.group(0)!;
      final bold = raw.startsWith('**');
      final marker = bold ? 2 : 1;
      spans.add(
        TextSpan(
          text: raw.substring(marker, raw.length - marker),
          style: TextStyle(
            fontWeight: bold ? FontWeight.w600 : null,
            fontStyle: bold ? null : FontStyle.italic,
          ),
        ),
      );
      index = match.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index)));
    }
    return spans;
  }

  static final RegExp _emphasis = RegExp(r'(\*\*[^*]+\*\*|\*[^*]+\*)');
}
