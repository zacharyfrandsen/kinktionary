import 'package:flutter/material.dart';

import '../data_store.dart';
import '../widgets/back_to_top.dart';
import 'glossary_screen.dart';

class SavedScreen extends StatefulWidget {
  final DataStore store;
  const SavedScreen({super.key, required this.store});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  DataStore get store => widget.store;
  final _backToTop = BackToTopController();
  String _query = '';

  @override
  void dispose() {
    _backToTop.dispose();
    super.dispose();
  }

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
        final saved = store.search(_query, savedOnly: true);
        final hasAnySaved = store.bookmarkedTerms.isNotEmpty;
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
                    if (hasAnySaved)
                      IconButton(
                        tooltip: 'Clear all saved data',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmClear(context),
                      ),
                  ],
                ),
              ),
              if (hasAnySaved)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SearchBar(
                    hintText: 'Search saved terms and notes…',
                    leading: const Icon(Icons.search),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              Expanded(
                child: Stack(
                  children: [
                    if (saved.isEmpty)
                      Center(
                        child: Card(
                          margin: const EdgeInsets.all(24),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              hasAnySaved
                                  ? 'No saved terms match your search.'
                                  : 'Bookmark terms from the glossary and they will '
                                      'show up here. Everything here is private to you.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        controller: _backToTop.scroll,
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: saved.length,
                        itemBuilder: (context, i) =>
                            TermTile(term: saved[i], store: store),
                      ),
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: BackToTopButton(
                        controller: _backToTop,
                        heroTag: 'savedBackToTop',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
