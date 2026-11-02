import 'package:flutter/material.dart';

import '../theme.dart';
import 'definition_body.dart';

/// The one safety-note treatment in the app: the same surface as a definition
/// card, white type, and a yellow outline.
///
/// Every screen that shows a term's safety note uses this, so a note can't
/// drift back to an old colour scheme in one place and not another.
class SafetyNoteCard extends StatelessWidget {
  const SafetyNoteCard({
    super.key,
    required this.note,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
  });

  final String note;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: margin,
      color: AppPalette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppPalette.safety, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.health_and_safety_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  'SAFETY NOTE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DefinitionBody(
              text: note,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.55,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
