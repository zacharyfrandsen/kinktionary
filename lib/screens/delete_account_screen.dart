import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data_store.dart';
import '../services/account_deletion_service.dart';
import '../widgets/pattern_background.dart';

/// Irreversibly deletes the signed-in account and its data.
///
/// The password is asked for because Firebase requires a recent sign-in before
/// an account can be removed, and because the action cannot be undone.
class DeleteAccountScreen extends StatefulWidget {
  final DataStore store;

  /// Injected by tests; production uses [AccountDeletionService].
  final Future<void> Function(String password)? deleteAccount;

  const DeleteAccountScreen({
    super.key,
    required this.store,
    this.deleteAccount,
  });

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _canDelete =>
      !_busy &&
      _password.text.isNotEmpty &&
      _confirmation.text.trim().toUpperCase() == 'DELETE';

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final password = _password.text;
    setState(() {
      _busy = true;
      _error = null;
    });
    // Anything queued for the server would otherwise be written back while the
    // deletion is running.
    widget.store.cancelPendingWrites();
    try {
      final delete = widget.deleteAccount ??
          (String value) =>
              AccountDeletionService().deleteAccount(password: value);
      await delete(password);
      await widget.store.clearAccountData();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).popUntil((route) => route.isFirst);
      messenger.showSnackBar(
        const SnackBar(content: Text('Your account was deleted.')),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _messageFor(error);
        _busy = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _error = 'Your account could not be deleted. Check your connection '
            'and try again.';
        _busy = false;
      });
    }
  }

  String _messageFor(FirebaseAuthException error) => switch (error.code) {
        'wrong-password' ||
        'invalid-credential' =>
          'That password is not right.',
        'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
        'requires-recent-login' => 'Sign in again, then delete your account.',
        'network-request-failed' =>
          'You need a connection to delete your account.',
        _ => 'Your account could not be deleted. Try again in a moment.',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    return PatternScaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: error),
                      const SizedBox(width: 8),
                      Text('This cannot be undone',
                          style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Deleting your account removes it for good, including:',
                  ),
                  const SizedBox(height: 8),
                  for (final item in const [
                    'your profile, photo and handle',
                    'your posts and the replies on them',
                    'replies and likes you left on other posts',
                    'friends, followers and blocked lists',
                    'bookmarks, notes and progress saved on this device',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  '),
                          Expanded(child: Text(item)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Your password',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmation,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _canDelete ? _delete() : null,
            decoration: const InputDecoration(
              labelText: 'Type DELETE to confirm',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: error)),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _canDelete ? _delete : null,
            style: FilledButton.styleFrom(
              backgroundColor: error,
              foregroundColor: theme.colorScheme.onError,
            ),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever_outlined),
            label: Text(_busy ? 'Deleting…' : 'Delete my account'),
          ),
        ],
      ),
    );
  }
}
