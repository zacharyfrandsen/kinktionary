import 'package:flutter/material.dart';

import '../instant_route.dart';
import '../data_store.dart';
import '../models.dart';
import '../widgets/pattern_background.dart';
import '../widgets/search_row.dart';
import '../widgets/user_tile.dart';
import 'public_profile_screen.dart';
import 'term_detail_screen.dart';

Widget _emptyCard(String text) => Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(text, textAlign: TextAlign.center),
        ),
      ),
    );

/// Compact post card used when browsing someone's posts from a stat.
class PostSummaryCard extends StatelessWidget {
  final CommunityPost post;
  const PostSummaryCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(post.topic, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(post.text),
            if (post.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final tag in post.tags)
                    Text('#$tag', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.favorite_border, size: 18),
                const SizedBox(width: 5),
                Text('${post.likeCount}'),
                const SizedBox(width: 18),
                const Icon(Icons.chat_bubble_outline, size: 18),
                const SizedBox(width: 5),
                Text('${post.replies.length}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PostsListScreen extends StatelessWidget {
  final DataStore store;
  final String title;
  final String userId;

  /// Only posts that have at least one like.
  final bool likedOnly;

  const PostsListScreen({
    super.key,
    required this.store,
    required this.title,
    required this.userId,
    this.likedOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return PatternScaffold(
      appBar: AppBar(title: Text(title)),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final posts = store.posts
              .where(
                  (p) => p.ownerId == userId && (!likedOnly || p.likeCount > 0))
              .toList();
          if (likedOnly) {
            posts.sort((a, b) => b.likeCount.compareTo(a.likeCount));
          }
          if (posts.isEmpty) {
            return _emptyCard(likedOnly ? 'No likes yet.' : 'No posts yet.');
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [for (final post in posts) PostSummaryCard(post: post)],
          );
        },
      ),
    );
  }
}

/// Replies other people have left on a user's posts.
class RepliesListScreen extends StatelessWidget {
  final DataStore store;
  final String userId;
  const RepliesListScreen(
      {super.key, required this.store, required this.userId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PatternScaffold(
      appBar: AppBar(title: const Text('Replies')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items = [
            for (final post in store.posts.where((p) => p.ownerId == userId))
              for (final reply in post.replies) (post: post, reply: reply),
          ]..sort((a, b) => b.reply.createdAt.compareTo(a.reply.createdAt));
          if (items.isEmpty) return _emptyCard('No replies yet.');
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final item in items)
                Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.reply.displayName,
                            style: theme.textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text(item.reply.text),
                        const Divider(height: 20),
                        Text(
                          'On: ${item.post.text}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class UserListScreen extends StatelessWidget {
  final DataStore store;
  final String title;
  final Future<List<String>> Function() load;
  const UserListScreen({
    super.key,
    required this.store,
    required this.title,
    required this.load,
  });

  @override
  Widget build(BuildContext context) {
    return PatternScaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<List<String>>(
        future: load(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _emptyCard('Could not load this list. Try again later.');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final ids = snapshot.data!;
          if (ids.isEmpty) return _emptyCard('Nobody here yet.');
          return ListView(
            children: [
              for (final id in ids)
                Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: UserTile(
                    userId: id,
                    onTap: () => Navigator.of(context).push(
                      instantRoute(PublicProfileScreen(
                          store: store,
                          userId: id,
                          displayName: '',
                          handle: '',
                        )),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Every term the user has written a note on, searchable by term or note text.
class NotesScreen extends StatefulWidget {
  final DataStore store;
  const NotesScreen({super.key, required this.store});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PatternScaffold(
      appBar: AppBar(title: const Text('My notes')),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final withNotes = widget.store.termsWithNotes;
          final q = _query.trim().toLowerCase();
          final terms = q.isEmpty
              ? withNotes
              : withNotes
                  .where((t) =>
                      t.name.toLowerCase().contains(q) ||
                      widget.store.noteFor(t.id).toLowerCase().contains(q))
                  .toList();
          return Column(
            children: [
              SearchRow(
                store: widget.store,
                controller: _search,
                hintText: 'Search your notes…',
                showSafety: false,
                onChanged: (v) => setState(() => _query = v),
              ),
              Expanded(
                child: terms.isEmpty
                    ? _emptyCard(withNotes.isEmpty
                        ? 'Notes you write on terms show up here. They are '
                            'private to you.'
                        : 'No notes match your search.')
                    : ListView(
                        children: [
                          for (final term in terms)
                            Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                title: Text(term.name),
                                subtitle: Text(
                                  widget.store.noteFor(term.id),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => Navigator.of(context)
                                    .push(instantRoute(TermDetailScreen(
                                    store: widget.store,
                                    termId: term.id,
                                  ))),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
