import 'package:flutter/material.dart';

import '../data_store.dart';
import '../models.dart';
import '../services/firebase_social_service.dart';
import '../widgets/pattern_background.dart';

class PublicProfileScreen extends StatefulWidget {
  final DataStore store;
  final String userId;
  final String displayName;
  final String handle;

  const PublicProfileScreen({
    super.key,
    required this.store,
    required this.userId,
    required this.displayName,
    required this.handle,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _socialService = FirebaseSocialService();
  late Future<UserProfile> _profileFuture;
  late Future<FriendStatus> _friendStatusFuture;
  bool _busy = false;

  UserProfile get _fallbackProfile => UserProfile(
        displayName: widget.displayName,
        handle: widget.handle,
      );

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _profileFuture = _socialService.loadProfile(
      widget.userId,
      fallback: _fallbackProfile,
    );
    _friendStatusFuture = _socialService.friendStatus(widget.userId);
  }

  Future<void> _actOnFriendStatus(FriendStatus status) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      switch (status) {
        case FriendStatus.none:
          await _socialService.sendFriendRequest(widget.userId);
          break;
        case FriendStatus.incoming:
          await _socialService.respondToFriendRequest(
            widget.userId,
            accept: true,
          );
          break;
        case FriendStatus.outgoing:
          await _socialService.cancelFriendRequest(widget.userId);
          break;
        case FriendStatus.signedOut:
        case FriendStatus.self:
        case FriendStatus.friends:
        case FriendStatus.declined:
          return;
      }
      if (!mounted) return;
      setState(_refresh);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not update friend request. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _friendButton(FriendStatus status) {
    final label = switch (status) {
      FriendStatus.signedOut => 'Sign in to add friends',
      FriendStatus.self => '',
      FriendStatus.none => 'Add friend',
      FriendStatus.outgoing => 'Request sent',
      FriendStatus.incoming => 'Accept request',
      FriendStatus.friends => 'Friends',
      FriendStatus.declined => 'Request declined',
    };
    if (status == FriendStatus.self) return const SizedBox.shrink();

    final canAct = !_busy &&
        (status == FriendStatus.none ||
            status == FriendStatus.incoming ||
            status == FriendStatus.outgoing);
    final onPressed = canAct ? () => _actOnFriendStatus(status) : null;
    final icon = switch (status) {
      FriendStatus.incoming => Icons.person_add_alt_1,
      FriendStatus.friends => Icons.people_alt_outlined,
      FriendStatus.outgoing => Icons.hourglass_top,
      _ => Icons.person_add_alt_1,
    };

    return status == FriendStatus.incoming
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.person_add_alt_1),
            label: Text(_busy ? 'Saving…' : label),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(_busy ? 'Saving…' : label),
          );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PatternScaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<UserProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          final profile = snapshot.data ?? _fallbackProfile;
          final displayName = profile.displayName.isEmpty
              ? widget.displayName
              : profile.displayName;
          final handle =
              profile.handle.isEmpty ? widget.handle : profile.handle;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 20),
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  backgroundImage: profile.photoUrl == null
                      ? null
                      : NetworkImage(profile.photoUrl!),
                  child: profile.photoUrl == null
                      ? Icon(
                          Icons.person_outline,
                          size: 48,
                          color: theme.colorScheme.onSecondaryContainer,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                displayName,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              if (handle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('@$handle', textAlign: TextAlign.center),
              ],
              if (profile.pronouns.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(profile.pronouns, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 20),
              FutureBuilder<FriendStatus>(
                future: _friendStatusFuture,
                builder: (context, statusSnapshot) {
                  if (statusSnapshot.hasError) {
                    return const Text('Friend requests could not be loaded.');
                  }
                  if (!statusSnapshot.hasData) {
                    return const Center(
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  return Center(child: _friendButton(statusSnapshot.data!));
                },
              ),
              if (snapshot.hasError)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    'Showing the profile details saved with this post.',
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 24),
              Text('About', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(profile.bio.isEmpty ? 'No bio yet.' : profile.bio),
              const SizedBox(height: 28),
              ListenableBuilder(
                listenable: widget.store,
                builder: (context, _) {
                  final posts = widget.store.posts
                      .where((post) => post.ownerId == widget.userId)
                      .toList();
                  final likes = posts.fold(
                    0,
                    (total, post) => total + post.likeCount,
                  );
                  final replies = posts.fold(
                    0,
                    (total, post) => total + post.replies.length,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _ProfileMetric(label: 'Posts', value: posts.length),
                          _ProfileMetric(label: 'Likes', value: likes),
                          _ProfileMetric(label: 'Replies', value: replies),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text('Posts', style: theme.textTheme.titleLarge),
                      if (posts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text('No posts yet.'),
                        ),
                      for (final post in posts)
                        Card(
                          margin: const EdgeInsets.only(top: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.topic,
                                  style: theme.textTheme.labelLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(post.text),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.favorite_border, size: 18),
                                    const SizedBox(width: 5),
                                    Text('${post.likeCount}'),
                                    const SizedBox(width: 18),
                                    const Icon(
                                      Icons.chat_bubble_outline,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 5),
                                    Text('${post.replies.length}'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  final String label;
  final int value;

  const _ProfileMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text('$value', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}
