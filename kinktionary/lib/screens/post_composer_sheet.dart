import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data_store.dart';
import '../models.dart';

class PostComposerSheet extends StatefulWidget {
  final DataStore store;
  const PostComposerSheet({super.key, required this.store});

  @override
  State<PostComposerSheet> createState() => _PostComposerSheetState();
}

class _PostComposerSheetState extends State<PostComposerSheet> {
  final _controller = TextEditingController();
  String _topic = 'Experience';
  bool _posting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  User? get _currentUser {
    try {
      return FirebaseAuth.instance.currentUser;
    } on Object {
      return null;
    }
  }

  Future<void> _publish() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _posting) return;

    setState(() => _posting = true);
    try {
      final user = _currentUser;
      await widget.store.addCommunityPost(
        CommunityPost(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          ownerId: user?.uid ?? 'local-preview-user',
          displayName: widget.store.profile.displayName.isNotEmpty
              ? widget.store.profile.displayName
              : user?.displayName ?? 'You',
          handle: widget.store.profile.handle,
          text: text,
          topic: _topic,
          createdAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not publish your post. Check your connection.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          18,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('New post', style: theme.textTheme.titleLarge),
                ),
                IconButton(
                  tooltip: 'Close composer',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            TextField(
              key: const ValueKey('community-composer'),
              controller: _controller,
              onChanged: (_) => setState(() {}),
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Share an experience or ask the community…',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _topic,
                    decoration: const InputDecoration(
                      labelText: 'Topic',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'Experience', child: Text('Experience')),
                      DropdownMenuItem(
                          value: 'Question', child: Text('Question')),
                      DropdownMenuItem(
                          value: 'Reflection', child: Text('Reflection')),
                      DropdownMenuItem(value: 'Advice', child: Text('Advice')),
                    ],
                    onChanged: (value) =>
                        setState(() => _topic = value ?? 'Experience'),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _controller.text.trim().isEmpty || _posting
                      ? null
                      : _publish,
                  icon: _posting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(_posting ? 'Posting' : 'Post'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
