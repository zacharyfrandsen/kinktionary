import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';

enum FriendStatus {
  signedOut,
  self,
  none,
  outgoing,
  incoming,
  friends,
  declined
}

class FirebaseSocialService {
  FirebaseSocialService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<UserProfile> loadProfile(
    String userId, {
    required UserProfile fallback,
  }) async {
    final snapshot = await _firestore.collection('users').doc(userId).get();
    if (!snapshot.exists) return fallback;
    return UserProfile.fromMap(snapshot.data() ?? const {});
  }

  Future<FriendStatus> friendStatus(String profileId) async {
    final viewerId = currentUserId;
    if (viewerId == null) return FriendStatus.signedOut;
    if (viewerId == profileId) return FriendStatus.self;

    final outgoingRef = _request(profileId, viewerId);
    final incomingRef = _request(viewerId, profileId);
    final snapshots = await Future.wait([outgoingRef.get(), incomingRef.get()]);
    final outgoing = snapshots[0].data()?['status'] as String?;
    final incoming = snapshots[1].data()?['status'] as String?;

    if (outgoing == 'accepted' || incoming == 'accepted') {
      return FriendStatus.friends;
    }
    if (incoming == 'pending') return FriendStatus.incoming;
    if (outgoing == 'pending') return FriendStatus.outgoing;
    if (outgoing == 'rejected') return FriendStatus.declined;
    return FriendStatus.none;
  }

  Future<void> sendFriendRequest(String profileId) async {
    final viewer = _auth.currentUser;
    if (viewer == null) throw StateError('Sign in to add friends.');
    if (viewer.uid == profileId) return;

    final request = _request(profileId, viewer.uid);
    final existing = await request.get();
    if (existing.exists) {
      if (existing.data()?['status'] != 'rejected') {
        return;
      }
      await request.delete();
    }
    await request.set({
      'senderId': viewer.uid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> respondToFriendRequest(
    String senderId, {
    required bool accept,
  }) async {
    final viewerId = currentUserId;
    if (viewerId == null) {
      throw StateError('Sign in to manage friend requests.');
    }
    await _request(viewerId, senderId).update({
      'status': accept ? 'accepted' : 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelFriendRequest(String profileId) async {
    final viewerId = currentUserId;
    if (viewerId == null) {
      throw StateError('Sign in to manage friend requests.');
    }
    await _request(profileId, viewerId).delete();
  }

  DocumentReference<Map<String, dynamic>> _request(
    String profileId,
    String senderId,
  ) =>
      _firestore
          .collection('users')
          .doc(profileId)
          .collection('friendRequests')
          .doc(senderId);
}
