import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data_store.dart';
import '../models.dart';
import '../services/auth_state.dart';
import '../services/firebase_profile_service.dart';
import '../widgets/account_dialogs.dart';
import '../widgets/color_picker.dart';
import '../widgets/pattern_background.dart';
import '../widgets/profile_header.dart';

const _pronounOptions = [
  '',
  'She/her',
  'He/him',
  'They/them',
  'She/they',
  'He/they',
  'Any pronouns',
  'Ask me',
];

const _interestOptions = [
  'Learning',
  'Communication',
  'Negotiation',
  'Aftercare',
  'Sensory play',
  'Roleplay',
  'Bondage',
  'Impact play',
  'Power exchange',
  'Service',
  'Pet play',
  'Switching',
  'Polyamory',
  'Events',
  'Community',
  'Mentoring',
];

final _phonePattern = RegExp(r'^[0-9+()\- ]{7,20}$');

class EditProfileScreen extends StatefulWidget {
  final DataStore store;
  const EditProfileScreen({super.key, required this.store});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _name = TextEditingController();
  final _handle = TextEditingController();
  final _bio = TextEditingController();
  final _status = TextEditingController();
  final _location = TextEditingController();
  final _phone = TextEditingController();
  FirebaseProfileService? _service;
  User? _user;
  String _pronouns = '';
  String? _photoUrl;
  final _interests = <String>[];
  int? _accent;
  int? _bannerStart;
  int? _bannerEnd;
  bool _phoneOptOut = true;
  late final bool _handleLocked = widget.store.profile.handle.isNotEmpty;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _user = currentUserOrNull();
    if (_user != null) {
      try {
        _service = FirebaseProfileService();
      } on Object {
        _service = null;
      }
    }
    final p = widget.store.profile;
    _name.text = p.displayName;
    _handle.text = p.handle;
    _bio.text = p.bio;
    _status.text = p.status;
    _location.text = p.location;
    _pronouns = _pronounOptions.contains(p.pronouns) ? p.pronouns : '';
    _photoUrl = p.photoUrl ?? _user?.photoURL;
    _interests.addAll(p.interests);
    _accent = p.accent;
    _bannerStart = p.bannerStart;
    _bannerEnd = p.bannerEnd;
    _baseline = _snapshot();
    _loadContact();
  }

  Future<void> _loadContact() async {
    final user = _user;
    final service = _service;
    if (user == null || service == null) return;
    try {
      final contact = await service.loadContact(user);
      if (!mounted) return;
      setState(() {
        _phone.text = contact.phone;
        _phoneOptOut = contact.optOut;
        _baseline = _snapshot();
      });
    } on Object {
      // Contact details are optional; leave the fields empty.
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _handle, _bio, _status, _location, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  late String _baseline;

  String _snapshot() => jsonEncode([
        _draft().toMap(),
        _phone.text.trim(),
        _phoneOptOut,
      ]);

  bool get _dirty => _snapshot() != _baseline;

  Widget _saveBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Discard'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving' : 'Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  UserProfile _draft() => UserProfile(
        displayName: _name.text.trim(),
        handle:
            _handle.text.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase(),
        pronouns: _pronouns,
        bio: _bio.text.trim(),
        photoUrl: _photoUrl,
        status: _status.text.trim(),
        location: _location.text.trim(),
        interests: List.of(_interests),
        accent: _accent,
        bannerStart: _bannerStart,
        bannerEnd: _bannerEnd,
      );

  void _toggleInterest(String interest) {
    setState(() {
      if (!_interests.remove(interest) &&
          _interests.length < UserProfile.maxInterests) {
        _interests.add(interest);
      }
    });
  }

  Future<void> _changePhone() async {
    final result = await showDialog<({String phone, bool optOut})>(
      context: context,
      builder: (_) => _PhoneDialog(phone: _phone.text, optOut: _phoneOptOut),
    );
    if (result == null) return;
    setState(() {
      _phone.text = result.phone;
      _phoneOptOut = result.optOut;
    });
  }

  Future<void> _changeAccount(AccountChange change) async {
    final message = await showAccountChangeDialog(context, _user!, change);
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _changePhoto() async {
    final user = _user;
    final service = _service;
    if (user == null || service == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to upload a profile photo.')),
      );
      return;
    }
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 84,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (image == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final url = await service.uploadProfilePhoto(user, image);
      if (mounted) setState(() => _photoUrl = url);
    } on ProfilePhotoTooLargeException {
      _fail('Choose an image smaller than 5 MB.');
    } on InvalidProfilePhotoException {
      _fail('Choose a JPEG, PNG, or WebP image.');
    } on FirebaseException catch (error) {
      _fail(error.message ?? 'Photo upload failed.');
    } catch (_) {
      _fail('Photo upload failed. Try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _fail(String message) {
    if (mounted) setState(() => _error = message);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = _draft();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = _user;
      final service = _service;
      if (user != null && service != null) {
        await service.saveProfile(user, profile);
        await service.saveContact(
          user,
          phone: _phone.text,
          optOut: _phoneOptOut,
        );
      }
      await widget.store.saveProfile(profile);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved.')),
      );
    } on HandleUnavailableException {
      _fail('That username is already taken.');
    } on FirebaseException catch (error) {
      _fail(error.message ?? 'Could not save profile.');
    } catch (_) {
      _fail('Could not save profile. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = _draft();
    return PatternScaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      bottomNavigationBar: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
        child: _dirty || _saving
            ? KeyedSubtree(key: const ValueKey('bar'), child: _saveBar())
            : const SizedBox.shrink(key: ValueKey('none')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ProfileHeader(
              profile: draft,
              displayName:
                  draft.displayName.isEmpty ? 'Your name' : draft.displayName,
              handle: draft.handle,
              photoUrl: _photoUrl,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _uploading ? null : _changePhoto,
                icon: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_camera_outlined),
                label: const Text('Change photo'),
              ),
            ),
            const SizedBox(height: 4),
            Text('Profile colours', style: theme.textTheme.titleMedium),
            Card(
              child: Column(
                children: [
                  ColorTile(
                    title: 'Accent colour',
                    color: _accent == null ? null : Color(_accent!),
                    fallback: theme.colorScheme.primary,
                    onChanged: (c) => setState(() => _accent = c.toARGB32()),
                    onReset: () => setState(() => _accent = null),
                  ),
                  ColorTile(
                    title: 'Banner gradient start',
                    color: _bannerStart == null ? null : Color(_bannerStart!),
                    fallback: theme.colorScheme.primaryContainer,
                    onChanged: (c) =>
                        setState(() => _bannerStart = c.toARGB32()),
                    onReset: () => setState(() => _bannerStart = null),
                  ),
                  ColorTile(
                    title: 'Banner gradient end',
                    color: _bannerEnd == null ? null : Color(_bannerEnd!),
                    fallback: theme.colorScheme.secondaryContainer,
                    onChanged: (c) => setState(() => _bannerEnd = c.toARGB32()),
                    onReset: () => setState(() => _bannerEnd = null),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Name',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a name'
                  : value.trim().length > 80
                      ? 'Use 80 characters or fewer'
                      : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _handle,
              autocorrect: false,
              enabled: !_handleLocked,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixText: '@',
                labelText: 'Username',
                helperText:
                    _handleLocked ? 'Usernames can\u2019t be changed.' : null,
              ),
              validator: (value) {
                final handle =
                    (value ?? '').trim().replaceFirst(RegExp(r'^@'), '');
                if (!RegExp(r'^[a-zA-Z0-9_]{3,24}$').hasMatch(handle)) {
                  return 'Use 3–24 letters, numbers, or underscores';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _pronouns,
              decoration: const InputDecoration(
                labelText: 'Pronouns',
              ),
              items: [
                for (final option in _pronounOptions)
                  DropdownMenuItem(
                    value: option,
                    child: Text(option.isEmpty ? 'Prefer not to say' : option),
                  ),
              ],
              onChanged: (value) => setState(() => _pronouns = value ?? ''),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _status,
              maxLength: 60,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Status',
                hintText: 'A short line under your name',
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _location,
              maxLength: 40,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                hintText: 'A city or region, as vague as you like',
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _bio,
              minLines: 3,
              maxLines: 5,
              maxLength: 160,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'About you',
                hintText: 'What would you like people to know?',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Text('Interests (${_interests.length}/${UserProfile.maxInterests})',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              // Without a run spacing the rows sit flush and read as one block
              // of touching pills, which is how they look on a wide window.
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final interest in {..._interestOptions, ..._interests})
                  FilterChip(
                    label: Text(interest),
                    selected: _interests.contains(interest),
                    onSelected: (_) => _toggleInterest(interest),
                  ),
              ],
            ),
            if (_user != null) ...[
              const SizedBox(height: 20),
              Text('Private profile details',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Only you can see these.', style: theme.textTheme.bodySmall),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.mail_outline),
                      title: Text(_user!.email ?? 'No email'),
                      trailing: TextButton(
                        onPressed: () => _changeAccount(AccountChange.email),
                        child: const Text('Change'),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.phone_outlined),
                      title: Text(_phoneOptOut || _phone.text.trim().isEmpty
                          ? 'No phone number'
                          : _phone.text.trim()),
                      trailing: TextButton(
                        onPressed: _changePhone,
                        child: Text(_phoneOptOut || _phone.text.trim().isEmpty
                            ? 'Add'
                            : 'Change'),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Password'),
                      trailing: TextButton(
                        onPressed: () => _changeAccount(AccountChange.password),
                        child: const Text('Change'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _PhoneDialog extends StatefulWidget {
  final String phone;
  final bool optOut;
  const _PhoneDialog({required this.phone, required this.optOut});

  @override
  State<_PhoneDialog> createState() => _PhoneDialogState();
}

class _PhoneDialogState extends State<_PhoneDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _phone = TextEditingController(text: widget.phone);
  late bool _optOut = widget.optOut;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Phone number'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _phone,
              enabled: !_optOut,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
              ),
              validator: (value) =>
                  _optOut || _phonePattern.hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Enter a valid phone number',
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _optOut,
              onChanged: (v) => setState(() => _optOut = v ?? true),
              title: const Text("I'd rather not share a phone number"),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              (phone: _optOut ? '' : _phone.text.trim(), optOut: _optOut),
            );
          },
          child: const Text('Done'),
        ),
      ],
    );
  }
}
