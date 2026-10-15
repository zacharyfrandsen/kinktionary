import 'package:flutter/material.dart';

import '../data_store.dart';
import '../models.dart';

class ProfileScreen extends StatefulWidget {
  final DataStore store;
  const ProfileScreen({super.key, required this.store});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _handleController;
  late final TextEditingController _pronounsController;
  late final TextEditingController _bioController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.store.profile;
    _displayNameController = TextEditingController(text: profile.displayName);
    _handleController = TextEditingController(text: profile.handle);
    _pronounsController = TextEditingController(text: profile.pronouns);
    _bioController = TextEditingController(text: profile.bio);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _handleController.dispose();
    _pronounsController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await widget.store.saveProfile(
        UserProfile(
          displayName: _displayNameController.text.trim(),
          handle: _handleController.text.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase(),
          pronouns: _pronounsController.text.trim(),
          bio: _bioController.text.trim(),
          photoUrl: widget.store.profile.photoUrl,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved on this device.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.person_outline,
                    size: 36,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Profile', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text('Your community identity',
                          style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Card(
              child: ListTile(
                leading: Icon(Icons.cloud_off_outlined),
                title: Text('Cloud account not connected'),
                subtitle: Text(
                  'Profile details are stored on this device until Firebase is configured.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _displayNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a display name'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _handleController,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              decoration: const InputDecoration(
                prefixText: '@',
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final handle = (value ?? '').trim().replaceFirst(RegExp(r'^@'), '');
                if (!RegExp(r'^[a-zA-Z0-9_]{3,24}$').hasMatch(handle)) {
                  return 'Use 3–24 letters, numbers, or underscores';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _pronounsController,
              decoration: const InputDecoration(
                labelText: 'Pronouns',
                hintText: 'Optional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _bioController,
              minLines: 3,
              maxLines: 5,
              maxLength: 160,
              decoration: const InputDecoration(
                labelText: 'About you',
                hintText: 'What would you like people to know?',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _saving ? null : _saveProfile,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving' : 'Save profile'),
            ),
          ],
        ),
      ),
    );
  }
}