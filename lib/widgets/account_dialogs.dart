import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

String _message(FirebaseAuthException e) => switch (e.code) {
      'wrong-password' ||
      'invalid-credential' =>
        'Your current password is incorrect.',
      'email-already-in-use' => 'An account already uses that email.',
      'invalid-email' => 'Enter a valid email address.',
      'weak-password' => 'Choose a stronger password.',
      'too-many-requests' => 'Too many attempts. Try again later.',
      'network-request-failed' => 'Network unavailable. Try again.',
      _ => e.message ?? 'Something went wrong. Try again.',
    };

Future<void> _reauthenticate(User user, String password) =>
    user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email!, password: password),
    );

enum AccountChange { email, password }

/// Asks for the current password, then changes the sign-in email or password.
/// Returns a confirmation message on success.
Future<String?> showAccountChangeDialog(
  BuildContext context,
  User user,
  AccountChange change,
) {
  return showDialog<String>(
    context: context,
    builder: (_) => _AccountChangeDialog(user: user, change: change),
  );
}

class _AccountChangeDialog extends StatefulWidget {
  final User user;
  final AccountChange change;
  const _AccountChangeDialog({required this.user, required this.change});

  @override
  State<_AccountChangeDialog> createState() => _AccountChangeDialogState();
}

class _AccountChangeDialogState extends State<_AccountChangeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;
  bool _show = false;
  String? _error;

  bool get _isEmail => widget.change == AccountChange.email;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _reauthenticate(widget.user, _current.text);
      if (_isEmail) {
        await widget.user.verifyBeforeUpdateEmail(_next.text.trim());
      } else {
        await widget.user.updatePassword(_next.text);
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        _isEmail
            ? 'Check ${_next.text.trim()} to confirm the new email.'
            : 'Password updated.',
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } on Object {
      if (mounted) setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEmail ? 'Change email' : 'Change password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _next,
              obscureText: !_isEmail && !_show,
              keyboardType:
                  _isEmail ? TextInputType.emailAddress : TextInputType.text,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: _isEmail ? 'New email' : 'New password',
              ),
              validator: (v) => _isEmail
                  ? (v == null || !v.contains('@')
                      ? 'Enter a valid email address'
                      : null)
                  : (v == null || v.length < 6
                      ? 'Use at least 6 characters'
                      : null),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _current,
              obscureText: !_show,
              decoration: InputDecoration(
                labelText: 'Current password',
                suffixIcon: IconButton(
                  tooltip: _show ? 'Hide password' : 'Show password',
                  onPressed: () => setState(() => _show = !_show),
                  icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                ),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter your current password' : null,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Saving…' : 'Update'),
        ),
      ],
    );
  }
}
