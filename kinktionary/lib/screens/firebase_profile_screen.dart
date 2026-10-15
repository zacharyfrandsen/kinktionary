import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data_store.dart';
import '../models.dart';
import '../services/firebase_profile_service.dart';
import 'profile_screen.dart';

class FirebaseProfileScreen extends StatefulWidget {
  final DataStore store;
  const FirebaseProfileScreen({super.key, required this.store});

  @override
  State<FirebaseProfileScreen> createState() => _FirebaseProfileScreenState();
}

class _FirebaseProfileScreenState extends State<FirebaseProfileScreen> {
  final _authFormKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _handleController = TextEditingController();
  final _bioController = TextEditingController();
  final _picker = ImagePicker();
  final _profileLoads = <String, Future<UserProfile>>{};
  FirebaseProfileService? _service;
  String _pronouns = '';
  String? _photoUrl;
  String? _loadedProfileUid;
  String? _authError;
  String? _profileError;
  bool _creatingAccount = false;
  bool _editingSettings = false;
  bool _authBusy = false;
  bool _saving = false;
  bool _uploadingPhoto = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    try {
      _service = FirebaseProfileService();
    } on Object {
      _service = null;
    }
    final profile = widget.store.profile;
    _displayNameController.text = profile.displayName;
    _handleController.text = profile.handle;
    _pronouns = profile.pronouns;
    _bioController.text = profile.bio;
    _photoUrl = profile.photoUrl;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _handleController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<UserProfile> _profileFor(User user) {
    return _profileLoads.putIfAbsent(user.uid, () async {
      final profile = await _service!.loadProfile(user);
      if (mounted && _loadedProfileUid != user.uid) {
        _loadedProfileUid = user.uid;
        _displayNameController.text = profile.displayName;
        _handleController.text = profile.handle;
        _pronouns = profile.pronouns;
        _bioController.text = profile.bio;
        _photoUrl = profile.photoUrl ?? user.photoURL;
        await widget.store.saveProfile(profile);
      }
      return profile;
    });
  }

  Future<void> _submitAuth() async {
    if (!_authFormKey.currentState!.validate() || _service == null) return;
    setState(() {
      _authBusy = true;
      _authError = null;
    });
    try {
      if (_creatingAccount) {
        await _service!.createAccount(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        await _service!.signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _authError = _authMessage(error));
    } catch (_) {
      if (mounted) {
        setState(() => _authError = 'Unable to connect. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  String _authMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'email-already-in-use' => 'An account already uses this email.',
      'invalid-email' => 'Enter a valid email address.',
      'weak-password' => 'Choose a stronger password.',
      'user-not-found' || 'wrong-password' || 'invalid-credential' =>
        'Email or password is incorrect.',
      'network-request-failed' => 'Network unavailable. Try again when connected.',
      _ => error.message ?? 'Authentication failed. Please try again.',
    };
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _authError = 'Enter your email address first.');
      return;
    }
    try {
      await _service!.sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _authError = _authMessage(error));
    }
  }

  UserProfile _currentProfile({String? photoUrl}) => UserProfile(
        displayName: _displayNameController.text.trim(),
        handle: _handleController.text
            .trim()
            .replaceFirst(RegExp(r'^@'), '')
            .toLowerCase(),
        pronouns: _pronouns,
        bio: _bioController.text.trim(),
        photoUrl: photoUrl ?? _photoUrl,
      );

  Future<void> _saveProfile(User? user) async {
    if (!_profileFormKey.currentState!.validate()) return;
    final profile = _currentProfile();
    setState(() {
      _saving = true;
      _profileError = null;
    });
    try {
      if (user != null && _service != null) {
        await _service!.saveProfile(user, profile);
        _profileLoads.remove(user.uid);
      }
      await widget.store.saveProfile(profile);
      if (mounted) {
        setState(() => _editingSettings = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(user == null
                ? 'Profile saved on this device.'
                : 'Profile saved to your account.'),
          ),
        );
      }
    } on HandleUnavailableException {
      if (mounted) {
        setState(() => _profileError = 'That username is already taken.');
      }
    } on FirebaseException catch (error) {
      if (mounted) setState(() => _profileError = error.message ?? 'Could not save profile.');
    } catch (_) {
      if (mounted) setState(() => _profileError = 'Could not save profile. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePhoto(User? user) async {
    if (user == null || _service == null) {
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

    setState(() => _uploadingPhoto = true);
    try {
      final url = await _service!.uploadProfilePhoto(user, image);
      await _service!.saveProfile(user, _currentProfile(photoUrl: url));
      final profile = _currentProfile(photoUrl: url);
      await widget.store.saveProfile(profile);
      if (mounted) setState(() => _photoUrl = url);
    } on ProfilePhotoTooLargeException {
      if (mounted) setState(() => _profileError = 'Choose an image smaller than 5 MB.');
    } on InvalidProfilePhotoException {
      if (mounted) setState(() => _profileError = 'Choose a JPEG, PNG, or WebP image.');
    } on HandleUnavailableException {
      if (mounted) setState(() => _profileError = 'That username is already taken.');
    } on FirebaseException catch (error) {
      if (mounted) setState(() => _profileError = error.message ?? 'Photo upload failed.');
    } catch (_) {
      if (mounted) setState(() => _profileError = 'Photo upload failed. Try again.');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = _service;
    if (service == null) {
      return Column(
        children: [
          const Card(
            margin: EdgeInsets.all(12),
            child: ListTile(
              leading: Icon(Icons.cloud_off_outlined),
              title: Text('Firebase is unavailable'),
              subtitle: Text('Using the on-device profile until Firebase initializes.'),
            ),
          ),
          Expanded(child: ProfileScreen(store: widget.store)),
        ],
      );
    }

    return StreamBuilder<User?>(
      stream: service.authStateChanges,
      initialData: service.currentUser,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _messageScreen('Could not read sign-in state.');
        }
        final user = snapshot.data;
        if (user == null) return _buildAuthForm();

        return FutureBuilder<UserProfile>(
          key: ValueKey(user.uid),
          future: _profileFor(user),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.hasError) {
              return _messageScreen('Could not load your cloud profile.');
            }
            if (!profileSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _editingSettings
              ? _buildProfileForm(user)
              : _buildProfileOverview(user);
          },
        );
      },
    );
  }

  Widget _messageScreen(String message) => SafeArea(
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(message, textAlign: TextAlign.center),
            ),
          ),
        ),
      );

  Widget _buildAuthForm() {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Profile', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Sign in to save your profile and join the community.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Form(
            key: _authFormKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || !value.contains('@')
                      ? 'Enter a valid email address'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _showPassword ? 'Hide password' : 'Show password',
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                      icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                  validator: (value) => value == null || value.length < 6
                      ? 'Password must be at least 6 characters'
                      : null,
                ),
                if (_authError != null) ...[
                  const SizedBox(height: 12),
                  Text(_authError!, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _authBusy ? null : _submitAuth,
                    child: Text(_authBusy
                        ? 'Please wait…'
                        : _creatingAccount
                            ? 'Create account'
                            : 'Sign in'),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: _authBusy
                  ? null
                  : () => setState(() {
                        _creatingAccount = !_creatingAccount;
                        _authError = null;
                      }),
              child: Text(_creatingAccount
                  ? 'Already have an account? Sign in'
                  : 'Create an account'),
            ),
          ),
          if (!_creatingAccount)
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: _authBusy ? null : _resetPassword,
                child: const Text('Forgot password?'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileOverview(User user) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final profile = widget.store.profile;
        final posts = widget.store.posts
            .where((post) => post.ownerId == user.uid)
            .toList();
        final likes = posts.fold(0, (total, post) => total + post.likeCount);
        final replies =
            posts.fold(0, (total, post) => total + post.replies.length);
        final photo = profile.photoUrl ?? user.photoURL;

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    backgroundImage: photo == null ? null : NetworkImage(photo),
                    child: photo == null
                        ? Icon(Icons.person_outline,
                            size: 40,
                            color: theme.colorScheme.onSecondaryContainer)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName.isEmpty
                              ? user.displayName ?? 'Your profile'
                              : profile.displayName,
                          style: theme.textTheme.titleLarge,
                        ),
                        if (profile.handle.isNotEmpty)
                          Text('@${profile.handle}',
                              style: theme.textTheme.bodyMedium),
                        if (profile.pronouns.isNotEmpty)
                          Text(profile.pronouns,
                              style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: () => _service!.signOut(),
                    icon: const Icon(Icons.logout),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _ProfileStat(label: 'Posts', value: posts.length)),
                  const SizedBox(width: 8),
                  Expanded(child: _ProfileStat(label: 'Likes', value: likes)),
                  const SizedBox(width: 8),
                  Expanded(child: _ProfileStat(label: 'Replies', value: replies)),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('About', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(profile.bio.isEmpty
                          ? 'Add a short bio in Profile settings.'
                          : profile.bio),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => setState(() => _editingSettings = true),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Profile settings'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileForm(User user) {
    final theme = Theme.of(context);
    final imageUrl = _photoUrl ?? user.photoURL;
    return SafeArea(
      child: Form(
        key: _profileFormKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      backgroundImage:
                          imageUrl == null ? null : NetworkImage(imageUrl),
                      child: imageUrl == null
                          ? Icon(Icons.person_outline,
                              size: 38,
                              color: theme.colorScheme.onSecondaryContainer)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: IconButton.filledTonal(
                        tooltip: 'Change profile photo',
                        onPressed: _uploadingPhoto ? null : () => _changePhoto(user),
                        icon: _uploadingPhoto
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.photo_camera_outlined, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Profile settings', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(user.email ?? '', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Back to profile',
                  onPressed: () => setState(() => _editingSettings = false),
                  icon: const Icon(Icons.close),
                ),
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: () => _service!.signOut(),
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _displayNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a display name'
                  : value.trim().length > 80
                      ? 'Use 80 characters or fewer'
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
            DropdownButtonFormField<String>(
              initialValue: _pronouns,
              decoration: const InputDecoration(
                labelText: 'Pronouns',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '', child: Text('Prefer not to say')),
                DropdownMenuItem(value: 'She/her', child: Text('She/her')),
                DropdownMenuItem(value: 'He/him', child: Text('He/him')),
                DropdownMenuItem(value: 'They/them', child: Text('They/them')),
                DropdownMenuItem(value: 'She/they', child: Text('She/they')),
                DropdownMenuItem(value: 'He/they', child: Text('He/they')),
                DropdownMenuItem(value: 'Any pronouns', child: Text('Any pronouns')),
                DropdownMenuItem(value: 'Ask me', child: Text('Ask me')),
              ],
              onChanged: (value) => setState(() => _pronouns = value ?? ''),
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
              validator: (value) => (value?.length ?? 0) > 160
                  ? 'Use 160 characters or fewer'
                  : null,
            ),
            if (_profileError != null) ...[
              const SizedBox(height: 8),
              Text(_profileError!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _saving ? null : () => _saveProfile(user),
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

class _ProfileStat extends StatelessWidget {
  final String label;
  final int value;

  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Text('$value', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}
