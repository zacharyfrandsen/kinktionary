import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../instant_route.dart';
import '../data_store.dart';
import '../services/auth_state.dart';
import '../widgets/feed_sidebar.dart';
import '../widgets/safety_note_card.dart';
import '../widgets/pattern_background.dart';
import 'community_feed_screen.dart';
import 'firebase_profile_screen.dart';
import 'glossary_screen.dart';
import 'paths_screen.dart';
import 'post_composer_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  final DataStore store;
  const HomeShell({super.key, required this.store});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _profileIndex = 3;

  /// At or above this width the tabs move from the bottom bar to a side rail,
  /// which is how the same app reads on a laptop or a monitor.
  static const double railBreakpoint = 860;

  /// Width of the reading column on wide screens, and the sidebar beside it.
  static const double columnWidth = 620;
  static const double sidebarWidth = 320;

  static const double _railWidth = 78;
  static const double _railExpandedWidth = 208;

  int index = 0;
  bool _railOpen = false;
  final _authStream = authStateOrSignedOut();

  /// The four tab screens, built once.
  ///
  /// This widget rebuilds whenever the rail opens on hover or a tab changes;
  /// constructing the pages again would rebuild every mounted tab with it, so
  /// opening the rail would re-filter the feed and the glossary for nothing.
  late final List<Widget> _pages = [
    StreamBuilder<User?>(
      stream: _authStream,
      initialData: currentUserOrNull(),
      builder: (context, snapshot) => CommunityFeedScreen(
        store: widget.store,
        signedIn: snapshot.data != null,
        onSignIn: _showProfile,
      ),
    ),
    GlossaryScreen(store: widget.store),
    PathsScreen(store: widget.store),
    FirebaseProfileScreen(store: widget.store),
  ];

  /// The column's own navigator. On a wide window a screen opens inside the
  /// reading column so the rail stays where it is; on a phone it takes the
  /// whole screen instead.
  final _columnNav = GlobalKey<NavigatorState>();

  /// Which rail row the open page belongs to, if any. While a page is open the
  /// tab underneath is not what you are looking at, so the rail marks the page
  /// instead of leaving the last tab highlighted.
  String? _openPage;

  /// Counts page opens. A replaced page finishes later than its replacement
  /// starts, so its completion must not clear the marker of the page that took
  /// its place -- only the newest one may.
  int _pageOpen = 0;

  void _pushPage(BuildContext context, Widget page, {String? id}) {
    final navigator = _columnNav.currentState ?? Navigator.of(context);
    final route = instantRoute(page);
    final open = ++_pageOpen;
    setState(() => _openPage = id ?? 'page');
    // One page at a time from the rail or the sidebar: opening something new
    // swaps out whatever was open there, so a single back returns you to the
    // tab you were on instead of replaying every screen you visited. Pages that
    // open pages from inside (settings -> blocked users) still nest, because
    // those do not come through here.
    if (navigator.canPop()) {
      navigator.pushReplacement(route);
    } else {
      navigator.push(route);
    }
    route.popped.whenComplete(() {
      if (mounted && open == _pageOpen) setState(() => _openPage = null);
    });
  }

  /// Tabs opened so far. An [IndexedStack] lays out every child, so building
  /// one for each tab means every notification rebuilds four screens; a tab is
  /// only mounted once it has been visited, and then stays mounted.
  final Set<int> _mounted = {0};

  void _openPostComposer() {
    if (currentUserOrNull() == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Sign in to post to the community.'),
            action: SnackBarAction(
              label: 'Sign in',
              onPressed: _showProfile,
            ),
          ),
        );
      return;
    }
    _pushPage(context, PostComposerScreen(store: widget.store), id: 'post');
  }

  void _openSettings() {
    _pushPage(context, SettingsScreen(store: widget.store), id: 'settings');
  }

  void _showProfile() {
    _openTab(_profileIndex);
  }

  void _select(int next) {
    _openTab(next);
  }

  /// Whether a tab is the thing on screen: a page opened over it is not.
  bool _onTab(int tab) => _openPage == null && index == tab;

  /// Switches tab. A page opened in the column (a path, settings) goes away
  /// first, so the rail always takes you where it says it will.
  void _openTab(int next) {
    _columnNav.currentState?.popUntil((route) => route.isFirst);
    _mounted.add(next);
    setState(() {
      index = next;
      _openPage = null;
      _pageOpen++;  // any page still closing is no longer the newest
    });
  }

  /// One row of the rail: a 40px icon tile and, when the rail is open, the
  /// section name beside it.
  Widget _railEntry({
    required Widget leading,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool expanded = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.onSecondaryContainer;
    final tile = SizedBox(
      width: 40,
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: accent, width: 1.4) : null,
        ),
        child: Center(child: leading),
      ),
    );

    // Closed, the icon has no label, so the tile is centred on the rail's own
    // midpoint and a tooltip names the section. The same inset is used when
    // open, so the icons do not jump sideways as the rail expands.
    final body = expanded
        ? Padding(
            padding: const EdgeInsets.fromLTRB(19, 6, 8, 6),
            child: Row(
              children: [
                tile,
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? accent : scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          )
        : SizedBox(
            width: _railWidth,
            height: 40,
            child: Center(child: tile),
          );

    final row = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: body,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: expanded
          ? row
          : Tooltip(
              message: label,
              waitDuration: const Duration(milliseconds: 400),
              child: row,
            ),
    );
  }

  Widget _railIcon(IconData icon, {required bool selected}) {
    final scheme = Theme.of(context).colorScheme;
    return Icon(
      icon,
      size: 22,
      color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
    );
  }

  Widget _railProfile(bool expanded) {
    final scheme = Theme.of(context).colorScheme;
    final profile = widget.store.profile;
    final name = profile.displayName.trim();
    final url = profile.photoUrl;
    return _railEntry(
      expanded: expanded,
      label: name.isEmpty ? 'Profile' : name,
      selected: _openPage == null && index == _profileIndex,
      onTap: _showProfile,
      leading: CircleAvatar(
        radius: 15,
        backgroundColor: scheme.surfaceContainerHigh,
        foregroundImage:
            (url == null || url.isEmpty) ? null : NetworkImage(url),
        child: name.isEmpty
            ? Icon(
                Icons.person_outline,
                size: 19,
                color: scheme.onSecondaryContainer,
              )
            : Text(
                name.characters.first.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSecondaryContainer,
                ),
              ),
      ),
    );
  }

  /// Navigation down the left edge. Collapsed to icons, it opens on hover to
  /// name every section.
  Widget _rail(BuildContext context, {bool allowOpen = true}) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: allowOpen
          ? (_) {
              if (!_railOpen) setState(() => _railOpen = true);
            }
          : null,
      onExit: allowOpen
          ? (_) {
              if (_railOpen) setState(() => _railOpen = false);
            }
          : null,
      child: AnimatedContainer(
        key: const Key('home-rail'),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        width: _railOpen ? _railExpandedWidth : _railWidth,
        decoration: BoxDecoration(
          color: scheme.surface.withAlpha(0xF2),
          border: Border(right: BorderSide(color: scheme.outlineVariant)),
        ),
        // Labels follow the width that actually exists, so they can't overflow
        // the row on the first frames of the opening animation.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final open = constraints.maxWidth >= 120;
            return Stack(
              children: [
                // The profile stays at the top of the strip, above the
                // sections, which are centred on the screen itself below.
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _railProfile(open),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 64),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _railEntry(
                            expanded: open,
                            label: 'Feed',
                            selected: _onTab(0),
                            onTap: () => _select(0),
                            leading: _railIcon(
                              index == 0 ? Icons.forum : Icons.forum_outlined,
                              selected: _onTab(0),
                            ),
                          ),
                          _railEntry(
                            expanded: open,
                            label: 'Glossary',
                            selected: _onTab(1),
                            onTap: () => _select(1),
                            leading:
                                _railIcon(Icons.search, selected: _onTab(1)),
                          ),
                          _railEntry(
                            expanded: open,
                            label: 'Paths',
                            selected: _onTab(2),
                            onTap: () => _select(2),
                            leading: _railIcon(
                              index == 2 ? Icons.route : Icons.route_outlined,
                              selected: _onTab(2),
                            ),
                          ),
                          _railEntry(
                            expanded: open,
                            label: 'New post',
                            selected: _openPage == 'post',
                            onTap: _openPostComposer,
                            leading: _railIcon(
                              Icons.add_box_outlined,
                              selected: _openPage == 'post',
                            ),
                          ),
                          _railEntry(
                            expanded: open,
                            label: 'Settings',
                            selected: _openPage == 'settings',
                            onTap: _openSettings,
                            leading: _railIcon(Icons.menu,
                                selected: _openPage == 'settings'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= railBreakpoint;

    final body = IndexedStack(
      index: index,
      children: [
        for (var page = 0; page < _pages.length; page++)
          if (_mounted.contains(page)) _pages[page] else const SizedBox.shrink(),
      ],
    );

    final appBar = AppBar(
      title: Text(const ['Community', 'Glossary', 'Paths', 'Profile'][index]),
      actions: [
        if (index == _profileIndex)
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
      ],
    );

    if (wide) {
      return PatternScaffold(
        // The rail, column and sidebar are positioned here by hand; the
        // wallpaper runs across the whole window behind them.
        constrainWidth: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            // Centre the column on the window, the way a desktop feed does,
            // and only let the rail open over empty space.
            final columnLeft = math.max(
              (w - columnWidth) / 2,
              _railWidth + 12,
            );
            final sidebarLeft = columnLeft + columnWidth + 24;
            final showSidebar =
                index == 0 && sidebarLeft + sidebarWidth <= w - 8;
            final canOpenRail = columnLeft >= _railExpandedWidth + 12;
            // The right column holds the sidebar on top and the consent box
            // pinned to the bottom of the window beneath it, so the two never
            // run into each other on a short screen.
            final fitsRightColumn = sidebarLeft + sidebarWidth <= w - 8;

            return Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: _rail(context, allowOpen: canOpenRail),
                ),
                Positioned(
                  left: columnLeft,
                  top: 0,
                  bottom: 0,
                  width: columnWidth,
                  // Everything the column opens -- the composer, a learning
                  // path, settings -- is pushed here rather than over the whole
                  // window, so the rail keeps its place beside it.
                  child: _ShellScope(
                    appBar: appBar,
                    body: body,
                    index: index,
                    child: NavigatorPopHandler<Object?>(
                      onPopWithResult: (_) =>
                          _columnNav.currentState?.maybePop(),
                      child: Navigator(
                        key: _columnNav,
                        onGenerateRoute: (_) => instantRoute(const _ColumnHome()),
                      ),
                    ),
                  ),
                ),
                if (fitsRightColumn)
                  Positioned(
                    left: sidebarLeft,
                    top: 0,
                    bottom: 0,
                    width: sidebarWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: showSidebar
                              ? FeedSidebar(
                                  store: widget.store,
                                  signedIn: currentUserOrNull() != null,
                                  onSignIn: _showProfile,
                                  onProfile: _showProfile,
                                  onOpen: (page) =>
                                      _pushPage(context, page),
                                )
                              : const SizedBox.shrink(),
                        ),
                        // Consent and risk, a small buffer up from the bottom
                        // edge, in the same box as a term's safety note.
                        const Padding(
                          padding: EdgeInsets.only(bottom: 18),
                          child: SafetyNoteCard(
                            margin: EdgeInsets.zero,
                            note: 'Consent, negotiation and risk awareness '
                                'come before any activity. 18+ only.',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    return PatternScaffold(
      appBar: appBar,
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 2 ? index : index + 1,
        onDestinationSelected: (destination) {
          if (destination == 2) {
            _openPostComposer();
            return;
          }
          _select(destination < 2 ? destination : destination - 1);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.forum_outlined), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Glossary'),
          NavigationDestination(
              icon: Icon(Icons.add_circle_outline, size: 32), label: 'Post'),
          NavigationDestination(
              icon: Icon(Icons.route_outlined), label: 'Paths'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

/// The tab content handed to the column's own navigator.
///
/// The navigator outlives any single tab, so its first page cannot capture the
/// shell's widgets directly; it reads them from this scope instead and is told
/// to rebuild when the selected tab changes.
class _ShellScope extends InheritedWidget {
  const _ShellScope({
    required this.appBar,
    required this.body,
    required this.index,
    required super.child,
  });

  final PreferredSizeWidget appBar;
  final Widget body;
  final int index;

  @override
  bool updateShouldNotify(_ShellScope old) => old.index != index;
}

class _ColumnHome extends StatelessWidget {
  const _ColumnHome();

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ShellScope>()!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: scope.appBar,
      body: scope.body,
    );
  }
}
