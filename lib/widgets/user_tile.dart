import 'package:flutter/material.dart';

import '../models.dart';
import '../services/firebase_social_service.dart';

final _profileCache = <String, Future<UserProfile>>{};

Future<UserProfile> _profileFor(String userId) =>
    _profileCache.putIfAbsent(userId, () async {
      try {
        return await FirebaseSocialService().loadProfile(
          userId,
          fallback: const UserProfile(displayName: 'Community member'),
        );
      } on Object {
        _profileCache.remove(userId);
        return const UserProfile(displayName: 'Community member');
      }
    });

/// Avatar, name and handle for a user id, with optional extras below the handle.
class UserTile extends StatelessWidget {
  final String userId;
  final String? nickname;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const UserTile({
    super.key,
    required this.userId,
    this.nickname,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<UserProfile>(
      future: _profileFor(userId),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = profile?.displayName.isNotEmpty == true
            ? profile!.displayName
            : 'Community member';
        final hasNickname = nickname != null && nickname!.isNotEmpty;
        final photo = profile?.photoUrl;
        return ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.secondaryContainer,
            backgroundImage: photo == null ? null : NetworkImage(photo),
            child: photo == null
                ? Icon(
                    Icons.person_outline,
                    color: theme.colorScheme.onSecondaryContainer,
                  )
                : null,
          ),
          title: Text(hasNickname ? nickname! : name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasNickname) Text(name),
              if (profile?.handle.isNotEmpty == true)
                Text('@${profile!.handle}'),
              if (subtitle != null) subtitle!,
            ],
          ),
          trailing: trailing,
        );
      },
    );
  }
}
