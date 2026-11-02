import 'package:flutter/material.dart';

import '../instant_route.dart';
import '../data_store.dart';
import '../services/firebase_social_service.dart';
import '../social_models.dart';
import '../widgets/friend_edit_sheet.dart';
import '../widgets/pattern_background.dart';
import '../widgets/user_tile.dart';
import 'public_profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  final DataStore store;
  const FriendsScreen({super.key, required this.store});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _service = FirebaseSocialService();
  String? _tagFilter;

  void _openProfile(String userId) {
    Navigator.of(context).push(
      instantRoute(PublicProfileScreen(
          store: widget.store,
          userId: userId,
          displayName: '',
          handle: '',
        )),
    );
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _confirmAndRun({
    required String title,
    required String body,
    required String action,
    required Future<void> Function() run,
    required String failure,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await run();
    } on Object {
      if (mounted) _message(failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: PatternScaffold(
        appBar: AppBar(
          title: const Text('Friends'),
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Friends'),
              Tab(
                child: StreamBuilder<List<FriendRequest>>(
                  stream: _service.incomingRequests(),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.length ?? 0;
                    return Text(count == 0 ? 'Requests' : 'Requests ($count)');
                  },
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(children: [_friendsTab(), _requestsTab()]),
      ),
    );
  }

  Widget _friendsTab() => StreamBuilder<List<Friend>>(
        stream: _service.friends(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _Empty('Friends could not be loaded.');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data!;
          if (all.isEmpty) {
            return const _Empty(
              'No friends yet. Open someone\u2019s profile from a post or '
              'reply to send a request.',
            );
          }
          final usedTags = FriendTags.presets
              .where((tag) => all.any((friend) => friend.tags.contains(tag)))
              .toList();
          final shown = _tagFilter == null
              ? all
              : all.where((f) => f.tags.contains(_tagFilter)).toList();
          return Column(
            children: [
              if (usedTags.isNotEmpty)
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: const Text('All'),
                          selected: _tagFilter == null,
                          onSelected: (_) => setState(() => _tagFilter = null),
                        ),
                      ),
                      for (final tag in usedTags)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(tag),
                            selected: _tagFilter == tag,
                            onSelected: (_) => setState(() => _tagFilter = tag),
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: shown.isEmpty
                    ? const _Empty('No friends with that label.')
                    : ListView.builder(
                        itemCount: shown.length,
                        itemBuilder: (context, index) =>
                            _friendCard(shown[index]),
                      ),
              ),
            ],
          );
        },
      );

  Widget _friendCard(Friend friend) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: UserTile(
          userId: friend.id,
          nickname: friend.nickname,
          onTap: () => _openProfile(friend.id),
          subtitle: friend.tags.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final tag in friend.tags)
                        Chip(
                          label: Text(tag),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
          trailing: PopupMenuButton<String>(
            tooltip: 'Friend options',
            onSelected: (action) {
              switch (action) {
                case 'edit':
                  showFriendEditSheet(
                    context,
                    service: _service,
                    friend: friend,
                  );
                case 'remove':
                  _confirmAndRun(
                    title: 'Remove friend?',
                    body: 'You will no longer be friends. They are not '
                        'notified.',
                    action: 'Remove',
                    run: () => _service.removeFriend(friend.id),
                    failure: 'Could not remove friend.',
                  );
                case 'block':
                  _confirmAndRun(
                    title: 'Block this person?',
                    body: 'They are removed from your friends and their posts '
                        'and replies are hidden from you. They cannot send '
                        'you requests or reply to your posts.',
                    action: 'Block',
                    run: () => _service.blockUser(friend.id),
                    failure: 'Could not block.',
                  );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit labels')),
              PopupMenuItem(value: 'remove', child: Text('Remove friend')),
              PopupMenuItem(value: 'block', child: Text('Block')),
            ],
          ),
        ),
      );

  Widget _requestsTab() => StreamBuilder<List<FriendRequest>>(
        stream: _service.incomingRequests(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _Empty('Requests could not be loaded.');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = snapshot.data!;
          if (requests.isEmpty) return const _Empty('No pending requests.');
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                child: Column(
                  children: [
                    UserTile(
                      userId: request.senderId,
                      onTap: () => _openProfile(request.senderId),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _respond(request, accept: true),
                              child: const Text('Accept'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _respond(request, accept: false),
                              child: const Text('Decline'),
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
        },
      );

  Future<void> _respond(FriendRequest request, {required bool accept}) async {
    try {
      if (accept) {
        await _service.acceptFriendRequest(request.senderId);
      } else {
        await _service.respondToFriendRequest(request.senderId, accept: false);
      }
    } on Object {
      if (mounted) _message('Could not update the request. Try again.');
    }
  }
}

class _Empty extends StatelessWidget {
  final String message;
  const _Empty(this.message);

  @override
  Widget build(BuildContext context) => Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      );
}
