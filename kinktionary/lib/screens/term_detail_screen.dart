import 'package:flutter/material.dart';

import '../data_store.dart';
import '../widgets/pattern_background.dart';

class TermDetailScreen extends StatefulWidget {
  final DataStore store;
  final String termId;
  const TermDetailScreen({super.key, required this.store, required this.termId});

  @override
  State<TermDetailScreen> createState() => _TermDetailScreenState();
}

class _TermDetailScreenState extends State<TermDetailScreen> {
  late final TextEditingController noteController;

  @override
  void initState() {
    super.initState();
    noteController =
        TextEditingController(text: widget.store.noteFor(widget.termId));
  }

  @override
  void dispose() {
    widget.store.saveNote(widget.termId, noteController.text);
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final term = widget.store.termById(widget.termId);
    if (term == null) {
      return const PatternScaffold(
          body: Center(child: Text('Term not found.')));
    }

    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final saved = widget.store.isBookmarked(term.id);
        return PatternScaffold(
          appBar: AppBar(
            title: Text(
              term.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              IconButton(
                tooltip: saved ? 'Remove bookmark' : 'Bookmark',
                icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                onPressed: () => widget.store.toggleBookmark(term.id),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text(term.category)),
                  if (term.draft)
                    const Chip(
                      avatar: Icon(Icons.edit_note, size: 18),
                      label: Text('Draft definition'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(term.short,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      if (term.details != null) ...[
                        const SizedBox(height: 16),
                        Text(term.details!, style: theme.textTheme.bodyLarge),
                      ],
                    ],
                  ),
                ),
              ),
              if (term.safetyNote != null) ...[
                const SizedBox(height: 20),
                Card(
                  color: theme.colorScheme.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.health_and_safety_outlined,
                            color: theme.colorScheme.onTertiaryContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            term.safetyNote!,
                            style: TextStyle(
                                color: theme.colorScheme.onTertiaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (term.related.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Related', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final id in term.related)
                      if (widget.store.termById(id) != null)
                        ActionChip(
                          label: Text(widget.store.termById(id)!.name),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TermDetailScreen(
                                  store: widget.store, termId: id),
                            ),
                          ),
                        ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Text('My notes (private, stays on this device)',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                maxLines: 5,
                minLines: 3,
                onChanged: (v) => widget.store.saveNote(term.id, v),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Thoughts, questions, things to discuss…',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
