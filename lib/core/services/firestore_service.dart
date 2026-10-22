import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/auth/models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore? _customFirestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      firestore.collection('users');

  /// Creates or updates user profile in Cloud Firestore at `users/{uid}`
  /// strictly using authenticated UID. Never writes passwords or OTP codes.
  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String email,
  }) async {
    final docRef = _usersCollection.doc(uid);
    final snapshot = await docRef.get();

    final data = <String, dynamic>{
      'uid': uid,
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snapshot.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
      await docRef.set(data);
    } else {
      await docRef.update(data);
    }
  }

  /// Retrieves user profile from `users/{uid}`
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final snapshot = await _usersCollection.doc(uid).get();
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return UserModel.fromFirestore(snapshot.data()!, uid);
    } catch (e) {
      throw Exception("Failed to load user profile from Firestore: $e");
    }
  }

  /// Updates user profile details
  Future<void> updateUserProfile({
    required String uid,
    String? name,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) updates['name'] = name.trim();

    await _usersCollection.doc(uid).update(updates);
  }
}
