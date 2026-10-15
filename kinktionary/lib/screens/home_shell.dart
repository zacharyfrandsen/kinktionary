import 'package:flutter/material.dart';

import '../data_store.dart';
import '../widgets/pattern_background.dart';
import 'consent_screen.dart';
import 'community_feed_screen.dart';
import 'firebase_profile_screen.dart';
import 'glossary_screen.dart';
import 'paths_screen.dart';
import 'post_composer_sheet.dart';

class HomeShell extends StatefulWidget {
  final DataStore store;
  const HomeShell({super.key, required this.store});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  bool showingSafety = false;

  void _openPostComposer() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PostComposerSheet(store: widget.store),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      CommunityFeedScreen(store: widget.store),
      GlossaryScreen(store: widget.store),
      PathsScreen(store: widget.store),
      FirebaseProfileScreen(store: widget.store),
      ConsentScreen(store: widget.store),
    ];
    return PatternScaffold(
      appBar: AppBar(
        title: Text(showingSafety
            ? 'Safety & consent'
            : const ['Community', 'Glossary', 'Paths', 'Profile'][index]),
        actions: index == 3
            ? null
            : [
                IconButton(
                  tooltip: showingSafety ? 'Back to screen' : 'Safety & consent',
                  onPressed: () => setState(() => showingSafety = !showingSafety),
                  icon: Icon(showingSafety
                      ? Icons.close
                      : Icons.verified_user_outlined),
                ),
              ],
      ),
      body: IndexedStack(index: showingSafety ? 4 : index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 2 ? index : index + 1,
        onDestinationSelected: (destination) {
          if (destination == 2) {
            _openPostComposer();
            return;
          }
          setState(() {
            index = destination < 2 ? destination : destination - 1;
            showingSafety = false;
          });
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.forum_outlined), label: 'Feed'),
          NavigationDestination(
              icon: Icon(Icons.search), label: 'Glossary'),
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
