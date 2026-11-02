import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../instant_route.dart';
import '../data_store.dart';
import '../models.dart';
import '../widgets/back_to_top.dart';
import '../widgets/search_row.dart';
import 'post_composer_screen.dart' show postTopics;
import 'public_profile_screen.dart';

class CommunityFeedScreen extends StatefulWidget {
  final DataStore store;
  final String? currentUserId;

  /// Visitors who aren't signed in only see a sign-in prompt.
  final bool signedIn;
  final VoidCallback? onSignIn;

  const CommunityFeedScreen({
    super.key,
    required this.store,
    this.currentUserId,
    this.signedIn = true,
    this.onSignIn,
  });

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  final TextEditingController _searchController = TextEditingController();
  final _backToTop = BackToTopController();
  String _query = '';

  /// Topic picked from the row at the top of the feed; null shows everything.
  String? _topic;

  @override
  void dispose() {
    _backToTop.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _ownerId {
    if (widget.currentUserId != null) return widget.currentUserId!;
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? 'local-preview-user';
    } on Object {
      return 'local-preview-user';
    }
  }

  String get _displayName {
    final profileName = widget.store.profile.displayName.trim();
    if (profileName.isNotEmpty) return profileName;
    try {
      final authName = FirebaseAuth.instance.currentUser?.displayName?.trim();
      return authName == null || authName.isEmpty ? 'You' : authName;
    } on Object {
      return 'You';
    }
  }

  List<CommunityPost> _filter(List<CommunityPost> posts) {
    final topic = _topic;
    final matching = topic == null
        ? posts
        : posts.where((post) => post.topic == topic).toList();
    final terms = _query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();
    if (terms.isEmpty) return matching;
    return matching.where((post) {
      final text = [
        post.text,
        post.topic,
        ...post.tags.map((tag) => '#$tag'),
        post.displayName,
        post.handle,
        ...post.replies.map(
          (reply) => '${reply.displayName} ${reply.handle} ${reply.text}',
        ),
      ].join(' ').toLowerCase();
      return terms.every(text.contains);
    }).toList();
  }

  Future<void> _edit(CommunityPost post) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _EditPostDialog(initialText: post.text),
    );
    if (text == null || text.isEmpty || !mounted) return;
    final changed = await widget.store.updateCommunityPost(
      postId: post.id,
      ownerId: _ownerId,
      text: text,
    );
    if (!changed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only edit your own posts.')),
      );
    }
  }

  Future<void> _delete(CommunityPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('Remove this post from the feed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await widget.store.deleteCommunityPost(
      postId: post.id,
      ownerId: _ownerId,
    );
    if (!deleted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete this post. Check your connection.'),
        ),
      );
    }
  }

  Future<void> _toggleLike(CommunityPost post) async {
    try {
      await widget.store.toggleCommunityPostLike(post.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update like. Try again.')),
      );
    }
  }

  Future<void> _reply(CommunityPost post) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReplySheet(
        store: widget.store,
        post: post,
        authorId: _ownerId,
        displayName: _displayName,
        handle: widget.store.profile.handle,
        onOpenProfile: (reply) => _openProfile(
          reply.authorId,
          reply.displayName,
          reply.handle,
        ),
      ),
    );
  }

  void _openProfile(String userId, String displayName, String handle) {
    if (userId.isEmpty || userId == 'local-preview-user') return;
    Navigator.of(context).push(
      instantRoute(PublicProfileScreen(
          store: widget.store,
          userId: userId,
          displayName: displayName,
          handle: handle,
        )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!widget.signedIn) return _signInPrompt(theme);
    return SafeArea(
      child: Column(
        children: [
          _topicStrip(theme),
          SearchRow(
            store: widget.store,
            controller: _searchController,
            hintText: 'Search experiences, questions, tags…',
            onChanged: (value) => setState(() => _query = value),
          ),
          Expanded(
            // Only post changes rebuild the cards; the rest of the store is
            // ignored here so other screens can't repaint the feed.
            child: ListenableBuilder(
              listenable: widget.store.postsRevision,
              builder: (context, _) {
                final posts = _filter(widget.store.posts);
                if (posts.isEmpty) {
                  return Center(
                    child: Card(
                      margin: const EdgeInsets.all(24),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.forum_outlined,
                              size: 42,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _query.isEmpty
                                  ? 'No conversations yet'
                                  : 'No matching posts',
                              style: theme.textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _query.isEmpty
                                  ? 'Use the Post button to start a conversation.'
                                  : 'Try another keyword or tag.',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return Stack(
                  children: [
                    ListView.builder(
                      controller: _backToTop.scroll,
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: posts.length,
                      itemBuilder: (context, index) =>
                          _postCard(posts[index]),
                    ),
                    // Same shortcut as the glossary: only while there is feed
                    // above the fold to go back to.
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: BackToTopButton(
                        controller: _backToTop,
                        heroTag: 'communityFeedBackToTop',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static IconData _topicIcon(String topic) => switch (topic) {
        'Question' => Icons.help_outline,
        'Reflection' => Icons.psychology_alt_outlined,
        'Advice' => Icons.lightbulb_outline,
        _ => Icons.forum_outlined,
      };

  /// Topic picker across the top of the feed — the same slot a social app uses
  /// for stories, but here each circle filters the posts below it.
  Widget _topicStrip(ThemeData theme) {
    final scheme = theme.colorScheme;
    final entries = <(String?, IconData, String)>[
      (null, Icons.grid_view, 'All'),
      for (final topic in postTopics) (topic, _topicIcon(topic), topic),
    ];
    return SizedBox(
      height: 106,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          final (topic, icon, label) = entries[i];
          final selected = _topic == topic;
          return InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: () => setState(() => _topic = selected ? null : topic),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.secondary],
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerLow,
                    ),
                    child: Icon(
                      icon,
                      size: 24,
                      color: selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _signInPrompt(ThemeData theme) => SafeArea(
        child: Column(
          children: [
            SearchRow(
              store: widget.store,
              controller: _searchController,
              hintText: 'Sign in to search the community',
              onChanged: (_) {},
            ),
            Expanded(
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(24),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 42,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sign in to view content',
                          style: theme.textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'The community feed is for signed-in members. You '
                          'can still use the glossary and paths without an '
                          'account.',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: widget.onSignIn,
                          child: const Text('Sign in or create an account'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  void _searchTag(String tag) {
    _searchController.text = '#$tag';
    setState(() => _query = '#$tag');
  }

  Widget _postCard(CommunityPost post) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () =>
                      _openProfile(post.ownerId, post.displayName, post.handle),
                  child: CircleAvatar(
                    radius: 19,
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: Icon(
                      Icons.person_outline,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => _openProfile(
                          post.ownerId,
                          post.displayName,
                          post.handle,
                        ),
                        child: Text(
                          post.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      if (post.handle.isNotEmpty)
                        Text('@${post.handle}',
                            style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Chip(label: Text(post.topic)),
                if (post.ownerId == _ownerId)
                  PopupMenuButton<_PostAction>(
                    tooltip: 'Post options',
                    onSelected: (action) => action == _PostAction.edit
                        ? _edit(post)
                        : _delete(post),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _PostAction.edit,
                        child: Text('Edit post'),
                      ),
                      PopupMenuItem(
                        value: _PostAction.delete,
                        child: Text('Delete post'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(post.text, style: theme.textTheme.bodyLarge),
            if (post.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final tag in post.tags)
                    ActionChip(
                      label: Text('#$tag'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _searchTag(tag),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: post.likedByMe ? 'Unlike post' : 'Like post',
                  onPressed: () => _toggleLike(post),
                  icon: Icon(
                    post.likedByMe ? Icons.favorite : Icons.favorite_border,
                  ),
                  color: post.likedByMe ? theme.colorScheme.primary : null,
                ),
                Text('${post.likeCount}'),
                const SizedBox(width: 16),
                IconButton(
                  tooltip: 'Reply to post',
                  onPressed: () => _reply(post),
                  icon: const Icon(Icons.chat_bubble_outline),
                ),
                Text('${post.replies.length}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplySheet extends StatefulWidget {
  final DataStore store;
  final CommunityPost post;
  final String authorId;
  final String displayName;
  final String handle;
  final ValueChanged<CommunityReply> onOpenProfile;

  const _ReplySheet({
    required this.store,
    required this.post,
    required this.authorId,
    required this.displayName,
    required this.handle,
    required this.onOpenProfile,
  });

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late CommunityPost _currentPost;
  var _sending = false;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
  }

  @override
  void dispose() {
    _focusNode.unfocus();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final added = await widget.store.addCommunityPostReply(
        _currentPost.id,
        CommunityReply(
          authorId: widget.authorId,
          displayName: widget.displayName,
          handle: widget.handle,
          text: text,
          createdAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      if (!added) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This post is no longer available.')),
        );
        return;
      }
      final updatedPost = widget.store.posts.firstWhere(
        (post) => post.id == _currentPost.id,
      );
      setState(() {
        _currentPost = updatedPost;
        _controller.clear();
        _sending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply could not be saved. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: 340,
          child: Column(
            children: [
              Text('Replies', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Expanded(
                child: _currentPost.replies.isEmpty
                    ? const Center(child: Text('Start the conversation.'))
                    : ListView(
                        children: [
                          for (final reply in _currentPost.replies)
                            ListTile(
                              onTap: reply.authorId.isEmpty
                                  ? null
                                  : () => widget.onOpenProfile(reply),
                              dense: true,
                              leading: const CircleAvatar(
                                radius: 16,
                                child: Icon(Icons.person_outline, size: 18),
                              ),
                              title: Text(
                                reply.displayName,
                                style: reply.authorId.isEmpty
                                    ? null
                                    : const TextStyle(
                                        decoration: TextDecoration.underline,
                                      ),
                              ),
                              subtitle: Text(reply.text),
                            ),
                        ],
                      ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('community-reply-field'),
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLength: 300,
                      decoration: const InputDecoration(
                        hintText: 'Write a reply',
                        counterText: '',
                      ),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Send reply',
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

enum _PostAction { edit, delete }

class _EditPostDialog extends StatefulWidget {
  final String initialText;
  const _EditPostDialog({required this.initialText});

  @override
  State<_EditPostDialog> createState() => _EditPostDialogState();
}

class _EditPostDialogState extends State<_EditPostDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Edit post'),
        content: TextField(
          key: const ValueKey('edit-post-field'),
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 7,
          maxLength: 500,
          decoration: const InputDecoration(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _controller.text.trim()),
            child: const Text('Save changes'),
          ),
        ],
      );
}
