import 'package:flutter/material.dart';

import '../instant_route.dart';
import '../data_store.dart';
import '../models.dart';
import '../widgets/back_to_top.dart';
import '../widgets/circled_icon_button.dart';
import '../widgets/definition_card.dart';
import '../widgets/pattern_background.dart';
import '../widgets/safety_note_card.dart';
import 'term_detail_screen.dart';

class PathsScreen extends StatefulWidget {
  final DataStore store;
  const PathsScreen({super.key, required this.store});

  @override
  State<PathsScreen> createState() => _PathsScreenState();
}

class _PathsScreenState extends State<PathsScreen> {
  final _backToTop = BackToTopController();

  @override
  void dispose() {
    _backToTop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = widget.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => SafeArea(
        child: Stack(
          children: [
            ListView(
              controller: _backToTop.scroll,
              padding: const EdgeInsets.all(16),
              children: [
                Text('Where would you like to begin?',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Pick a short path. Go at your own pace, and skip anything.',
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                for (final p in store.paths) _PathCard(store: store, path: p),
              ],
            ),
            // Only appears once the list is long enough to have scrolled, so
            // a short list of paths never gets a useless button.
            Positioned(
              right: 16,
              bottom: 16,
              child: BackToTopButton(
                controller: _backToTop,
                heroTag: 'pathsBackToTop',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PathCard extends StatelessWidget {
  final DataStore store;
  final LearningPath path;
  const _PathCard({required this.store, required this.path});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = store.termsForPath(path).length;
    final done = store.pathCompleted(path.id);
    final started = store.pathStarted(path.id);
    final step = store.pathStep(path.id).clamp(0, total);
    final progress = total == 0 ? 0.0 : (step / total).clamp(0.0, 1.0);
    final percent = (progress * 100).round();
    final status = done
        ? 'Completed'
        : started
            ? 'Step ${step + 1} of $total · $percent%'
            : '$total terms';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(instantRoute(PathDetailScreen(store: store, path: path))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(path.title, style: theme.textTheme.titleMedium),
                  ),
                  if (done)
                    Icon(
                      Icons.check_circle,
                      // Same colour as the path title, not a separate accent.
                      color: theme.textTheme.titleMedium?.color,
                    )
                  else if (started && total > 0)
                    _ProgressRing(progress: progress, percent: percent)
                  else
                    const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 4),
              Text(path.blurb),
              const SizedBox(height: 10),
              Row(
                children: [
                  Chip(
                    label: Text(path.level),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  Text(status, style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact ring showing how far through a path someone is, with the
/// percentage in the middle so it reads at a glance.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.progress, required this.percent});

  final double progress;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          Text(
            '$percent%',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Overview of a path with its steps and a start / continue button.
class PathDetailScreen extends StatelessWidget {
  final DataStore store;
  final LearningPath path;
  const PathDetailScreen({super.key, required this.store, required this.path});

  void _play(BuildContext context, int start) =>
      Navigator.of(context).push(instantRoute(PathPlayerScreen(store: store, path: path, start: start)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Completed steps wear the same colour as the headings, so a finished
    // step reads as part of the text rather than a grey chip.
    final completedColor =
        theme.textTheme.titleMedium?.color ?? theme.colorScheme.onSurface;
    final terms = store.termsForPath(path);
    return PatternScaffold(
      appBar: AppBar(
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: CircledIconButton(
            icon: Icons.arrow_back,
            tooltip: 'Back to paths',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        // The path name is the page's main heading, so it gets heading scale
        // rather than the default app-bar size.
        title: Text(
          path.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final started = store.pathStarted(path.id);
          final done = store.pathCompleted(path.id);
          final resume = terms.isEmpty
              ? 0
              : store.pathStep(path.id).clamp(0, terms.length - 1);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(path.blurb, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(label: Text(path.level)),
                          Chip(label: Text('${terms.length} steps')),
                          if (done) const Chip(label: Text('Completed')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _play(context, started && !done ? resume : 0),
                icon: Icon(done ? Icons.replay : Icons.play_arrow),
                label: Text(started && !done
                    ? 'Continue at step ${resume + 1}'
                    : done
                        ? 'Go through it again'
                        : 'Start path'),
              ),
              if (path.reflection.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('You finish with a reflection',
                            style: theme.textTheme.titleSmall),
                        const SizedBox(height: 6),
                        Text(path.reflection),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text('In this path', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              for (var i = 0; i < terms.length; i++)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          done || (started && i < resume)
                              ? completedColor
                              : null,
                      foregroundColor:
                          done || (started && i < resume)
                              ? theme.colorScheme.surface
                              : null,
                      child: done || (started && i < resume)
                          ? const Icon(Icons.check, size: 18)
                          : Text('${i + 1}'),
                    ),
                    title: Text(terms[i].name),
                    subtitle: Text(
                      terms[i].short,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _play(context, i),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Steps through a path one term at a time with Back / Next navigation.
class PathPlayerScreen extends StatefulWidget {
  final DataStore store;
  final LearningPath path;
  final int start;
  const PathPlayerScreen({
    super.key,
    required this.store,
    required this.path,
    this.start = 0,
  });

  @override
  State<PathPlayerScreen> createState() => _PathPlayerScreenState();
}

class _PathPlayerScreenState extends State<PathPlayerScreen> {
  late final List<Term> _terms = widget.store.termsForPath(widget.path);
  late int _step = widget.start.clamp(0, _terms.length);
  final _note = TextEditingController();
  String? _noteTermId;

  bool get _finished => _step >= _terms.length;

  @override
  void initState() {
    super.initState();
    _syncNote();
    WidgetsBinding.instance.addPostFrameCallback((_) => _remember());
  }

  @override
  void dispose() {
    _saveNote();
    _note.dispose();
    super.dispose();
  }

  void _saveNote() {
    final id = _noteTermId;
    if (id != null) widget.store.saveNote(id, _note.text);
  }

  void _syncNote() {
    _noteTermId = _finished ? null : _terms[_step].id;
    _note.text = _noteTermId == null ? '' : widget.store.noteFor(_noteTermId!);
  }

  void _remember() {
    if (_terms.isEmpty) return;
    if (_finished) {
      widget.store.completePath(widget.path.id);
      widget.store.setPathStep(widget.path.id, _terms.length - 1);
    } else {
      widget.store.setPathStep(widget.path.id, _step);
    }
  }

  void _go(int step) {
    _saveNote();
    setState(() => _step = step.clamp(0, _terms.length));
    _syncNote();
    _remember();
  }

  Future<void> _pickStep() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        children: [
          for (var i = 0; i < _terms.length; i++)
            ListTile(
              leading: CircleAvatar(radius: 14, child: Text('${i + 1}')),
              title: Text(_terms[i].name),
              selected: i == _step,
              onTap: () => Navigator.pop(context, i),
            ),
        ],
      ),
    );
    if (picked != null) _go(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _terms.length;
    return PatternScaffold(
      appBar: AppBar(
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: CircledIconButton(
            icon: Icons.arrow_back,
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(
          widget.path.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Jump to a step',
            onPressed: _pickStep,
            icon: const Icon(Icons.list),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => Column(
          children: [
            LinearProgressIndicator(
              value: total == 0 ? 0.0 : _step.clamp(0, total) / total,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _finished ? _completion(context) : _stepView(context),
                ),
              ),
            ),
            _controls(context),
          ],
        ),
      ),
    );
  }

  Widget _stepView(BuildContext context) {
    final theme = Theme.of(context);
    final term = _terms[_step];
    final saved = widget.store.isBookmarked(term.id);
    final related = widget.store.relatedTerms(term);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Step ${_step + 1} of ${_terms.length}',
            style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(term.name,
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            IconButton(
              tooltip: saved ? 'Remove bookmark' : 'Bookmark',
              onPressed: () => widget.store.toggleBookmark(term.id),
              icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Chip(label: Text(term.category)),
        ),
        const SizedBox(height: 8),
        DefinitionCard(
          term: term,
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
        if (term.safetyNote != null) SafetyNoteCard(note: term.safetyNote!),
        if (related.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Related', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final other in related)
                ActionChip(
                  label: Text(other.name),
                  onPressed: () => Navigator.of(context).push(
                    instantRoute(TermDetailScreen(
                        store: widget.store,
                        termId: other.id,
                      )),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Text('My notes (private to you)',
            style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _note,
          minLines: 2,
          maxLines: 5,
          onChanged: (value) => widget.store.saveNote(term.id, value),
          decoration: const InputDecoration(
            hintText: 'Thoughts, questions, things to discuss…',
          ),
        ),
      ],
    );
  }

  Widget _completion(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 56,
          color: theme.textTheme.titleMedium?.color,
        ),
        const SizedBox(height: 12),
        Text('Path complete',
            textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(widget.path.title,
            textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
        if (widget.path.reflection.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('To reflect on', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(widget.path.reflection),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            for (final term in _terms) {
              if (!widget.store.isBookmarked(term.id)) {
                await widget.store.toggleBookmark(term.id);
              }
            }
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('All terms bookmarked.')),
            );
          },
          icon: const Icon(Icons.bookmark_add_outlined),
          label: const Text('Bookmark every term'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () async {
            await widget.store.restartPath(widget.path.id);
            _go(0);
          },
          icon: const Icon(Icons.replay),
          label: const Text('Start over'),
        ),
      ],
    );
  }

  Widget _controls(BuildContext context) {
    final last = _step == _terms.length - 1;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    _step == 0 ? Navigator.of(context).pop() : _go(_step - 1),
                icon: const Icon(Icons.arrow_back),
                label: Text(_step == 0 ? 'Overview' : 'Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _finished
                    ? () => Navigator.of(context).pop()
                    : () => _go(_step + 1),
                icon: Icon(_finished ? Icons.done : Icons.arrow_forward),
                label: Text(_finished
                    ? 'Done'
                    : last
                        ? 'Finish'
                        : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
