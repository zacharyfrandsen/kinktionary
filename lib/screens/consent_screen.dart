import 'package:flutter/material.dart';

import '../data_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/definition_body.dart';

class ConsentScreen extends StatelessWidget {
  final DataStore store;
  const ConsentScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Safety & consent basics',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Read this first, and come back to it any time.',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          for (var i = 0; i < store.consent.length; i++)
            _ConsentTile(
              index: i + 1,
              topic: store.consent[i],
              initiallyExpanded: i == 0,
            ),
          const SizedBox(height: 8),
          Text(
            'This app is educational. It is not medical, legal or mental-health '
            'advice. If you or someone else is in danger, contact local '
            'emergency services.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// One numbered topic, in the same card as a definition and a safety note: a
/// near-black surface, a thin outline, and white body text.
class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.index,
    required this.topic,
    required this.initiallyExpanded,
  });

  final int index;
  final ConsentTopic topic;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: AppPalette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // The tile's own divider lines cut across the card's outline.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: _NumberBadge(index),
          iconColor: scheme.secondary,
          collapsedIconColor: scheme.onSurfaceVariant,
          title: Text(
            topic.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 20, 18),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DefinitionBody(
              text: topic.body,
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

/// The step number: the app's pink, filled, with the dark text that goes with
/// it. It was the purple primary, which read as a different palette.
class _NumberBadge extends StatelessWidget {
  const _NumberBadge(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.secondary,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: scheme.onSecondary,
        ),
      ),
    );
  }
}
