import 'package:flutter/material.dart';

import '../services/auth_state.dart';
import '../services/firebase_profile_service.dart';
import '../widgets/pattern_background.dart';

enum DataRequestType {
  deletion(
    'deletion',
    'Request data deletion',
    'Ask us to delete your account and the data stored with it: profile, '
        'posts, replies, friends and followers.',
  ),
  recovery(
    'recovery',
    'Request data recovery',
    'Lost access or removed something by mistake? Ask us to help restore your '
        'account or data.',
  );

  final String id;
  final String title;
  final String blurb;
  const DataRequestType(this.id, this.title, this.blurb);
}

class DataRequestScreen extends StatefulWidget {
  final DataRequestType type;
  const DataRequestScreen({super.key, required this.type});

  @override
  State<DataRequestScreen> createState() => _DataRequestScreenState();
}

class _DataRequestScreenState extends State<DataRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email =
      TextEditingController(text: currentUserOrNull()?.email ?? '');
  final _note = TextEditingController();
  bool _confirmed = false;
  bool _busy = false;
  String? _error;
  bool _sent = false;

  bool get _isDeletion => widget.type == DataRequestType.deletion;

  @override
  void dispose() {
    _email.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseProfileService().submitDataRequest(
        type: widget.type.id,
        email: _email.text,
        note: _note.text,
      );
      if (mounted) setState(() => _sent = true);
    } on Object {
      if (mounted) {
        setState(() => _error = _isDeletion && currentUserOrNull() == null
            ? 'Sign in to request deletion.'
            : 'Could not send your request. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PatternScaffold(
      appBar: AppBar(title: Text(widget.type.title)),
      body: _sent
          ? Center(
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 48, color: theme.colorScheme.primary),
                      const SizedBox(height: 12),
                      Text('Request received',
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const Text(
                        'We\u2019ll review it and contact you at the email '
                        'you gave.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(widget.type.blurb, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Contact email',
                    ),
                    validator: (value) => value == null || !value.contains('@')
                        ? 'Enter a valid email address'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _note,
                    maxLength: 500,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Anything we should know? (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (_isDeletion)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _confirmed,
                      onChanged: (v) => setState(() => _confirmed = v ?? false),
                      title: const Text(
                        'I understand this permanently removes my account '
                        'and can\u2019t be undone.',
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!,
                          style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed:
                        _busy || (_isDeletion && !_confirmed) ? null : _submit,
                    child: Text(_busy ? 'Sending…' : 'Send request'),
                  ),
                ],
              ),
            ),
    );
  }
}
