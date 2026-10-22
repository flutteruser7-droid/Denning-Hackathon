import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/emailjs_service.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../models/user_model.dart';

abstract class AuthRepository {
  Future<UserModel> signIn({required String email, required String password});
  Future<String> sendSignupOtp({required String email, required String name});
  Future<UserModel> completeSignUpWithOtp({
    required String name,
    required String email,
    required String password,
  });
  Future<void> sendPasswordResetEmail({required String email});
  Future<void> signOut();
  Future<UserModel?> getCurrentUserProfile();
  UserModel? getCurrentUser();

  // Backward compatibility alias
  Future<UserModel> signUp({
    required String email,
    required String password,
    String name = 'User',
  });
  Future<String> sendPasswordResetOtp({required String email});
  bool verifyOtp({required String enteredOtp, required String expectedOtp});
  Future<void> resetPassword({required String email, required String newPassword});
}

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuthService _firebaseAuthService;
  final FirestoreService _firestoreService;
  final EmailJsService _emailJsService;

  FirebaseAuthRepository({
    FirebaseAuthService? firebaseAuthService,
    FirestoreService? firestoreService,
    EmailJsService? emailJsService,
  })  : _firebaseAuthService = firebaseAuthService ?? FirebaseAuthService(),
        _firestoreService = firestoreService ?? FirestoreService(),
        _emailJsService = emailJsService ?? EmailJsService();

  @override
  UserModel? getCurrentUser() {
    final user = _firebaseAuthService.currentUser;
    if (user == null) return null;
    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      name: user.displayName ?? '',
    );
  }

  @override
  Future<UserModel?> getCurrentUserProfile() async {
    final user = _firebaseAuthService.currentUser;
    if (user == null) return null;

    try {
      final profile = await _firestoreService.getUserProfile(user.uid);
      if (profile != null) return profile;
    } catch (_) {}

    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      name: user.displayName ?? '',
    );
  }

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuthService.signIn(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception("Failed to retrieve user after sign in.");
      }

      // Retrieve or ensure profile in Firestore
      UserModel? profile;
      try {
        profile = await _firestoreService.getUserProfile(user.uid);
        if (profile == null) {
          final defaultName = user.displayName ?? email.split('@').first;
          await _firestoreService.createUserProfile(
            uid: user.uid,
            name: defaultName,
            email: user.email ?? email,
          );
          profile = UserModel(
            uid: user.uid,
            email: user.email ?? email,
            name: defaultName,
          );
        }
      } catch (_) {
        // Fallback to auth details if firestore offline
        profile = UserModel(
          uid: user.uid,
          email: user.email ?? email,
          name: user.displayName ?? email.split('@').first,
        );
      }

      return profile;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      if (e is String) throw Exception(e);
      rethrow;
    }
  }

  @override
  Future<String> sendSignupOtp({
    required String email,
    required String name,
  }) async {
    // Generate secure 6-digit random code
    final random = Random.secure();
    final otp = (100000 + random.nextInt(900000)).toString();

    // Send real OTP via EmailJS
    await _emailJsService.sendOtpEmail(
      toEmail: email,
      otp: otp,
      toName: name,
    );

    return otp;
  }

  @override
  Future<UserModel> completeSignUpWithOtp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      // 1. Create Firebase Auth account
      final credential = await _firebaseAuthService.signUp(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception("Failed to create user account.");
      }

      // 2. Update display name in Firebase Auth
      await _firebaseAuthService.updateDisplayName(name);

      // 3. Write user profile to Cloud Firestore
      await _firestoreService.createUserProfile(
        uid: user.uid,
        name: name,
        email: email,
      );

      return UserModel(
        uid: user.uid,
        email: email,
        name: name,
        createdAt: DateTime.now(),
      );
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _firebaseAuthService.sendPasswordResetEmail(email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        // Don't expose whether the user exists for security
        return;
      }
      throw _mapFirebaseAuthException(e);
    }
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuthService.signOut();
  }

  // --- Backward compatibility methods ---
  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    String name = 'User',
  }) {
    return completeSignUpWithOtp(name: name, email: email, password: password);
  }

  @override
  Future<String> sendPasswordResetOtp({required String email}) {
    return sendSignupOtp(email: email, name: 'User');
  }

  @override
  bool verifyOtp({required String enteredOtp, required String expectedOtp}) {
    return enteredOtp.trim() == expectedOtp.trim();
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    await sendPasswordResetEmail(email: email);
  }

  String _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return "No account found with this email.";
      case 'wrong-password':
        return "Incorrect password. Please try again.";
      case 'invalid-credential':
        return "Invalid email or password.";
      case 'invalid-email':
        return "The email address is badly formatted.";
      case 'user-disabled':
        return "This account has been disabled.";
      case 'email-already-in-use':
        return "This email is already registered. Please sign in.";
      case 'operation-not-allowed':
        return "Email/Password sign in is not enabled in Firebase Console.";
      case 'weak-password':
        return "The password is too weak.";
      case 'too-many-requests':
        return "Too many attempts. Please try again later.";
      case 'network-request-failed':
        return "Network error. Please check your internet connection.";
      default:
        return e.message ?? "Authentication failed. (${e.code})";
    }
  }
}
