import 'package:flutter/material.dart';

import '../services/firebase_social_service.dart';
import '../social_models.dart';
import '../widgets/pattern_background.dart';
import '../widgets/user_tile.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirebaseSocialService();
    return PatternScaffold(
      appBar: AppBar(title: const Text('Blocked users')),
      body: StreamBuilder<List<BlockedUser>>(
        stream: service.blockedUsers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _Message('Blocked users could not be loaded.');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final blocked = snapshot.data!;
          if (blocked.isEmpty) {
            return const _Message(
              'You have not blocked anyone. Blocked people cannot send you '
              'requests or reply to your posts, and you will not see their '
              'posts or replies.',
            );
          }
          return ListView.builder(
            itemCount: blocked.length,
            itemBuilder: (context, index) => Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: UserTile(
                userId: blocked[index].id,
                trailing: TextButton(
                  onPressed: () async {
                    try {
                      await service.unblockUser(blocked[index].id);
                    } on Object {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not unblock.')),
                        );
                      }
                    }
                  },
                  child: const Text('Unblock'),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  const _Message(this.text);

  @override
  Widget build(BuildContext context) => Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(text, textAlign: TextAlign.center),
          ),
        ),
      );
}
