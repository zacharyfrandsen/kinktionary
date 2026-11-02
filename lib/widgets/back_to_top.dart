import 'package:flutter/material.dart';

/// Scroll position for a long list, plus the shortcut back to the top.
///
/// The glossary, the feed, saved terms and paths all need the same thing: a
/// button that appears only once the list has actually moved and glides to the
/// top at one speed. Keeping it here means those four can't drift apart.
class BackToTopController extends ChangeNotifier {
  BackToTopController() {
    scroll.addListener(_onScroll);
  }

  /// For the list that owns this controller.
  final ScrollController scroll = ScrollController();

  bool _scrolled = false;

  /// Re-reads the live offset rather than trusting the last notification, so a
  /// list rebuilt at the top (an emptied filter, say) cannot leave a stale
  /// button floating over it.
  bool get visible =>
      _scrolled && scroll.hasClients && scroll.offset > 0;

  void _onScroll() {
    final scrolled = scroll.hasClients && scroll.offset > 0;
    if (scrolled == _scrolled) return;
    _scrolled = scrolled;
    notifyListeners();
  }

  void jumpToTop() {
    if (!scroll.hasClients) return;
    scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }
}

/// The "back to top" button itself, in a [Positioned] slot.
///
/// It renders nothing until [controller] says the list has moved, so a screen
/// can place it unconditionally.
class BackToTopButton extends StatelessWidget {
  const BackToTopButton({
    super.key,
    required this.controller,
    required this.heroTag,
  });

  final BackToTopController controller;

  /// Unique per screen: Flutter rejects two heroes with the same tag.
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => controller.visible
          ? FloatingActionButton.small(
              heroTag: heroTag,
              tooltip: 'Back to top',
              onPressed: controller.jumpToTop,
              child: const Icon(Icons.arrow_upward, size: 20),
            )
          : const SizedBox.shrink(),
    );
  }
}
