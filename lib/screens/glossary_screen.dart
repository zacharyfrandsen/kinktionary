import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show FloatingHeaderSnapConfiguration;

import '../instant_route.dart';
import '../data_store.dart';
import '../models.dart';
import '../widgets/back_to_top.dart';
import '../widgets/chip_rail.dart';
import '../widgets/search_row.dart';
import 'term_detail_screen.dart';

class GlossaryScreen extends StatefulWidget {
  final DataStore store;
  const GlossaryScreen({super.key, required this.store});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _backToTop = BackToTopController();
  String query = '';
  String? category;
  bool savedOnly = false;

  @override
  void dispose() {
    _backToTop.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final results = widget.store.search(
          query,
          category: category,
          savedOnly: savedOnly,
        );
        final theme = Theme.of(context);
        return SafeArea(
          child: Stack(
            children: [
              CustomScrollView(
                controller: _backToTop.scroll,
                slivers: [
                  // The search field floats: it leaves with the terms as they
                  // are scrolled down and snaps back the moment the list moves
                  // up, so searching never means climbing a long glossary
                  // first. The chips stay in the list below it and scroll away.
                  SliverPersistentHeader(
                    floating: true,
                    delegate: _SearchHeader(
                      vsync: this,
                      child: SearchRow(
                        store: widget.store,
                        controller: _searchController,
                        hintText: savedOnly
                            ? 'Search saved terms and notes…'
                            : 'Search terms…',
                        onChanged: (v) => setState(() => query = v),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    ChipRail(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: FilterChip(
                              avatar: Icon(
                                savedOnly
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                size: 18,
                              ),
                              label: const Text('Saved'),
                              selected: savedOnly,
                              onSelected: (value) =>
                                  setState(() => savedOnly = value),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: const Text('All'),
                              selected: category == null,
                              onSelected: (_) =>
                                  setState(() => category = null),
                            ),
                          ),
                          for (final c in widget.store.categories)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Text(c),
                                selected: category == c,
                                onSelected: (_) =>
                                    setState(() => category = c),
                              ),
                            ),
                      ],
                    ),
                    // A category picked by tapping a pill can be dropped again
                    // here, without scrolling the chip row back to All.
                    if (category != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Row(
                          children: [
                            InputChip(
                              label: Text(category!),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              deleteButtonTooltipMessage: 'Clear category',
                              onDeleted: () => setState(() => category = null),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              results.length == 1
                                  ? '1 term'
                                  : '${results.length} terms',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      ],
                    ),
                  ),
                  if (results.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Card(
                          margin: const EdgeInsets.all(24),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              savedOnly && query.isEmpty
                                  ? 'Bookmark terms and they will show up here.'
                                  : 'No matching terms.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 4, bottom: 12),
                      sliver: SliverList.builder(
                        itemCount: results.length,
                        itemBuilder: (context, i) => TermTile(
                          term: results[i],
                          store: widget.store,
                          onCategoryTap: (value) =>
                              setState(() => category = value),
                        ),
                      ),
                    ),
                ],
              ),
              // Long glossaries are easy to get lost in; the shortcut only
              // exists while there is something to go back to.
              if (results.isNotEmpty)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: BackToTopButton(
                    controller: _backToTop,
                    heroTag: 'glossaryBackToTop',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The glossary's search field, as a header that is part of the scroll rather
/// than pinned: it goes away while the terms are scrolled down, and is back the
/// moment the list is pulled upwards.
class _SearchHeader extends SliverPersistentHeaderDelegate {
  const _SearchHeader({required this.child, required this.vsync});

  final Widget child;

  /// Drives the snap: a short upward drag opens the field all the way instead
  /// of leaving a sliver of it on screen to be pulled further by hand.
  @override
  final TickerProvider vsync;

  /// [SearchRow]'s own padding (12 above, 8 below) plus the search bar's 56px.
  static const double height = 76;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  FloatingHeaderSnapConfiguration get snapConfiguration =>
      FloatingHeaderSnapConfiguration();

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) =>
      child;

  @override
  bool shouldRebuild(covariant _SearchHeader oldDelegate) =>
      oldDelegate.child != child;
}

class TermTile extends StatelessWidget {
  final Term term;
  final DataStore store;

  /// Called when the category label is tapped. Null makes the label static,
  /// which is what a list without a category filter wants.
  final ValueChanged<String>? onCategoryTap;

  const TermTile({
    super.key,
    required this.term,
    required this.store,
    this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        title: Text(
          term.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        // One line of the definition, so a list of names is readable at a
        // glance without turning every row into a paragraph.
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  term.short,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: _CategoryPill(
                  label: term.category,
                  onTap: onCategoryTap == null
                      ? null
                      : () => onCategoryTap!(term.category),
                ),
              ),
            ],
          ),
        ),
        trailing: store.isBookmarked(term.id)
            ? Icon(Icons.bookmark, color: theme.colorScheme.primary)
            : null,
        onTap: () => Navigator.of(context).push(instantRoute(TermDetailScreen(store: store, termId: term.id))),
      ),
    );
  }
}

/// Small, quiet category label that sits at the end of a row's preview line.
/// Taps it to filter; taps on the rest of the row still open the term.
class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    if (onTap == null) return pill;
    return Semantics(
      button: true,
      label: 'Filter by $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: pill,
      ),
    );
  }
}
