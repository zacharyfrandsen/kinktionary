import 'package:flutter/material.dart';

import '../data_store.dart';
import '../models.dart';
import '../widgets/pattern_background.dart';
import 'term_detail_screen.dart';

class PathsScreen extends StatelessWidget {
  final DataStore store;
  const PathsScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Where would you like to begin?',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Pick a short path. Go at your own pace, and skip anything.',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          for (final p in store.paths)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(p.title),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${p.blurb}\n${p.termIds.length} terms'),
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => PathDetailScreen(store: store, path: p),
                )),
              ),
            ),
        ],
      ),
    );
  }
}

class PathDetailScreen extends StatelessWidget {
  final DataStore store;
  final LearningPath path;
  const PathDetailScreen({super.key, required this.store, required this.path});

  @override
  Widget build(BuildContext context) {
    final terms = [
      for (final id in path.termIds)
        if (store.termById(id) != null) store.termById(id)!,
    ];
    return PatternScaffold(
      appBar: AppBar(title: Text(path.title)),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(path.blurb,
                      style: Theme.of(context).textTheme.bodyLarge),
                ),
              ),
            ),
            for (var i = 0; i < terms.length; i++)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(terms[i].name),
                  subtitle: Text(terms[i].short),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) =>
                        TermDetailScreen(store: store, termId: terms[i].id),
                  )),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
