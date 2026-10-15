import 'package:flutter/material.dart';

import '../data_store.dart';
import 'glossary_screen.dart';

class SavedScreen extends StatelessWidget {
  final DataStore store;
  const SavedScreen({super.key, required this.store});

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear saved data?'),
        content: const Text(
            'This removes all bookmarks and notes from this device. It can\'t be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) await store.clearPersonalData();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final saved = store.bookmarkedTerms;
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Saved',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    if (saved.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear all saved data',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmClear(context),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: saved.isEmpty
                    ? const Center(
                        child: Card(
                          margin: EdgeInsets.all(24),
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'Bookmark terms from the glossary and they will '
                              'show up here. Everything stays private on your device.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: saved.length,
                        itemBuilder: (context, i) =>
                            TermTile(term: saved[i], store: store),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
