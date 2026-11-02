import 'package:flutter/material.dart';

import '../services/firebase_social_service.dart';
import '../social_models.dart';

/// Lets the user pick relationship tags and a private nickname for a friend.
Future<void> showFriendEditSheet(
  BuildContext context, {
  required FirebaseSocialService service,
  required Friend friend,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FriendEditSheet(service: service, friend: friend),
    );

class _FriendEditSheet extends StatefulWidget {
  final FirebaseSocialService service;
  final Friend friend;

  const _FriendEditSheet({required this.service, required this.friend});

  @override
  State<_FriendEditSheet> createState() => _FriendEditSheetState();
}

class _FriendEditSheetState extends State<_FriendEditSheet> {
  late final TextEditingController _nickname;
  late final Set<String> _tags;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _nickname = TextEditingController(text: widget.friend.nickname);
    _tags = {...widget.friend.tags};
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.service.updateFriend(
        widget.friend.id,
        tags: FriendTags.presets.where(_tags.contains).toList(),
        nickname: _nickname.text,
      );
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final atLimit = _tags.length >= FriendTags.maxPerFriend;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Customize friend', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Only you can see these labels.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('friend-nickname'),
            controller: _nickname,
            maxLength: FriendTags.maxNicknameLength,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nickname',
            ),
          ),
          const SizedBox(height: 8),
          Text('Relationship', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final tag in FriendTags.presets)
                FilterChip(
                  label: Text(tag),
                  selected: _tags.contains(tag),
                  onSelected: !_tags.contains(tag) && atLimit
                      ? null
                      : (selected) => setState(
                            () => selected ? _tags.add(tag) : _tags.remove(tag),
                          ),
                ),
            ],
          ),
          if (atLimit)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'You can pick up to ${FriendTags.maxPerFriend} labels.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving\u2026' : 'Save'),
            ),
          ),
        ],
      ),
    );
  }
}
