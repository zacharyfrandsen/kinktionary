import 'package:flutter/material.dart';

import '../instant_route.dart';
import '../data_store.dart';
import '../models.dart';
import '../services/firebase_social_service.dart';
import '../social_models.dart';
import '../widgets/friend_edit_sheet.dart';
import '../widgets/pattern_background.dart';
import '../widgets/profile_header.dart';
import 'profile_lists_screen.dart';

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
  late Future<bool> _followingFuture;
  late final Stream<int> _followers = _socialService
      .countStream(widget.userId, 'followers')
      .asBroadcastStream();
  late final Stream<int> _following = _socialService
      .countStream(widget.userId, 'following')
      .asBroadcastStream();
  late final Stream<int> _friends = _socialService
      .countStream(widget.userId, 'publicFriends')
      .asBroadcastStream();
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
    _followingFuture = _socialService.isFollowing(widget.userId);
  }

  Future<void> _toggleFollow(bool following) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (following) {
        await _socialService.unfollow(widget.userId);
      } else {
        await _socialService.follow(widget.userId);
      }
      if (!mounted) return;
      setState(_refresh);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update following. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _followButton(FriendStatus status) {
    if (status == FriendStatus.self ||
        status == FriendStatus.signedOut ||
        status == FriendStatus.blocked) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<bool>(
      future: _followingFuture,
      builder: (context, snapshot) {
        final following = snapshot.data ?? false;
        final onPressed =
            _busy || !snapshot.hasData ? null : () => _toggleFollow(following);
        return following
            ? OutlinedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.check),
                label: const Text('Following'),
              )
            : FilledButton.tonalIcon(
                onPressed: onPressed,
                icon: const Icon(Icons.rss_feed),
                label: const Text('Follow'),
              );
      },
    );
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
          await _socialService.acceptFriendRequest(widget.userId);
          break;
        case FriendStatus.outgoing:
          await _socialService.cancelFriendRequest(widget.userId);
          break;
        case FriendStatus.blocked:
          await _socialService.unblockUser(widget.userId);
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

  Future<void> _confirmBlock() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Block this person?'),
        content: const Text(
          'Their posts and replies are hidden from you, and they cannot send '
          'you requests or reply to your posts. Any friendship is removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _socialService.blockUser(widget.userId);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not block. Try again.')),
      );
    }
  }

  Widget _friendDetails() => FutureBuilder<Friend?>(
        future: _socialService.friendRecord(widget.userId),
        builder: (context, snapshot) {
          final friend = snapshot.data;
          if (friend == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                if (friend.nickname.isNotEmpty)
                  Text('Nickname: ${friend.nickname}'),
                if (friend.tags.isNotEmpty)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    children: [
                      for (final tag in friend.tags)
                        Chip(
                          label: Text(tag),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                TextButton.icon(
                  onPressed: () async {
                    await showFriendEditSheet(
                      context,
                      service: _socialService,
                      friend: friend,
                    );
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.label_outline),
                  label: const Text('Edit labels'),
                ),
              ],
            ),
          );
        },
      );

  Widget _friendButton(FriendStatus status) {
    final label = switch (status) {
      FriendStatus.signedOut => 'Sign in to add friends',
      FriendStatus.self => '',
      FriendStatus.blocked => 'Unblock',
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
            status == FriendStatus.outgoing ||
            status == FriendStatus.blocked);
    final onPressed = canAct ? () => _actOnFriendStatus(status) : null;
    final icon = switch (status) {
      FriendStatus.incoming => Icons.person_add_alt_1,
      FriendStatus.friends => Icons.people_alt_outlined,
      FriendStatus.outgoing => Icons.hourglass_top,
      FriendStatus.blocked => Icons.lock_open_outlined,
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
    return PatternScaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          FutureBuilder<FriendStatus>(
            future: _friendStatusFuture,
            builder: (context, snapshot) {
              final status = snapshot.data;
              if (status == null ||
                  status == FriendStatus.self ||
                  status == FriendStatus.signedOut ||
                  status == FriendStatus.blocked) {
                return const SizedBox.shrink();
              }
              return PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (_) => _confirmBlock(),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'block', child: Text('Block')),
                ],
              );
            },
          ),
        ],
      ),
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
            padding: const EdgeInsets.all(16),
            children: [
              ProfileHeader(
                profile: profile,
                displayName:
                    displayName.isEmpty ? 'Community member' : displayName,
                handle: handle,
                photoUrl: profile.photoUrl,
              ),
              const SizedBox(height: 16),
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
                  final status = statusSnapshot.data!;
                  return Column(
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _friendButton(status),
                          _followButton(status),
                        ],
                      ),
                      if (status == FriendStatus.friends) _friendDetails(),
                    ],
                  );
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
              const SizedBox(height: 16),
              ListenableBuilder(
                listenable: widget.store,
                builder: (context, _) {
                  final posts = widget.store.posts
                      .where((post) => post.ownerId == widget.userId)
                      .toList();
                  final likes =
                      posts.fold(0, (total, post) => total + post.likeCount);
                  final replies = posts.fold(
                      0, (total, post) => total + post.replies.length);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatGrid(rows: [
                        [
                          StatTile(
                            label: 'Friends',
                            stream: _friends,
                            onTap: () => _open(UserListScreen(
                              store: widget.store,
                              title: 'Friends',
                              load: () =>
                                  _socialService.friendIds(widget.userId),
                            )),
                          ),
                          StatTile(
                            label: 'Followers',
                            stream: _followers,
                            onTap: () => _open(UserListScreen(
                              store: widget.store,
                              title: 'Followers',
                              load: () =>
                                  _socialService.followerIds(widget.userId),
                            )),
                          ),
                          StatTile(
                            label: 'Following',
                            stream: _following,
                            onTap: () => _open(UserListScreen(
                              store: widget.store,
                              title: 'Following',
                              load: () =>
                                  _socialService.followingIds(widget.userId),
                            )),
                          ),
                        ],
                        [
                          StatTile(
                            label: 'Posts',
                            value: posts.length,
                            onTap: () => _open(PostsListScreen(
                              store: widget.store,
                              title: 'Posts',
                              userId: widget.userId,
                            )),
                          ),
                          StatTile(
                            label: 'Likes',
                            value: likes,
                            onTap: () => _open(PostsListScreen(
                              store: widget.store,
                              title: 'Liked posts',
                              userId: widget.userId,
                              likedOnly: true,
                            )),
                          ),
                          StatTile(
                            label: 'Replies',
                            value: replies,
                            onTap: () => _open(RepliesListScreen(
                              store: widget.store,
                              userId: widget.userId,
                            )),
                          ),
                        ],
                      ]),
                      ProfileAbout(profile: profile),
                      const SizedBox(height: 12),
                      Text('Posts',
                          style: Theme.of(context).textTheme.titleLarge),
                      if (posts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text('No posts yet.'),
                        ),
                      for (final post in posts)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: PostSummaryCard(post: post),
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

  void _open(Widget page) =>
      Navigator.of(context).push(instantRoute(page));
}
