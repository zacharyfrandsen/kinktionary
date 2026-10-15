import 'package:flutter/material.dart';

import '../data_store.dart';

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
            Card(
              child: ExpansionTile(
                initiallyExpanded: i == 0,
                leading: CircleAvatar(
                  radius: 14,
                  child: Text('${i + 1}', style: const TextStyle(fontSize: 13)),
                ),
                title: Text(store.consent[i].title),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(store.consent[i].body)],
              ),
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
