import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../instant_route.dart';
import '../appearance.dart';
import '../data_store.dart';
import '../services/auth_state.dart';
import '../services/firebase_social_service.dart';
import '../social_models.dart';
import '../theme.dart';
import '../widgets/color_picker.dart';
import '../widgets/pattern_background.dart';
import 'blocked_users_screen.dart';
import 'consent_screen.dart';
import 'data_request_screen.dart';
import 'delete_account_screen.dart';
import 'donations_screen.dart';
import 'edit_profile_screen.dart';
import 'friends_screen.dart';
import 'open_source_screen.dart';
import 'profile_lists_screen.dart';
import 'saved_screen.dart';

class SettingsScreen extends StatelessWidget {
  final DataStore store;
  const SettingsScreen({super.key, required this.store});

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(instantRoute(page));

  Widget _page(String title, Widget body) => PatternScaffold(
        appBar: AppBar(title: Text(title)),
        body: body,
      );

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear saved data?'),
        content: const Text(
          'This removes all bookmarks and notes from this device. '
          'It can\u2019t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) await store.clearPersonalData();
  }

  @override
  Widget build(BuildContext context) {
    final user = currentUserOrNull();
    return PatternScaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _Section(
            title: 'Account',
            children: user == null
                ? const [
                    ListTile(
                      leading: Icon(Icons.person_outline),
                      title: Text('Not signed in'),
                      subtitle: Text(
                        'Sign in from the Profile tab to post, reply and add '
                        'friends.',
                      ),
                    ),
                  ]
                : [
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('Edit profile'),
                      subtitle: const Text(
                        'Profile, interests, colours, email, password and phone',
                      ),
                      onTap: () =>
                          _push(context, EditProfileScreen(store: store)),
                    ),
                  ],
          ),
          if (user != null)
            _Section(
              title: 'Friends & privacy',
              children: [
                ListTile(
                  leading: const Icon(Icons.group_outlined),
                  title: const Text('Friends'),
                  subtitle: const Text('Labels, requests and nicknames'),
                  trailing: _RequestBadge(),
                  onTap: () => _push(context, FriendsScreen(store: store)),
                ),
                ListTile(
                  leading: const Icon(Icons.block_outlined),
                  title: const Text('Blocked users'),
                  subtitle: const Text('Manage who you have blocked'),
                  onTap: () => _push(context, const BlockedUsersScreen()),
                ),
              ],
            ),
          _AppearanceSection(store: store),
          _Section(
            title: 'Library',
            children: [
              ListTile(
                leading: const Icon(Icons.bookmark_border),
                title: const Text('Bookmarks'),
                subtitle: const Text('Search what you have bookmarked'),
                onTap: () => _push(
                  context,
                  _page('Bookmarks', SavedScreen(store: store)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.sticky_note_2_outlined),
                title: const Text('My notes'),
                subtitle: const Text('Terms you have written notes on'),
                onTap: () => _push(context, NotesScreen(store: store)),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Clear saved data'),
                subtitle:
                    const Text('Removes bookmarks and notes from this device'),
                onTap: () => _confirmClear(context),
              ),
            ],
          ),
          _Section(
            title: 'Your data',
            children: [
              // Signed-in people delete their own account here; the email
              // request is only for those who cannot sign in.
              if (currentUserOrNull() != null)
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined),
                  iconColor: Theme.of(context).colorScheme.error,
                  textColor: Theme.of(context).colorScheme.error,
                  title: const Text('Delete account'),
                  subtitle: const Text(
                      'Permanently removes your account and its data'),
                  onTap: () =>
                      _push(context, DeleteAccountScreen(store: store)),
                )
              else
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined),
                  title: const Text('Request data deletion'),
                  subtitle: const Text(
                      'Ask us to delete your account and data'),
                  onTap: () => _push(
                    context,
                    const DataRequestScreen(type: DataRequestType.deletion),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Request data recovery'),
                subtitle:
                    const Text('Ask us to help restore your account or data'),
                onTap: () => _push(
                  context,
                  const DataRequestScreen(type: DataRequestType.recovery),
                ),
              ),
            ],
          ),
          _Section(
            title: 'About',
            children: [
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Open source'),
                subtitle:
                    const Text('How the app is built and how we handle data'),
                onTap: () => _push(context, const OpenSourceScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: const Text('Safety & consent basics'),
                onTap: () => _push(
                  context,
                  _page('Safety & consent', ConsentScreen(store: store)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.favorite_outline),
                title: const Text('Support Kinktionary'),
                onTap: () => _push(context, const DonationsScreen()),
              ),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('For adults only'),
                subtitle: Text(
                  'Kinktionary is educational and is not medical, legal or '
                  'mental-health advice.',
                ),
              ),
            ],
          ),
          if (user != null)
            _Section(
              title: 'Session',
              children: [
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  final DataStore store;
  const _AppearanceSection({required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppAppearance.listenable,
      builder: (context, _) {
        final gradient = AppAppearance.gradient.value;
        return _Section(
          title: 'Appearance',
          children: [
            ValueListenableBuilder<double>(
              valueListenable: wallpaperIntensity,
              builder: (context, intensity, _) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.wallpaper_outlined),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Background icons',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(intensity == 0
                            ? 'Off'
                            : '${(intensity * 100).round()}%'),
                      ],
                    ),
                    Slider(
                      value: intensity,
                      divisions: 10,
                      label: intensity == 0
                          ? 'Off'
                          : '${(intensity * 100).round()}%',
                      onChanged: (value) => wallpaperIntensity.value = value,
                      onChangeEnd: store.setWallpaperIntensity,
                    ),
                  ],
                ),
              ),
            ),
            ColorTile(
              title: 'Accent colour',
              subtitle: AppAppearance.accent.value == null
                  ? 'Buttons, highlights and icons'
                  : null,
              color: AppAppearance.accent.value,
              fallback: AppPalette.orchid,
              onChanged: store.setAccent,
              onReset: () => store.setAccent(null),
            ),
            ColorTile(
              title: 'Heading colour',
              subtitle: AppAppearance.secondary.value == null
                  ? 'Titles and secondary highlights'
                  : null,
              color: AppAppearance.secondary.value,
              fallback: AppPalette.rose,
              onChanged: store.setSecondaryAccent,
              onReset: () => store.setSecondaryAccent(null),
            ),
            ColorTile(
              title: 'Background colour',
              subtitle: gradient == null ? 'Default' : null,
              color: gradient?.start,
              fallback: AppPalette.background,
              onChanged: (c) => store.setBackgroundGradient(
                gradient == null || gradient.isSolid
                    ? BackgroundGradient(start: c, end: c)
                    : gradient.copyWith(start: c),
              ),
              onReset: () => store.setBackgroundGradient(null),
            ),
            ColorTile(
              title: 'Background icons colour',
              subtitle: AppAppearance.icons.value == null ? 'Default' : null,
              color: AppAppearance.icons.value,
              fallback: Colors.white,
              onChanged: store.setIconColor,
              onReset: () => store.setIconColor(null),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.gradient),
              title: const Text('Gradient background'),
              subtitle: const Text('Blend into a second colour'),
              value: gradient != null && !gradient.isSolid,
              onChanged: (on) {
                final base = gradient?.start ?? AppPalette.background;
                final hsl = HSLColor.fromColor(base);
                store.setBackgroundGradient(
                  BackgroundGradient(
                    start: base,
                    end: on
                        ? hsl
                            .withHue((hsl.hue + 60) % 360)
                            .withLightness((hsl.lightness + 0.12).clamp(0, 1))
                            .toColor()
                        : base,
                    direction:
                        gradient?.direction ?? GradientDirection.vertical,
                  ),
                );
              },
            ),
            if (gradient != null && !gradient.isSolid) ...[
              ColorTile(
                title: 'Gradient end colour',
                color: gradient.end,
                fallback: gradient.end,
                onChanged: (c) =>
                    store.setBackgroundGradient(gradient.copyWith(end: c)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: SegmentedButton<GradientDirection>(
                  showSelectedIcon: false,
                  segments: [
                    for (final d in GradientDirection.values)
                      ButtonSegment(value: d, label: Text(d.label)),
                  ],
                  selected: {gradient.direction},
                  onSelectionChanged: (s) => store.setBackgroundGradient(
                      gradient.copyWith(direction: s.first)),
                ),
              ),
            ],
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('Reset appearance'),
              onTap: store.resetAppearance,
            ),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 1,
              ),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _RequestBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StreamBuilder<List<FriendRequest>>(
        stream: FirebaseSocialService().incomingRequests(),
        builder: (context, snapshot) {
          final count = snapshot.data?.length ?? 0;
          if (count == 0) return const Icon(Icons.chevron_right);
          return Badge(
            label: Text('$count'),
            child: const Icon(Icons.chevron_right),
          );
        },
      );
}
