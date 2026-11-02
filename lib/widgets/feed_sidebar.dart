import 'package:flutter/material.dart';

import '../instant_route.dart';
import '../data_store.dart';
import '../screens/consent_screen.dart';
import '../screens/open_source_screen.dart';
import '../screens/saved_screen.dart';
import '../screens/settings_screen.dart';
import 'pattern_background.dart';

/// The right-hand column of the wide feed, in the same slot as the sidebar on
/// other desktop apps: your account, then shortcuts into the rest of the app.
class FeedSidebar extends StatelessWidget {
  final DataStore store;
  final bool signedIn;
  final VoidCallback? onSignIn;

  /// Opens the profile tab: the name and picture here are the way back to it.
  final VoidCallback? onProfile;

  /// Opens a page. The shell supplies this so the page lands beside the rail
  /// on a wide window instead of covering it.
  final void Function(Widget page)? onOpen;

  const FeedSidebar({
    super.key,
    required this.store,
    this.signedIn = true,
    this.onSignIn,
    this.onProfile,
    this.onOpen,
  });

  void _push(BuildContext context, Widget page) {
    final open = onOpen;
    if (open != null) {
      open(page);
      return;
    }
    Navigator.of(context).push(instantRoute(page));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profile = store.profile;
    final name = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : 'Guest';
    final handle = profile.handle.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: onProfile != null,
                  label: 'Your profile',
                  child: InkWell(
                    onTap: onProfile,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          _Avatar(photoUrl: profile.photoUrl, name: name),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall,
                                ),
                                Text(
                                  signedIn
                                      ? (handle.isEmpty
                                          ? 'Signed in'
                                          : '@$handle')
                                      : 'Not signed in',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (!signedIn && onSignIn != null)
                TextButton(onPressed: onSignIn, child: const Text('Sign in')),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Explore',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.06,
            ),
          ),
          const SizedBox(height: 10),
          _SidebarLink(
            icon: Icons.bookmark_border,
            label: 'Saved terms',
            onTap: () => _push(context, SavedScreen(store: store)),
          ),
          _SidebarLink(
            icon: Icons.verified_user_outlined,
            label: 'Safety & consent',
            onTap: () => _push(
              context,
              PatternScaffold(
                appBar: AppBar(title: const Text('Safety & consent')),
                body: ConsentScreen(store: store),
              ),
            ),
          ),
          _SidebarLink(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () => _push(context, SettingsScreen(store: store)),
          ),
          _SidebarLink(
            icon: Icons.code,
            label: 'About & open source',
            onTap: () => _push(context, const OpenSourceScreen()),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  const _Avatar({required this.photoUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = photoUrl;
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return CircleAvatar(
      radius: 22,
      backgroundColor: scheme.surfaceContainerHigh,
      foregroundImage: url == null || url.isEmpty ? null : NetworkImage(url),
      child: Text(
        initial,
        style: TextStyle(color: scheme.onSecondaryContainer, fontSize: 17),
      ),
    );
  }
}

class _SidebarLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SidebarLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 22, color: scheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w500,
                  fontSize: 14.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
