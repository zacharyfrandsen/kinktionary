// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kinktionary/data_store.dart';
import 'package:kinktionary/main.dart';
import 'package:kinktionary/models.dart';
import 'package:kinktionary/screens/glossary_screen.dart';
import 'package:kinktionary/screens/home_shell.dart';
import 'package:kinktionary/screens/profile_screen.dart';
import 'package:kinktionary/widgets/pattern_background.dart';

void main() {
  testWidgets('Glossary can sort bookmarked definitions first',
      (WidgetTester tester) async {
    final store = DataStore()
      ..terms = [
        const Term(id: 'a', name: 'Alpha', category: 'Test', short: 'Alpha'),
        const Term(id: 'b', name: 'Bravo', category: 'Test', short: 'Bravo'),
        const Term(id: 'z', name: 'Zulu', category: 'Test', short: 'Zulu'),
      ];
    await store.toggleBookmark('b');
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: GlossaryScreen(store: store))),
    );

    List<String> termNames() => tester
        .widgetList<TermTile>(find.byType(TermTile))
        .map((tile) => tile.term.name)
        .toList();

    expect(termNames(), ['Alpha', 'Bravo', 'Zulu']);
    await tester.tap(find.text('Bookmarks first'));
    await tester.pump();
    expect(termNames(), ['Bravo', 'Alpha', 'Zulu']);
  });

  testWidgets('App launches to the age gate', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const KinktionaryApp());
    await tester.pumpAndSettle();

    expect(find.text('Kinktionary'), findsOneWidget);
    expect(find.text("I'm 18 or older — continue"), findsOneWidget);
  });

  testWidgets('Wallpaper follows vertical scrolling',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PatternBackground(
          child: ListView(
            children: [
              for (var i = 0; i < 20; i++) const SizedBox(height: 100)
            ],
          ),
        ),
      ),
    );

    Transform wallpaper() => tester.widget<Transform>(
          find.byKey(const ValueKey('scrolling-wallpaper')),
        );

    expect(wallpaper().transform.getTranslation().y, 0);
    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(wallpaper().transform.getTranslation().y, lessThan(0));
  });

  testWidgets('Profile saves and reloads locally', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = DataStore();
    await store.loadPreferences();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ProfileScreen(store: store))),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'Alex Example');
    await tester.enterText(find.byType(TextFormField).at(1), 'alex_example');
    await tester.enterText(find.byType(TextFormField).at(2), 'they/them');
    await tester.enterText(
        find.byType(TextFormField).at(3), 'Learning together.');
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Save profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final reloadedStore = DataStore();
    await reloadedStore.loadPreferences();
    expect(reloadedStore.profile.displayName, 'Alex Example');
    expect(reloadedStore.profile.handle, 'alex_example');
    expect(reloadedStore.profile.pronouns, 'they/them');
    expect(reloadedStore.profile.bio, 'Learning together.');
  });

  testWidgets('Community feed publishes text posts',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = DataStore();
    await store.loadPreferences();
    await store.saveProfile(
      const UserProfile(displayName: 'Alex Example', handle: 'alex_example'),
    );
    await tester.pumpWidget(MaterialApp(home: HomeShell(store: store)));
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();

    const postText = 'I learned to make space for check-ins afterward.';
    await tester.enterText(
      find.byKey(const ValueKey('community-composer')),
      postText,
    );
    await tester.pump();
    await tester.tap(find.text('Post').last);
    await tester.pumpAndSettle();

    expect(find.text(postText), findsOneWidget);
    expect(find.byTooltip('Post options'), findsOneWidget);

    await tester.tap(find.byTooltip('Post options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit post'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('edit-post-field')),
      'Edited experience.',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Edited experience.'), findsOneWidget);

    await tester.tap(find.byTooltip('Reply to post'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('community-reply-field')),
      'Thanks for sharing this.',
    );
    await tester.tap(find.byTooltip('Send reply'));
    await tester.pumpAndSettle();
    expect(find.text('Alex Example'), findsNWidgets(2));
    expect(find.text('@alex_example'), findsOneWidget);
    expect(find.text('Thanks for sharing this.'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Post options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete post'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Edited experience.'), findsNothing);
  });

  test('Legacy string replies load as attributed community replies', () {
    final post = CommunityPost.fromMap({
      'id': 'legacy-post',
      'ownerId': 'owner',
      'text': 'Post text',
      'createdAt': DateTime(2026).toIso8601String(),
      'replies': ['A reply from an older app version'],
    });

    expect(post.replies.single.text, 'A reply from an older app version');
    expect(post.replies.single.displayName, 'Community member');
  });

  test('Guest likes toggle locally', () async {
    SharedPreferences.setMockInitialValues({});
    final store = DataStore();
    await store.loadPreferences();
    store.posts = [
      CommunityPost(
        id: 'local-post',
        ownerId: 'local-preview-user',
        displayName: 'You',
        handle: '',
        text: 'A local post',
        topic: 'Experience',
        createdAt: DateTime(2026),
      ),
    ];

    await store.toggleCommunityPostLike('local-post');
    expect(store.posts.single.likeCount, 1);
    expect(store.posts.single.likedByMe, isTrue);

    await store.toggleCommunityPostLike('local-post');
    expect(store.posts.single.likeCount, 0);
    expect(store.posts.single.likedByMe, isFalse);
  });

  test('Firestore reply echo is not appended twice', () async {
    SharedPreferences.setMockInitialValues({});
    final store = DataStore();
    await store.loadPreferences();
    final reply = CommunityReply(
      id: 'reply-1',
      authorId: 'user-1',
      displayName: 'Alex Example',
      handle: 'alex_example',
      text: 'Thanks for sharing this.',
      createdAt: DateTime(2026),
    );
    store.posts = [
      CommunityPost(
        id: 'post-1',
        ownerId: 'user-1',
        displayName: 'Alex Example',
        handle: 'alex_example',
        text: 'A post',
        topic: 'Experience',
        createdAt: DateTime(2026),
        replies: [reply],
      ),
    ];

    final added = await store.addCommunityPostReply('post-1', reply);

    expect(added, isTrue);
    expect(store.posts.single.replies, hasLength(1));
  });

  testWidgets('Community feed clear search empties the query',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = DataStore();
    await store.loadPreferences();
    await tester.pumpWidget(MaterialApp(home: HomeShell(store: store)));

    final searchBar = find.byType(SearchBar);
    await tester.enterText(searchBar, 'rope');
    await tester.pumpAndSettle();
    expect(find.text('No matching posts'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    expect(tester.widget<SearchBar>(searchBar).controller!.text, isEmpty);
    expect(find.text('No conversations yet'), findsOneWidget);
  });

  testWidgets('Safety opens from the top action but not Profile',
      (WidgetTester tester) async {
    final store = DataStore()
      ..consent = [
        const ConsentTopic(title: 'Boundaries', body: 'Discuss limits.')
      ];
    await tester.pumpWidget(MaterialApp(home: HomeShell(store: store)));

    expect(find.byTooltip('Safety & consent'), findsOneWidget);
    await tester.tap(find.byTooltip('Safety & consent'));
    await tester.pump();
    expect(find.text('Safety & consent basics'), findsOneWidget);

    await tester.tap(find.byTooltip('Back to screen'));
    await tester.pump();
    await tester.tap(find.text('Profile').last);
    await tester.pump();
    expect(find.byTooltip('Safety & consent'), findsNothing);
  });
}
