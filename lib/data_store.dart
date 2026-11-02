import 'dart:convert';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'appearance.dart';
import 'models.dart';

/// Loads bundled content and keeps the user's private state (age gate,
/// bookmarks, notes, path progress, appearance) on this device. Private state
/// is never uploaded: only the community feed, profile and friend lists use
/// Firestore.
class DataStore extends ChangeNotifier {
  List<Term> _terms = const [];
  List<LearningPath> paths = [];
  List<ConsentTopic> consent = [];

  final Set<String> _bookmarks = {};
  final Map<String, String> _notes = {};

  /// Users whose one-off public-friend backfill already finished on this device.
  final Set<String> _publicFriendBackfills = {};
  UserProfile profile = const UserProfile();
  bool ageConfirmed = false;
  bool loaded = false;
  String? communitySyncError;

  /// Lookup indexes over [_terms], rebuilt whenever the list is replaced.
  final Map<String, Term> _termsById = {};
  final Map<String, String> _searchText = {};
  List<String> _categories = const [];

  List<Term> get terms => _terms;

  set terms(List<Term> value) {
    _terms = value;
    _termsById
      ..clear()
      ..addEntries(value.map((term) => MapEntry(term.id, term)));
    _searchText
      ..clear()
      ..addEntries(value.map(
        (term) => MapEntry(term.id, _searchHaystack(term)),
      ));
    _categories = value.map((term) => term.category).toSet().toList()..sort();
  }

  SharedPreferences? _prefs;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _cloudPostsSubscription;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _cloudReplySubscriptions = {};
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
      _cloudLikeSubscriptions = {};
  final Map<String, CommunityPost> _cloudPosts = {};
  final Map<String, List<CommunityReply>> _cloudReplies = {};

  /// Posts changed on this device that the cloud listener hasn't confirmed
  /// yet. They win over the cloud copy until a snapshot carries the change;
  /// without this, the next merge would undo an add or an edit.
  final Map<String, CommunityPost> _pendingPosts = {};

  /// Posts deleted here. The tombstone hides a stale cloud copy (or a cached
  /// one) until the delete propagates, then it is dropped.
  final Set<String> _deletedPostIds = {};

  String? _activeCloudUserId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _blockedSubscription;

  /// People the signed-in user has blocked; their content is hidden locally.
  final Set<String> blockedUserIds = {};

  /// Every post the store holds, blocked or not. This is what gets cached, so
  /// blocking only hides content and unblocking restores it.
  List<CommunityPost> _allPosts = [];
  List<CommunityPost> _visiblePosts = const [];

  /// Ids that came from a cloud snapshot (or from a cache written by one), so
  /// one that stops appearing can be retired instead of lingering in the feed.
  final Set<String> _seenInCloud = {};

  /// Posts the user may see, newest first.
  List<CommunityPost> get posts => _visiblePosts;

  /// Fires only when [posts] changes. Screens that render the feed listen to
  /// this instead of the whole store, so bookmarking a term or moving through
  /// a path doesn't rebuild every visible post card.
  final ValueNotifier<int> postsRevision = ValueNotifier<int>(0);

  set posts(List<CommunityPost> value) {
    _allPosts = List<CommunityPost>.of(value);
    _refreshVisiblePosts();
  }

  void _refreshVisiblePosts() {
    final blocked = blockedUserIds;
    final visible = blocked.isEmpty
        ? _allPosts
        : [
            for (final post in _allPosts)
              if (!blocked.contains(post.ownerId))
                post.copyWith(
                  replies: post.replies
                      .where((reply) => !blocked.contains(reply.authorId))
                      .toList(),
                ),
          ];
    _visiblePosts = List<CommunityPost>.of(visible)
      ..sort((a, b) {
        final byDate = b.createdAt.compareTo(a.createdAt);
        // Two posts can share a timestamp; the id keeps the order stable so
        // cards don't swap places between rebuilds.
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });
    postsRevision.value++;
  }

  /// How far through [load] the store is, 0 to 1. The splash draws it around
  /// the mark, so the wait has a shape instead of an unknown length.
  final ValueNotifier<double> loadProgress = ValueNotifier<double>(0);

  Future<void> load() async {
    loadProgress.value = 0.1;
    await loadPreferences();
    loadProgress.value = 0.25;

    final termsJson =
        jsonDecode(await rootBundle.loadString('assets/data/terms.json'))
            as List<dynamic>;
    loadProgress.value = 0.5;
    final pathsJson =
        jsonDecode(await rootBundle.loadString('assets/data/paths.json'))
            as List<dynamic>;
    loadProgress.value = 0.7;
    final consentJson =
        jsonDecode(await rootBundle.loadString('assets/data/consent.json'))
            as List<dynamic>;
    loadProgress.value = 0.85;

    terms = termsJson
        .map((e) => Term.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    paths = pathsJson
        .map((e) => LearningPath.fromJson(e as Map<String, dynamic>))
        .toList();
    consent = consentJson
        .map((e) => ConsentTopic.fromJson(e as Map<String, dynamic>))
        .toList();

    loadProgress.value = 1;
    loaded = true;
    notifyListeners();
    _startCommunitySync();
  }

  @override
  void dispose() {
    loadProgress.dispose();
    postsRevision.dispose();
    _publishTimer?.cancel();
    _notesTimer?.cancel();
    if (_cacheTimer != null) _writeCachedCommunityPosts();
    unawaited(_blockedSubscription?.cancel());
    unawaited(_authSubscription?.cancel());
    unawaited(_cloudPostsSubscription?.cancel());
    for (final subscription in _cloudReplySubscriptions.values) {
      unawaited(subscription.cancel());
    }
    for (final subscription in _cloudLikeSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  User? get _firebaseUser {
    try {
      return FirebaseAuth.instance.currentUser;
    } on Object {
      return null;
    }
  }

  void _startCommunitySync() {
    try {
      _authSubscription ??= FirebaseAuth.instance.authStateChanges().listen(
        watchCloudCommunity,
        onError: (Object _) {
          communitySyncError = 'Cloud community is unavailable.';
          notifyListeners();
        },
      );
    } on Object {
      communitySyncError = null;
    }
  }

  @visibleForTesting
  void watchCloudCommunity(User? user) {
    final userId = user?.uid;
    _activeCloudUserId = userId;
    unawaited(_cloudPostsSubscription?.cancel());
    _cloudPostsSubscription = null;
    for (final subscription in _cloudReplySubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _cloudReplySubscriptions.clear();
    for (final subscription in _cloudLikeSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _cloudLikeSubscriptions.clear();
    _cloudPosts.clear();
    _cloudReplies.clear();
    _pendingPosts.clear();
    _deletedPostIds.clear();
    unawaited(_blockedSubscription?.cancel());
    _blockedSubscription = null;
    blockedUserIds.clear();
    communitySyncError = null;

    if (userId == null) {
      _forgetCachedFeed();
      return;
    }
    // Earlier builds copied private state into the account. Remove that copy
    // so notes and progress live only on the device, as the app promises.
    unawaited(_removeLegacySettings(userId));

    try {
      _blockedSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('blocked')
          .snapshots()
          .listen(
        (snapshot) {
          if (_activeCloudUserId != userId) return;
          blockedUserIds
            ..clear()
            ..addAll(snapshot.docs.map((document) => document.id));
          _publishCombinedCommunityPosts();
        },
        onError: (Object _) {},
      );
    } on Object {
      blockedUserIds.clear();
    }

    try {
      _cloudPostsSubscription = FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .listen(
        (snapshot) => _acceptCloudPosts(snapshot, userId),
        onError: (Object _) {
          if (_activeCloudUserId != userId) return;
          communitySyncError = 'Cloud community is unavailable.';
          notifyListeners();
        },
      );
    } on Object {
      communitySyncError = 'Cloud community is unavailable.';
      notifyListeners();
    }
  }

  void _acceptCloudPosts(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String userId,
  ) {
    if (_activeCloudUserId != userId) return;
    final postIds = snapshot.docs.map((document) => document.id).toSet();
    final previousCloudPosts = Map<String, CommunityPost>.from(_cloudPosts);
    // A post the cloud has since dropped -- deleted, or aged out of the query
    // window -- would otherwise be kept by the merge and sit at the bottom of
    // the feed for good. Anything written here but not yet echoed by a snapshot
    // is still pending, so it stays.
    _allPosts.removeWhere(
      (post) =>
          !postIds.contains(post.id) &&
          !_pendingPosts.containsKey(post.id) &&
          _seenInCloud.contains(post.id),
    );
    _seenInCloud
      ..clear()
      ..addAll(postIds);
    for (final postId in _cloudReplySubscriptions.keys.toList()) {
      if (postIds.contains(postId)) continue;
      unawaited(_cloudReplySubscriptions.remove(postId)?.cancel());
      _cloudReplies.remove(postId);
    }
    for (final postId in _cloudLikeSubscriptions.keys.toList()) {
      if (postIds.contains(postId)) continue;
      unawaited(_cloudLikeSubscriptions.remove(postId)?.cancel());
    }

    _cloudPosts
      ..clear()
      ..addEntries(snapshot.docs.map((document) {
        final post = _communityPostFromFirestore(document);
        return MapEntry(
          document.id,
          post.copyWith(
            likedByMe: previousCloudPosts[document.id]?.likedByMe ?? false,
          ),
        );
      }));

    // Snapshots that have caught up with our own writes no longer need an
    // override, and a tombstone only has to outlive the document it deletes.
    for (final postId in _pendingPosts.keys.toList()) {
      if (_cloudPosts[postId]?.text == _pendingPosts[postId]?.text) {
        _pendingPosts.remove(postId);
      }
    }
    for (final postId in _deletedPostIds.toList()) {
      if (!postIds.contains(postId)) _deletedPostIds.remove(postId);
    }

    for (final document in snapshot.docs) {
      if (_cloudReplySubscriptions.containsKey(document.id)) continue;
      _cloudReplySubscriptions[document.id] = document.reference
          .collection('replies')
          .orderBy('createdAt')
          .limit(100)
          .snapshots()
          .listen(
        (replySnapshot) {
          if (_activeCloudUserId != userId) return;
          _cloudReplies[document.id] =
              replySnapshot.docs.map(_communityReplyFromFirestore).toList();
          _publishCombinedCommunityPosts();
        },
        onError: (Object _) {
          if (_activeCloudUserId != userId) return;
          communitySyncError = 'Some replies could not be loaded.';
          notifyListeners();
        },
      );
      if (!_cloudLikeSubscriptions.containsKey(document.id)) {
        _cloudLikeSubscriptions[document.id] = document.reference
            .collection('likes')
            .doc(userId)
            .snapshots()
            .listen(
          (likeSnapshot) {
            if (_activeCloudUserId != userId) return;
            final post = _cloudPosts[document.id];
            if (post == null) return;
            _cloudPosts[document.id] =
                post.copyWith(likedByMe: likeSnapshot.exists);
            _publishCombinedCommunityPosts();
          },
          onError: (Object _) {
            if (_activeCloudUserId != userId) return;
            communitySyncError = 'Some likes could not be loaded.';
            notifyListeners();
          },
        );
      }
    }
    _publishCombinedCommunityPosts();
  }

  /// Drops the feed and its cache when nobody is signed in.
  ///
  /// The posts were loaded for an account, not for the device: leaving them in
  /// memory or on disk would show one person's feed to the next account that
  /// signs in here.
  void _forgetCachedFeed() {
    _allPosts = [];
    _refreshVisiblePosts();
    notifyListeners();
    unawaited(_prefs?.remove('communityPosts'));
  }

  CommunityPost _communityPostFromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = Map<String, dynamic>.from(document.data());
    data['id'] = document.id;
    data['createdAt'] = _timestampString(data['createdAt']);
    data['replies'] = const <dynamic>[];
    return CommunityPost.fromMap(data);
  }

  CommunityReply _communityReplyFromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = Map<String, dynamic>.from(document.data());
    data['id'] = document.id;
    data['createdAt'] = _timestampString(data['createdAt']);
    return CommunityReply.fromMap(data);
  }

  String _timestampString(Object? value) => value is Timestamp
      ? value.toDate().toIso8601String()
      : value is String
          ? value
          : DateTime.now().toIso8601String();

  Timer? _publishTimer;
  Timer? _cacheTimer;

  /// Reply and like listeners fire once per post; batch them into one update.
  void _publishCombinedCommunityPosts() {
    _publishTimer?.cancel();
    _publishTimer = Timer(const Duration(milliseconds: 120), _publishNow);
  }

  void _publishNow({bool flushCache = false}) {
    _allPosts = mergeCommunityPosts(
      cloudPosts: _cloudPosts,
      pendingPosts: _pendingPosts,
      deletedPostIds: _deletedPostIds,
      cloudReplies: _cloudReplies,
      allPosts: _allPosts,
    );
    _refreshVisiblePosts();
    if (flushCache) {
      _writeCachedCommunityPosts();
    } else {
      // A burst of snapshots republishes several times a second, and encoding
      // fifty posts with their replies costs more than the merge itself, so
      // the first publish of a burst schedules one write rather than every
      // publish scheduling its own.
      _cacheTimer ??= Timer(
        const Duration(milliseconds: 900),
        _writeCachedCommunityPosts,
      );
    }
    notifyListeners();
  }

  void _writeCachedCommunityPosts() {
    _cacheTimer?.cancel();
    _cacheTimer = null;
    unawaited(_cacheCommunityPosts());
  }

  /// Runs the cloud/local merge at once instead of waiting for the debounce
  /// that cloud listeners get, and writes the cache immediately, so tests can
  /// observe the result synchronously.
  @visibleForTesting
  void mergeCloudCommunityPosts() => _publishNow(flushCache: true);

  /// Users whose legacy `private/settings` document was already deleted on
  /// this device. Nothing writes it any more; this removes what earlier
  /// builds uploaded so the device is the only copy.
  final Set<String> _settingsPurged = {};

  Future<void> _removeLegacySettings(String uid) async {
    if (!_settingsPurged.add(uid)) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('settings')
          .delete();
      await _prefs?.setStringList('settingsPurged', _settingsPurged.toList());
    } on Object {
      // Offline; try again on the next sign-in.
      _settingsPurged.remove(uid);
    }
  }

  Future<void> loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    ageConfirmed = _prefs!.getBool('ageConfirmed') ?? false;
    wallpaperIntensity.value = _prefs!.getDouble('wallpaperIntensity') ?? 0.7;
    final accentValue = _prefs!.getInt('accent');
    AppAppearance.accent.value =
        accentValue == null ? null : Color(accentValue);
    final secondaryValue = _prefs!.getInt('secondaryAccent');
    AppAppearance.secondary.value =
        secondaryValue == null ? null : Color(secondaryValue);
    final gradientStart = _prefs!.getInt('bgStart');
    final gradientEnd = _prefs!.getInt('bgEnd');
    if (gradientStart != null && gradientEnd != null) {
      final directionIndex = _prefs!.getInt('bgDirection') ?? 0;
      AppAppearance.gradient.value = BackgroundGradient(
        start: Color(gradientStart),
        end: Color(gradientEnd),
        direction: GradientDirection.values[
            directionIndex.clamp(0, GradientDirection.values.length - 1)],
      );
    }
    final iconValue = _prefs!.getInt('iconColor');
    AppAppearance.icons.value = iconValue == null ? null : Color(iconValue);
    final progress = _readJsonPref('pathProgress');
    if (progress is Map) {
      progress.forEach((key, value) {
        if (key is String && value is num) _pathProgress[key] = value.toInt();
      });
    } else if (progress != null) {
      _dropCorruptPref('pathProgress');
    }
    _completedPaths.addAll(_prefs!.getStringList('completedPaths') ?? const []);
    final profileRaw = _readJsonPref('profile');
    if (profileRaw is Map<String, dynamic>) {
      try {
        profile = UserProfile.fromMap(profileRaw);
      } on Object {
        _dropCorruptPref('profile');
      }
    } else if (profileRaw != null) {
      _dropCorruptPref('profile');
    }
    final postsRaw = _readJsonPref('communityPosts');
    if (postsRaw is List) {
      try {
        posts = postsRaw
            .map((item) => CommunityPost.fromMap(item as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        // The cache was written from snapshots, so the next one can retire
        // anything in it that the cloud no longer returns.
        _seenInCloud.addAll(posts.map((post) => post.id));
      } on Object {
        posts = const [];
        _dropCorruptPref('communityPosts');
      }
    } else if (postsRaw != null) {
      _dropCorruptPref('communityPosts');
    }
    _bookmarks.addAll(_prefs!.getStringList('bookmarks') ?? const []);
    final notes = _readJsonPref('notes');
    if (notes is Map) {
      notes.forEach((key, value) {
        if (key is String && value is String) _notes[key] = value;
      });
    } else if (notes != null) {
      _dropCorruptPref('notes');
    }
    _publicFriendBackfills
        .addAll(_prefs!.getStringList('publicFriendBackfills') ?? const []);
    _settingsPurged.addAll(_prefs!.getStringList('settingsPurged') ?? const []);
  }

  /// Decodes a cached JSON value, dropping it instead of throwing if it is
  /// half-written or was edited by hand. A bad cache must never leave the app
  /// stuck on the loading screen.
  Object? _readJsonPref(String key) {
    final raw = _prefs!.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      _dropCorruptPref(key);
      return null;
    }
  }

  void _dropCorruptPref(String key) => unawaited(_prefs?.remove(key));

  List<String> get categories => _categories;

  Term? termById(String id) => _termsById[id];

  /// The terms of [path] in order; ids that match no term are skipped.
  List<Term> termsForPath(LearningPath path) =>
      path.termIds.map((id) => _termsById[id]).whereType<Term>().toList();

  /// Terms linked from [term], skipping ids that match no term.
  List<Term> relatedTerms(Term term) =>
      term.related.map((id) => _termsById[id]).whereType<Term>().toList();

  /// Lowercase text searched for a term; the newline keeps a match from
  /// spanning two fields.
  static String _searchHaystack(Term term) =>
      '${term.name}\n${term.short}\n${term.details ?? ''}'.toLowerCase();

  List<Term> search(String query, {String? category, bool savedOnly = false}) {
    final q = query.trim().toLowerCase();
    final results = <Term>[];
    for (final term in terms) {
      if (category != null && term.category != category) continue;
      if (savedOnly && !_bookmarks.contains(term.id)) continue;
      if (q.isEmpty ||
          (_searchText[term.id] ?? '').contains(q) ||
          (savedOnly && noteFor(term.id).toLowerCase().contains(q))) {
        results.add(term);
      }
    }
    return results;
  }

  // ---- age gate ----
  Future<void> confirmAge() async {
    ageConfirmed = true;
    await _prefs?.setBool('ageConfirmed', true);
    notifyListeners();
  }

  // ---- appearance ----
  Future<void> setWallpaperIntensity(double value) async {
    wallpaperIntensity.value = value.clamp(0, 1).toDouble();
    await _prefs?.setDouble('wallpaperIntensity', wallpaperIntensity.value);
  }

  Future<void> _saveColor(String key, Color? color) async {
    if (color == null) {
      await _prefs?.remove(key);
    } else {
      await _prefs?.setInt(key, color.toARGB32());
    }
  }

  // ---- local persistence of appearance and private state ----
  Future<void> _persistAppearance() async {
    final gradient = AppAppearance.gradient.value;
    await _saveColor('accent', AppAppearance.accent.value);
    await _saveColor('secondaryAccent', AppAppearance.secondary.value);
    await _saveColor('iconColor', AppAppearance.icons.value);
    await _saveColor('bgStart', gradient?.start);
    await _saveColor('bgEnd', gradient?.end);
    if (gradient == null) {
      await _prefs?.remove('bgDirection');
    } else {
      await _prefs?.setInt('bgDirection', gradient.direction.index);
    }
    await _prefs?.setDouble('wallpaperIntensity', wallpaperIntensity.value);
  }

  Future<void> _persistProgress() async {
    await _prefs?.setString('pathProgress', jsonEncode(_pathProgress));
    await _prefs?.setStringList('completedPaths', _completedPaths.toList());
  }

  Future<void> _persistBookmarks() async {
    await _prefs?.setStringList('bookmarks', _bookmarks.toList());
  }

  Future<void> _persistNotes() async {
    await _prefs?.setString('notes', jsonEncode(_notes));
  }

  Future<void> setAccent(Color? color) async {
    AppAppearance.accent.value = color;
    await _saveColor('accent', color);
  }

  Future<void> setSecondaryAccent(Color? color) async {
    AppAppearance.secondary.value = color;
    await _saveColor('secondaryAccent', color);
  }

  Future<void> setIconColor(Color? color) async {
    AppAppearance.icons.value = color;
    await _saveColor('iconColor', color);
  }

  Future<void> setBackgroundGradient(BackgroundGradient? gradient) async {
    AppAppearance.gradient.value = gradient;
    await _persistAppearance();
  }

  Future<void> resetAppearance() async {
    await setAccent(null);
    await setSecondaryAccent(null);
    await setBackgroundGradient(null);
    await setIconColor(null);
    await setWallpaperIntensity(0.7);
  }

  // ---- path progress ----
  final Map<String, int> _pathProgress = {};
  final Set<String> _completedPaths = {};

  /// Index of the step to resume at (0 when not started).
  int pathStep(String pathId) => _pathProgress[pathId] ?? 0;

  bool pathStarted(String pathId) => _pathProgress.containsKey(pathId);

  bool pathCompleted(String pathId) => _completedPaths.contains(pathId);

  Future<void> setPathStep(String pathId, int step) async {
    _pathProgress[pathId] = step;
    await _persistProgress();
    notifyListeners();
  }

  Future<void> completePath(String pathId) async {
    _completedPaths.add(pathId);
    await _persistProgress();
    notifyListeners();
  }

  Future<void> restartPath(String pathId) async {
    _pathProgress.remove(pathId);
    _completedPaths.remove(pathId);
    await _persistProgress();
    notifyListeners();
  }

  // ---- bookmarks ----
  bool isBookmarked(String id) => _bookmarks.contains(id);

  List<Term> get bookmarkedTerms =>
      terms.where((t) => _bookmarks.contains(t.id)).toList();

  Future<void> toggleBookmark(String id) async {
    if (!_bookmarks.remove(id)) _bookmarks.add(id);
    await _persistBookmarks();
    notifyListeners();
  }

  // ---- notes ----
  String noteFor(String id) => _notes[id] ?? '';

  List<Term> get termsWithNotes =>
      terms.where((t) => (_notes[t.id] ?? '').trim().isNotEmpty).toList();

  Timer? _notesTimer;

  /// Keeps typing responsive: the write is debounced and listeners only hear
  /// about a note appearing or disappearing.
  Future<void> saveNote(String id, String text) async {
    final hadNote = _notes.containsKey(id);
    if (text.trim().isEmpty) {
      _notes.remove(id);
    } else {
      _notes[id] = text;
    }
    _notesTimer?.cancel();
    _notesTimer = Timer(const Duration(milliseconds: 400), () async {
      await _persistNotes();
    });
    if (hadNote != _notes.containsKey(id)) notifyListeners();
  }

  Future<void> saveProfile(UserProfile nextProfile) async {
    profile = nextProfile;
    await _prefs?.setString('profile', jsonEncode(profile.toMap()));
    notifyListeners();
  }

  /// The legacy public-friend backfill costs two Firestore reads per friend, so
  /// it runs once per user on each device instead of on every profile load.
  bool needsPublicFriendBackfill(String userId) =>
      !_publicFriendBackfills.contains(userId);

  /// Records a successful backfill; a failed one stays pending so it retries.
  Future<void> markPublicFriendBackfillDone(String userId) async {
    if (!_publicFriendBackfills.add(userId)) return;
    await _prefs?.setStringList(
      'publicFriendBackfills',
      _publicFriendBackfills.toList(),
    );
  }

  Future<void> addCommunityPost(CommunityPost post) async {
    final user = _firebaseUser;
    if (user != null) {
      final data = post.toMap()
        ..remove('replies')
        ..remove('likedByMe')
        ..['likeCount'] = 0
        ..['createdAt'] = FieldValue.serverTimestamp();
      try {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(post.id)
            .set(data);
      } on Object {
        _pendingPosts.remove(post.id);
        rethrow;
      }
    }
    _pendingPosts[post.id] = post;
    _allPosts = [post, ..._allPosts.where((item) => item.id != post.id)];
    await _persistCommunityPosts();
  }

  Future<bool> updateCommunityPost({
    required String postId,
    required String ownerId,
    required String text,
  }) async {
    final index = _allPosts.indexWhere((post) => post.id == postId);
    if (index < 0 || _allPosts[index].ownerId != ownerId) return false;
    final user = _firebaseUser;
    if (user != null) {
      // Ownership is already checked above and the rules check it again, so the
      // document is updated directly instead of reading it back first.
      try {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .update({
          'text': text,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException catch (error) {
        // A post that never reached the cloud, has just gone, or no longer
        // belongs to this account keeps its local copy; anything else is a real
        // failure the caller should see.
        if (error.code == 'permission-denied') return false;
        if (error.code != 'not-found') rethrow;
      }
    }
    final updated = _allPosts[index].copyWith(text: text);
    _pendingPosts[updated.id] = updated;
    _allPosts[index] = updated;
    await _persistCommunityPosts();
    return true;
  }

  Future<bool> deleteCommunityPost({
    required String postId,
    required String ownerId,
  }) async {
    final index = _allPosts.indexWhere((post) => post.id == postId);
    if (index < 0 || _allPosts[index].ownerId != ownerId) return false;
    final user = _firebaseUser;
    if (user != null) {
      // The rules only let the owner through, so there is no need to read the
      // post first; delete is a no-op if it has already gone.
      try {
        final reference =
            FirebaseFirestore.instance.collection('posts').doc(postId);
        while (true) {
          final replies =
              await reference.collection('replies').limit(450).get();
          if (replies.docs.isEmpty) break;
          final batch = FirebaseFirestore.instance.batch();
          for (final reply in replies.docs) {
            batch.delete(reply.reference);
          }
          await batch.commit();
        }
        await reference.delete();
      } on Object {
        return false;
      }
    }
    _forgetPost(postId);
    await _persistCommunityPosts();
    return true;
  }

  /// Drops a post everywhere the store keeps it, including the cloud copy and
  /// its listeners, so nothing can publish it again before the delete lands.
  void _forgetPost(String postId) {
    _deletedPostIds.add(postId);
    _pendingPosts.remove(postId);
    _cloudPosts.remove(postId);
    _cloudReplies.remove(postId);
    unawaited(_cloudReplySubscriptions.remove(postId)?.cancel());
    unawaited(_cloudLikeSubscriptions.remove(postId)?.cancel());
    _allPosts.removeWhere((post) => post.id == postId);
  }

  Future<void> toggleCommunityPostLike(String postId) async {
    final index = _allPosts.indexWhere((post) => post.id == postId);
    if (index < 0) return;
    final post = _allPosts[index];
    final user = _firebaseUser;
    if (user != null && _cloudPosts.containsKey(postId)) {
      final postReference =
          FirebaseFirestore.instance.collection('posts').doc(postId);
      final likeReference = postReference.collection('likes').doc(user.uid);
      final result = await FirebaseFirestore.instance
          .runTransaction<({bool liked, int count})?>(
        (transaction) async {
          final postSnapshot = await transaction.get(postReference);
          if (!postSnapshot.exists) return null;
          final likeSnapshot = await transaction.get(likeReference);
          final currentCount = postSnapshot.data()?['likeCount'] as int? ?? 0;
          if (likeSnapshot.exists) {
            transaction.delete(likeReference);
            transaction.update(postReference, {'likeCount': currentCount - 1});
            return (liked: false, count: currentCount - 1);
          }
          transaction.set(likeReference, {
            'userId': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(postReference, {'likeCount': currentCount + 1});
          return (liked: true, count: currentCount + 1);
        },
      );
      if (result == null) return;
      _allPosts[index] = post.copyWith(
        likedByMe: result.liked,
        likeCount: result.count,
      );
      // Keep the cloud copy in step too, or the next merge reverts the count.
      final cloudPost = _cloudPosts[postId];
      if (cloudPost != null) {
        _cloudPosts[postId] = cloudPost.copyWith(
          likedByMe: result.liked,
          likeCount: result.count,
        );
      }
      await _persistCommunityPosts();
      return;
    }
    _allPosts[index] = post.copyWith(
      likedByMe: !post.likedByMe,
      likeCount: post.likeCount + (post.likedByMe ? -1 : 1),
    );
    await _persistCommunityPosts();
  }

  Future<bool> addCommunityPostReply(
    String postId,
    CommunityReply reply,
  ) async {
    if (!_allPosts.any((post) => post.id == postId)) return false;
    final savedReply = reply.id.isEmpty
        ? reply.copyWith(
            id: '${reply.authorId}_${DateTime.now().microsecondsSinceEpoch}',
          )
        : reply;
    final user = _firebaseUser;
    if (user != null) {
      if (savedReply.authorId != user.uid) return false;
      final reference =
          FirebaseFirestore.instance.collection('posts').doc(postId);
      final snapshot = await reference.get();
      if (snapshot.exists) {
        final replyData = savedReply.toMap()
          ..remove('id')
          ..['createdAt'] = FieldValue.serverTimestamp();
        await reference.collection('replies').doc(savedReply.id).set(replyData);
      }
    }
    final updatedIndex = _allPosts.indexWhere((post) => post.id == postId);
    if (updatedIndex < 0) return false;
    final post = _allPosts[updatedIndex];
    if (!post.replies.any((existing) => existing.id == savedReply.id)) {
      _allPosts[updatedIndex] =
          post.copyWith(replies: [...post.replies, savedReply]);
      // A merged cloud post takes its replies from this cache, so the new one
      // has to be held there until the reply snapshot includes it.
      final cloudReplies = _cloudReplies[postId];
      if (cloudReplies != null &&
          !cloudReplies.any((existing) => existing.id == savedReply.id)) {
        _cloudReplies[postId] = [...cloudReplies, savedReply];
      }
    }
    await _persistCommunityPosts();
    return true;
  }

  Future<void> _persistCommunityPosts() async {
    _refreshVisiblePosts();
    await _cacheCommunityPosts();
    notifyListeners();
  }

  /// Caches every post, blocked or not, so hiding someone stays reversible.
  Future<void> _cacheCommunityPosts() async {
    await _prefs?.setString(
      'communityPosts',
      jsonEncode(_allPosts.map((post) => post.toMap()).toList()),
    );
  }

  /// Wipe everything the user has saved on this device.
  Future<void> clearPersonalData() async {
    _bookmarks.clear();
    _notes.clear();
    await _prefs?.remove('bookmarks');
    await _prefs?.remove('notes');
    notifyListeners();
  }

  /// Stops queued writes from landing while an account is being deleted.
  void cancelPendingWrites() {
    _notesTimer?.cancel();
    _notesTimer = null;
    _cacheTimer?.cancel();
    _cacheTimer = null;
    _publishTimer?.cancel();
    _publishTimer = null;
  }

  /// Removes everything tied to the signed-in account from this device.
  ///
  /// The age gate and appearance stay: they belong to the device, not to the
  /// account that was just deleted.
  Future<void> clearAccountData() async {
    cancelPendingWrites();
    _bookmarks.clear();
    _notes.clear();
    _pathProgress.clear();
    _completedPaths.clear();
    _publicFriendBackfills.clear();
    _settingsPurged.clear();
    blockedUserIds.clear();
    _cloudPosts.clear();
    _cloudReplies.clear();
    _pendingPosts.clear();
    _deletedPostIds.clear();
    _allPosts = [];
    _visiblePosts = const [];
    profile = const UserProfile();
    for (final key in const [
      'bookmarks',
      'notes',
      'profile',
      'communityPosts',
      'pathProgress',
      'completedPaths',
      'publicFriendBackfills',
      'settingsPurged',
    ]) {
      await _prefs?.remove(key);
    }
    postsRevision.value++;
    notifyListeners();
  }
}

/// Builds the post list the feed shows from three sources:
///
///   * the cloud snapshot, minus posts deleted here,
///   * overridden by anything this device changed and the cloud hasn't
///     confirmed yet, so an add or edit isn't undone by a late snapshot,
///   * plus posts that only exist locally (cached while offline).
///
/// Split out from the store so the ordering rules can be tested without a
/// Firestore connection.
@visibleForTesting
List<CommunityPost> mergeCommunityPosts({
  required Map<String, CommunityPost> cloudPosts,
  required Map<String, CommunityPost> pendingPosts,
  required Set<String> deletedPostIds,
  required Map<String, List<CommunityReply>> cloudReplies,
  required List<CommunityPost> allPosts,
}) {
  final merged = <String, CommunityPost>{};
  for (final entry in cloudPosts.entries) {
    if (deletedPostIds.contains(entry.key)) continue;
    final post = pendingPosts[entry.key] ?? entry.value;
    merged[entry.key] = post.copyWith(
      replies: cloudReplies[entry.key] ?? post.replies,
    );
  }
  for (final post in allPosts) {
    if (deletedPostIds.contains(post.id) || merged.containsKey(post.id)) {
      continue;
    }
    merged[post.id] = post;
  }
  for (final post in pendingPosts.values) {
    if (deletedPostIds.contains(post.id)) continue;
    merged[post.id] = post.copyWith(
      replies:
          cloudReplies[post.id] ?? merged[post.id]?.replies ?? post.replies,
    );
  }
  return merged.values.toList();
}
