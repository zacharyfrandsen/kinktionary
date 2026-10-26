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
/// bookmarks, notes) on-device only.
class DataStore extends ChangeNotifier {
  List<Term> terms = [];
  List<LearningPath> paths = [];
  List<ConsentTopic> consent = [];
  List<CommunityPost> posts = [];

  final Set<String> _bookmarks = {};
  final Map<String, String> _notes = {};
  UserProfile profile = const UserProfile();
  bool ageConfirmed = false;
  bool loaded = false;
  String? communitySyncError;

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
  String? _activeCloudUserId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _blockedSubscription;

  /// People the signed-in user has blocked; their content is hidden locally.
  final Set<String> blockedUserIds = {};

  Future<void> load() async {
    await loadPreferences();

    final termsJson =
        jsonDecode(await rootBundle.loadString('assets/data/terms.json'))
            as List<dynamic>;
    final pathsJson =
        jsonDecode(await rootBundle.loadString('assets/data/paths.json'))
            as List<dynamic>;
    final consentJson =
        jsonDecode(await rootBundle.loadString('assets/data/consent.json'))
            as List<dynamic>;

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

    loaded = true;
    notifyListeners();
    _startCommunitySync();
  }

  @override
  void dispose() {
    _settingsTimer?.cancel();
    _publishTimer?.cancel();
    _notesTimer?.cancel();
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
        _watchCloudCommunity,
        onError: (Object _) {
          communitySyncError = 'Cloud community is unavailable.';
          notifyListeners();
        },
      );
    } on Object {
      communitySyncError = null;
    }
  }

  void _watchCloudCommunity(User? user) {
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
    unawaited(_blockedSubscription?.cancel());
    _blockedSubscription = null;
    blockedUserIds.clear();
    communitySyncError = null;

    if (userId == null) {
      _settingsTimer?.cancel();
      _publishCombinedCommunityPosts();
      return;
    }
    unawaited(_pullSettings(userId));

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

  /// Reply and like listeners fire once per post; batch them into one update.
  void _publishCombinedCommunityPosts() {
    _publishTimer?.cancel();
    _publishTimer = Timer(const Duration(milliseconds: 120), _publishNow);
  }

  void _publishNow() {
    final cloudIds = _cloudPosts.keys.toSet();
    final syncedPosts = _cloudPosts.entries.map((entry) {
      return entry.value.copyWith(
        replies: _cloudReplies[entry.key] ?? const [],
      );
    });
    final localOnlyPosts = posts.where((post) => !cloudIds.contains(post.id));
    posts = [...syncedPosts, ...localOnlyPosts]
        .where((post) => !blockedUserIds.contains(post.ownerId))
        .map((post) => blockedUserIds.isEmpty
            ? post
            : post.copyWith(
                replies: post.replies
                    .where((reply) => !blockedUserIds.contains(reply.authorId))
                    .toList(),
              ))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    unawaited(_cacheCommunityPosts());
    notifyListeners();
  }

  // ---- account settings sync (users/{uid}/private/settings) ----
  Timer? _settingsTimer;
  bool _applyingCloud = false;

  DocumentReference<Map<String, dynamic>> _settingsDoc(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('settings');

  void _queueSettingsSync() {
    if (_applyingCloud || _firebaseUser == null) return;
    _settingsTimer?.cancel();
    _settingsTimer = Timer(const Duration(milliseconds: 1500), () {
      unawaited(_pushSettings());
    });
  }

  Future<void> _pushSettings() async {
    final user = _firebaseUser;
    if (user == null) return;
    final gradient = AppAppearance.gradient.value;
    try {
      await _settingsDoc(user.uid).set({
        'accent': AppAppearance.accent.value?.toARGB32(),
        'secondaryAccent': AppAppearance.secondary.value?.toARGB32(),
        'bgStart': gradient?.start.toARGB32(),
        'bgEnd': gradient?.end.toARGB32(),
        'iconColor': AppAppearance.icons.value?.toARGB32(),
        'bgDirection': gradient?.direction.index ?? 0,
        'wallpaperIntensity': wallpaperIntensity.value,
        'bookmarks': _bookmarks.toList(),
        'notes': _notes,
        'pathProgress': _pathProgress,
        'completedPaths': _completedPaths.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on Object {
      // Offline or rules not deployed; the next change retries.
    }
  }

  /// Cloud values win for appearance and progress; bookmarks and notes merge.
  Future<void> _pullSettings(String uid) async {
    try {
      final snapshot = await _settingsDoc(uid).get();
      if (_activeCloudUserId != uid) return;
      final data = snapshot.data();
      if (data == null) {
        _queueSettingsSync();
        return;
      }
      _applyingCloud = true;
      Color? color(String key) =>
          data[key] is int ? Color(data[key] as int) : null;
      AppAppearance.accent.value = color('accent');
      AppAppearance.secondary.value = color('secondaryAccent');
      AppAppearance.icons.value = color('iconColor');
      final start = color('bgStart');
      final end = color('bgEnd');
      final directionIndex = (data['bgDirection'] as int?) ?? 0;
      AppAppearance.gradient.value = start == null || end == null
          ? null
          : BackgroundGradient(
              start: start,
              end: end,
              direction: GradientDirection.values[
                  directionIndex.clamp(0, GradientDirection.values.length - 1)],
            );
      final intensity = data['wallpaperIntensity'];
      if (intensity is num) {
        wallpaperIntensity.value = intensity.toDouble().clamp(0.0, 1.0);
      }
      _bookmarks.addAll((data['bookmarks'] as List<dynamic>? ?? const [])
          .whereType<String>());
      (data['notes'] as Map<String, dynamic>? ?? const {}).forEach((k, v) {
        if (v is String && v.trim().isNotEmpty) _notes[k] = v;
      });
      (data['pathProgress'] as Map<String, dynamic>? ?? const {})
          .forEach((k, v) {
        if (v is num) _pathProgress[k] = v.toInt();
      });
      _completedPaths.addAll(
          (data['completedPaths'] as List<dynamic>? ?? const [])
              .whereType<String>());

      await _saveColor('accent', AppAppearance.accent.value);
      await _saveColor('secondaryAccent', AppAppearance.secondary.value);
      await _saveColor('iconColor', AppAppearance.icons.value);
      await _saveColor('bgStart', start);
      await _saveColor('bgEnd', end);
      await _prefs?.setInt('bgDirection', directionIndex);
      await _prefs?.setDouble('wallpaperIntensity', wallpaperIntensity.value);
      await _prefs?.setStringList('bookmarks', _bookmarks.toList());
      await _prefs?.setString('notes', jsonEncode(_notes));
      await _prefs?.setString('pathProgress', jsonEncode(_pathProgress));
      await _prefs?.setStringList('completedPaths', _completedPaths.toList());
      _applyingCloud = false;
      notifyListeners();
      _queueSettingsSync();
    } on Object {
      // Offline; local settings stay as they are.
    } finally {
      _applyingCloud = false;
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
    final progressRaw = _prefs!.getString('pathProgress');
    if (progressRaw != null) {
      (jsonDecode(progressRaw) as Map<String, dynamic>).forEach((key, value) {
        _pathProgress[key] = (value as num).toInt();
      });
    }
    _completedPaths.addAll(_prefs!.getStringList('completedPaths') ?? const []);
    final profileRaw = _prefs!.getString('profile');
    if (profileRaw != null) {
      profile =
          UserProfile.fromMap(jsonDecode(profileRaw) as Map<String, dynamic>);
    }
    final postsRaw = _prefs!.getString('communityPosts');
    if (postsRaw != null) {
      posts = (jsonDecode(postsRaw) as List<dynamic>)
          .map((item) => CommunityPost.fromMap(item as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    _bookmarks.addAll(_prefs!.getStringList('bookmarks') ?? const []);
    final notesRaw = _prefs!.getString('notes');
    if (notesRaw != null) {
      _notes.addAll((jsonDecode(notesRaw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as String)));
    }
  }

  List<String> get categories {
    final set = terms.map((t) => t.category).toSet().toList()..sort();
    return set;
  }

  Term? termById(String id) {
    for (final t in terms) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<Term> search(String query, {String? category, bool savedOnly = false}) {
    final q = query.trim().toLowerCase();
    return terms.where((t) {
      if (category != null && t.category != category) return false;
      if (savedOnly && !_bookmarks.contains(t.id)) return false;
      if (q.isEmpty) return true;
      return t.name.toLowerCase().contains(q) ||
          t.short.toLowerCase().contains(q) ||
          (t.details ?? '').toLowerCase().contains(q) ||
          (savedOnly && noteFor(t.id).toLowerCase().contains(q));
    }).toList();
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
    _queueSettingsSync();
  }

  Future<void> _saveColor(String key, Color? color) async {
    if (color == null) {
      await _prefs?.remove(key);
    } else {
      await _prefs?.setInt(key, color.toARGB32());
    }
  }

  Future<void> setAccent(Color? color) async {
    AppAppearance.accent.value = color;
    await _saveColor('accent', color);
    _queueSettingsSync();
  }

  Future<void> setSecondaryAccent(Color? color) async {
    AppAppearance.secondary.value = color;
    await _saveColor('secondaryAccent', color);
    _queueSettingsSync();
  }

  Future<void> setIconColor(Color? color) async {
    AppAppearance.icons.value = color;
    await _saveColor('iconColor', color);
    _queueSettingsSync();
  }

  Future<void> setBackgroundGradient(BackgroundGradient? gradient) async {
    AppAppearance.gradient.value = gradient;
    await _saveColor('bgStart', gradient?.start);
    await _saveColor('bgEnd', gradient?.end);
    if (gradient == null) {
      await _prefs?.remove('bgDirection');
    } else {
      await _prefs?.setInt('bgDirection', gradient.direction.index);
    }
    _queueSettingsSync();
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
    await _prefs?.setString('pathProgress', jsonEncode(_pathProgress));
    _queueSettingsSync();
    notifyListeners();
  }

  Future<void> completePath(String pathId) async {
    _completedPaths.add(pathId);
    await _prefs?.setStringList('completedPaths', _completedPaths.toList());
    _queueSettingsSync();
    notifyListeners();
  }

  Future<void> restartPath(String pathId) async {
    _pathProgress.remove(pathId);
    _completedPaths.remove(pathId);
    await _prefs?.setString('pathProgress', jsonEncode(_pathProgress));
    await _prefs?.setStringList('completedPaths', _completedPaths.toList());
    _queueSettingsSync();
    notifyListeners();
  }

  // ---- bookmarks ----
  bool isBookmarked(String id) => _bookmarks.contains(id);

  List<Term> get bookmarkedTerms =>
      terms.where((t) => _bookmarks.contains(t.id)).toList();

  Future<void> toggleBookmark(String id) async {
    if (!_bookmarks.remove(id)) _bookmarks.add(id);
    await _prefs?.setStringList('bookmarks', _bookmarks.toList());
    _queueSettingsSync();
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
      await _prefs?.setString('notes', jsonEncode(_notes));
      _queueSettingsSync();
    });
    if (hadNote != _notes.containsKey(id)) notifyListeners();
  }

  Future<void> saveProfile(UserProfile nextProfile) async {
    profile = nextProfile;
    await _prefs?.setString('profile', jsonEncode(profile.toMap()));
    notifyListeners();
  }

  Future<void> addCommunityPost(CommunityPost post) async {
    final user = _firebaseUser;
    if (user != null) {
      final data = post.toMap()
        ..remove('replies')
        ..remove('likedByMe')
        ..['likeCount'] = 0
        ..['createdAt'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(post.id)
          .set(data);
    }
    posts = [post, ...posts.where((item) => item.id != post.id)];
    await _persistCommunityPosts();
  }

  Future<bool> updateCommunityPost({
    required String postId,
    required String ownerId,
    required String text,
  }) async {
    final index = posts.indexWhere((post) => post.id == postId);
    if (index < 0 || posts[index].ownerId != ownerId) return false;
    final user = _firebaseUser;
    if (user != null) {
      final reference =
          FirebaseFirestore.instance.collection('posts').doc(postId);
      final snapshot = await reference.get();
      if (snapshot.exists) {
        if (ownerId != user.uid || snapshot.data()?['ownerId'] != user.uid) {
          return false;
        }
        await reference.update({
          'text': text,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    posts[index] = posts[index].copyWith(text: text);
    await _persistCommunityPosts();
    return true;
  }

  Future<bool> deleteCommunityPost({
    required String postId,
    required String ownerId,
  }) async {
    final index = posts.indexWhere((post) => post.id == postId);
    if (index < 0 || posts[index].ownerId != ownerId) return false;
    final user = _firebaseUser;
    if (user != null) {
      final reference =
          FirebaseFirestore.instance.collection('posts').doc(postId);
      final snapshot = await reference.get();
      if (snapshot.exists) {
        if (ownerId != user.uid || snapshot.data()?['ownerId'] != user.uid) {
          return false;
        }
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
      }
    }
    posts.removeAt(index);
    await _persistCommunityPosts();
    return true;
  }

  Future<void> toggleCommunityPostLike(String postId) async {
    final index = posts.indexWhere((post) => post.id == postId);
    if (index < 0) return;
    final post = posts[index];
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
      posts[index] = post.copyWith(
        likedByMe: result.liked,
        likeCount: result.count,
      );
      await _persistCommunityPosts();
      return;
    }
    posts[index] = post.copyWith(
      likedByMe: !post.likedByMe,
      likeCount: post.likeCount + (post.likedByMe ? -1 : 1),
    );
    await _persistCommunityPosts();
  }

  Future<bool> addCommunityPostReply(
    String postId,
    CommunityReply reply,
  ) async {
    if (!posts.any((post) => post.id == postId)) return false;
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
    final updatedIndex = posts.indexWhere((post) => post.id == postId);
    if (updatedIndex < 0) return false;
    final post = posts[updatedIndex];
    if (!post.replies.any((existing) => existing.id == savedReply.id)) {
      posts[updatedIndex] =
          post.copyWith(replies: [...post.replies, savedReply]);
    }
    await _persistCommunityPosts();
    return true;
  }

  Future<void> _persistCommunityPosts() async {
    await _cacheCommunityPosts();
    notifyListeners();
  }

  Future<void> _cacheCommunityPosts() async {
    await _prefs?.setString(
      'communityPosts',
      jsonEncode(posts.map((post) => post.toMap()).toList()),
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
}
