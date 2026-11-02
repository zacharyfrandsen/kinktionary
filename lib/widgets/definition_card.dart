import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'definition_body.dart';

/// The one definition treatment in the app: a near-black card, a one-line
/// gloss as the lead, then the full text rendered as paragraphs.
///
/// Used by the term screen and by the path player, so stepping through a path
/// shows exactly the same definition layout as opening the term directly.
class DefinitionCard extends StatelessWidget {
  const DefinitionCard({
    super.key,
    required this.term,
    this.margin = EdgeInsets.zero,
  });

  final Term term;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = term.details;
    return Card(
      elevation: 0,
      margin: margin,
      color: AppPalette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'DEFINITION',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              term.short,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 18,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (details != null) ...[
              const SizedBox(height: 14),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 16),
              DefinitionBody(
                text: details,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                  color: const Color(0xFFFFFFFF),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
