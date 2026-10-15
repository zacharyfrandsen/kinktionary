import 'dart:convert';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

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
    communitySyncError = null;

    if (userId == null) {
      _publishCombinedCommunityPosts();
      return;
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

  void _publishCombinedCommunityPosts() {
    final cloudIds = _cloudPosts.keys.toSet();
    final syncedPosts = _cloudPosts.entries.map((entry) {
      return entry.value.copyWith(
        replies: _cloudReplies[entry.key] ?? const [],
      );
    });
    final localOnlyPosts = posts.where((post) => !cloudIds.contains(post.id));
    posts = [...syncedPosts, ...localOnlyPosts]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    unawaited(_cacheCommunityPosts());
    notifyListeners();
  }

  Future<void> loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    ageConfirmed = _prefs!.getBool('ageConfirmed') ?? false;
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

  List<Term> search(String query, {String? category}) {
    final q = query.trim().toLowerCase();
    return terms.where((t) {
      if (category != null && t.category != category) return false;
      if (q.isEmpty) return true;
      return t.name.toLowerCase().contains(q) ||
          t.short.toLowerCase().contains(q) ||
          (t.details ?? '').toLowerCase().contains(q);
    }).toList();
  }

  // ---- age gate ----
  Future<void> confirmAge() async {
    ageConfirmed = true;
    await _prefs?.setBool('ageConfirmed', true);
    notifyListeners();
  }

  // ---- bookmarks ----
  bool isBookmarked(String id) => _bookmarks.contains(id);

  List<Term> get bookmarkedTerms =>
      terms.where((t) => _bookmarks.contains(t.id)).toList();

  Future<void> toggleBookmark(String id) async {
    if (!_bookmarks.remove(id)) _bookmarks.add(id);
    await _prefs?.setStringList('bookmarks', _bookmarks.toList());
    notifyListeners();
  }

  // ---- notes ----
  String noteFor(String id) => _notes[id] ?? '';

  Future<void> saveNote(String id, String text) async {
    if (text.trim().isEmpty) {
      _notes.remove(id);
    } else {
      _notes[id] = text;
    }
    await _prefs?.setString('notes', jsonEncode(_notes));
    notifyListeners();
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

  int get communityPostCount => posts.length;

  int get communityLikesReceived =>
      posts.fold(0, (total, post) => total + post.likeCount);

  int get communityReplyCount =>
      posts.fold(0, (total, post) => total + post.replies.length);

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
