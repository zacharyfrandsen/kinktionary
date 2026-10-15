import 'package:flutter/material.dart';

import '../data_store.dart';
import '../models.dart';
import 'term_detail_screen.dart';

class GlossaryScreen extends StatefulWidget {
  final DataStore store;
  const GlossaryScreen({super.key, required this.store});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  String query = '';
  String? category;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final results = widget.store.search(query, category: category);
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SearchBar(
                  hintText: 'Search terms…',
                  leading: const Icon(Icons.search),
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: const Text('All'),
                        selected: category == null,
                        onSelected: (_) => setState(() => category = null),
                      ),
                    ),
                    for (final c in widget.store.categories)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(c),
                          selected: category == c,
                          onSelected: (_) => setState(() => category = c),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? const Center(
                        child: Card(
                          margin: EdgeInsets.all(24),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No matching terms.'),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, i) =>
                            TermTile(term: results[i], store: widget.store),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TermTile extends StatelessWidget {
  final Term term;
  final DataStore store;
  const TermTile({super.key, required this.term, required this.store});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        title: Text(term.name),
        subtitle: Text(term.short, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: store.isBookmarked(term.id)
            ? Icon(Icons.bookmark, color: Theme.of(context).colorScheme.primary)
            : null,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => TermDetailScreen(store: store, termId: term.id),
        )),
      ),
    );
  }
}
