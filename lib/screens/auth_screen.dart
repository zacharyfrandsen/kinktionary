import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/firebase_profile_service.dart';

final _usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,24}$');
final _phonePattern = RegExp(r'^[0-9+()\- ]{7,20}$');

/// Sign in / create account form shown to visitors who aren't signed in.
class AuthScreen extends StatefulWidget {
  final FirebaseProfileService service;
  final String? message;
  const AuthScreen({super.key, required this.service, this.message});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  Timer? _usernameDebounce;
  String _checkedHandle = '';
  bool? _handleAvailable;
  bool _checkingHandle = false;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  bool _creating = false;
  bool _phoneOptOut = false;
  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    for (final c in [_name, _username, _email, _password, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _handle =>
      _username.text.trim().replaceFirst('@', '').toLowerCase();

  void _onUsernameChanged(String _) {
    _usernameDebounce?.cancel();
    final handle = _handle;
    if (!_usernamePattern.hasMatch(handle)) {
      setState(() {
        _handleAvailable = null;
        _checkingHandle = false;
      });
      return;
    }
    setState(() {
      _handleAvailable = null;
      _checkingHandle = true;
    });
    _usernameDebounce = Timer(const Duration(milliseconds: 450), () async {
      bool? available;
      try {
        available = await widget.service.isHandleAvailable(handle);
      } on Object {
        available = null;
      }
      if (!mounted || handle != _handle) return;
      setState(() {
        _checkedHandle = handle;
        _handleAvailable = available;
        _checkingHandle = false;
      });
    });
  }

  Widget? _usernameStatus() {
    if (_checkingHandle) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return switch (_handleAvailable) {
      true => const Icon(Icons.check_circle, color: Colors.green, size: 20),
      false => const Icon(Icons.cancel, color: Colors.red, size: 20),
      null => null,
    };
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    var signedIn = false;
    try {
      if (_creating) {
        await widget.service.createAccount(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
          handle: _username.text.trim().replaceFirst('@', '').toLowerCase(),
          phone: _phone.text,
          phoneOptOut: _phoneOptOut,
        );
      } else {
        await widget.service.signIn(_email.text, _password.text);
      }
      signedIn = true;
    } on HandleUnavailableException {
      _fail('That username is already taken.');
    } on FirebaseAuthException catch (error) {
      _fail(_authMessage(error));
    } on FirebaseException catch (error) {
      _fail(error.message ?? 'Could not save your profile. Try again.');
    } catch (error) {
      _fail(_plainMessage(error));
    } finally {
      // Tells the browser's password manager (and Android's) that this was a
      // real sign-in, which is what makes it offer to save the credentials.
      if (signedIn) TextInput.finishAutofillContext();
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Firebase reports a rejected App Check token as a plain message, and the
  /// advice that suits it ("check your connection") is exactly wrong, so it
  /// gets its own wording.
  String _plainMessage(Object error) => error.toString().toLowerCase().contains(
        'app check',
      )
          ? 'App Check rejected this build. Its debug token has to be registered '
              'for this app before sign-in will work.'
          : 'Unable to connect. Check your connection and try again.';

  void _fail(String message) {
    if (mounted) setState(() => _error = message);
  }

  String _authMessage(FirebaseAuthException error) => switch (error.code) {
        'email-already-in-use' => 'An account already uses this email.',
        'invalid-email' => 'Enter a valid email address.',
        'weak-password' => 'Choose a stronger password.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Email or password is incorrect.',
        'network-request-failed' =>
          'Network unavailable. Try again when connected.',
        _ => error.message ?? 'Authentication failed. Please try again.',
      };

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      _fail('Enter your email address first.');
      return;
    }
    try {
      await widget.service.sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
      }
    } on FirebaseAuthException catch (error) {
      _fail(_authMessage(error));
    }
  }

  InputDecoration _decoration(String label, {String? prefix, String? hint}) =>
      InputDecoration(
        labelText: label,
        prefixText: prefix,
        hintText: hint,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                _creating ? 'Create your account' : 'Welcome back',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                widget.message ??
                    (_creating
                        ? 'Join the community to post, reply, follow and '
                            'add friends.'
                        : 'Sign in to reach your profile and the community.'),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Sign in')),
                  ButtonSegment(value: true, label: Text('Create account')),
                ],
                selected: {_creating},
                onSelectionChanged: _busy
                    ? null
                    : (value) => setState(() {
                          _creating = value.first;
                          _error = null;
                        }),
              ),
              const SizedBox(height: 20),
              // One group, so the browser's password manager and Android's
              // autofill can fill the email and password together rather than
              // one field at a time.
              AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_creating) ...[
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.name],
                          textInputAction: TextInputAction.next,
                          decoration: _decoration('Name'),
                          validator: (value) {
                            final name = value?.trim() ?? '';
                            if (name.isEmpty) return 'Enter your name';
                            if (name.length > 80) {
                              return 'Use 80 characters or fewer';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _username,
                          autocorrect: false,
                          // One hint only: the web engine passes the first one
                        // through, and this is the name a password manager
                        // saves the account's login under.
                        autofillHints: const [AutofillHints.username],
                          textInputAction: TextInputAction.next,
                          onChanged: _onUsernameChanged,
                          decoration: _decoration('Username', prefix: '@')
                              .copyWith(suffixIcon: _usernameStatus()),
                          validator: (value) {
                            final handle =
                                (value ?? '').trim().replaceFirst('@', '');
                            if (!_usernamePattern.hasMatch(handle)) {
                              return 'Use 3–24 letters, numbers, or underscores';
                            }
                            if (_handleAvailable == false &&
                                _checkedHandle == handle.toLowerCase()) {
                              return 'That username is already taken.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        // Signing in is a username/password form as far as a
                        // password manager is concerned; signing up is not.
                        autofillHints: _creating
                            ? const [AutofillHints.email]
                            : const [
                                AutofillHints.username,
                                AutofillHints.email,
                              ],
                        textInputAction: TextInputAction.next,
                        decoration: _decoration('Email'),
                        validator: (value) =>
                            value == null || !value.contains('@')
                                ? 'Enter a valid email address'
                                : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: !_showPassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: _creating
                            ? const [AutofillHints.newPassword]
                            : const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: _decoration('Password').copyWith(
                          suffixIcon: IconButton(
                            tooltip: _showPassword
                                ? 'Hide password'
                                : 'Show password',
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                            icon: Icon(_showPassword
                                ? Icons.visibility_off
                                : Icons.visibility),
                          ),
                        ),
                        validator: (value) => value == null || value.length < 6
                            ? 'Password must be at least 6 characters'
                            : null,
                      ),
                      if (_creating) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phone,
                          enabled: !_phoneOptOut,
                          keyboardType: TextInputType.phone,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          decoration: _decoration('Phone number'),
                          validator: (value) {
                            if (_phoneOptOut) return null;
                            return _phonePattern.hasMatch(value?.trim() ?? '')
                                ? null
                                : 'Enter a valid phone number, or opt out below';
                          },
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _phoneOptOut,
                          onChanged: (value) =>
                              setState(() => _phoneOptOut = value ?? false),
                          title:
                              const Text("I'd rather not share a phone number"),
                          subtitle: const Text(
                            'Optional. Your number is private and never shown '
                            'on your profile.',
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!,
                            style: TextStyle(color: theme.colorScheme.error)),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: Text(_busy
                              ? 'Please wait…'
                              : _creating
                                  ? 'Create account'
                                  : 'Sign in'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!_creating)
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : _resetPassword,
                    child: const Text('Forgot password?'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
