import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';

class FirebaseProfileService {
  FirebaseProfileService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> createAccount(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.sendEmailVerification();
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();

  Future<UserProfile> loadProfile(User user) async {
    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    if (!snapshot.exists) {
      final authName = user.displayName?.trim();
      final profile = UserProfile(
        displayName: authName == null || authName.isEmpty
            ? 'Community member'
            : authName,
        photoUrl: user.photoURL,
      );
      await saveProfile(user, profile);
      return profile;
    }
    return UserProfile.fromMap(snapshot.data() ?? const {});
  }

  Future<void> saveProfile(User user, UserProfile profile) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final newHandle = profile.handle.trim().toLowerCase();
    final newHandleRef = newHandle.isEmpty
        ? null
        : _firestore.collection('handles').doc(newHandle);

    await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final oldHandle = userSnapshot.data()?['handle'] as String? ?? '';
      final oldHandleRef = oldHandle.isEmpty || oldHandle == newHandle
          ? null
          : _firestore.collection('handles').doc(oldHandle);
      final newHandleSnapshot =
          newHandleRef == null ? null : await transaction.get(newHandleRef);
      final oldHandleSnapshot =
          oldHandleRef == null ? null : await transaction.get(oldHandleRef);

      if (newHandleSnapshot?.exists == true &&
          newHandleSnapshot?.data()?['uid'] != user.uid) {
        throw const HandleUnavailableException();
      }

      if (oldHandleRef != null &&
          oldHandleSnapshot?.data()?['uid'] == user.uid) {
        transaction.delete(oldHandleRef);
      }
      if (newHandleRef != null &&
          (oldHandle != newHandle || newHandleSnapshot?.exists != true)) {
        transaction.set(newHandleRef, {'uid': user.uid});
      }

      final data = profile.toMap()
        ..['uid'] = user.uid
        ..['updatedAt'] = FieldValue.serverTimestamp();
      if (!userSnapshot.exists) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      transaction.set(userRef, data, SetOptions(merge: true));
    });

    await user.updateDisplayName(profile.displayName);
    await user.updatePhotoURL(profile.photoUrl);
  }

  Future<String> uploadProfilePhoto(User user, XFile image) async {
    final bytes = await image.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      throw const ProfilePhotoTooLargeException();
    }

    final contentType = image.mimeType ?? 'image/jpeg';
    if (!contentType.startsWith('image/')) {
      throw const InvalidProfilePhotoException();
    }

    final reference = _storage.ref().child('users/${user.uid}/profile/avatar');
    await reference.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return reference.getDownloadURL();
  }
}

class HandleUnavailableException implements Exception {
  const HandleUnavailableException();
}

class ProfilePhotoTooLargeException implements Exception {
  const ProfilePhotoTooLargeException();
}

class InvalidProfilePhotoException implements Exception {
  const InvalidProfilePhotoException();
}
