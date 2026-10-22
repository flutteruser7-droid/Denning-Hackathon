import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../utils/env_config.dart';

class FirebaseAuthService {
  final FirebaseAuth? _customAuth;

  FirebaseAuthService({FirebaseAuth? auth}) : _customAuth = auth;

  FirebaseAuth get auth => _customAuth ?? FirebaseAuth.instance;

  User? get currentUser {
    try {
      if (_customAuth == null && Firebase.apps.isEmpty) return null;
      return auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Stream<User?> get authStateChanges {
    try {
      if (_customAuth == null && Firebase.apps.isEmpty) {
        return const Stream.empty();
      }
      return auth.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  static Future<void> initializeFirebase() async {
    if (Firebase.apps.isNotEmpty) return;

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await Firebase.initializeApp();
      } catch (nativeError) {
        debugPrint(
          "Firebase default initialization failed on Android: $nativeError. Attempting explicit options fallback.",
        );
        // Fallback with verified google-services.json configuration options
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: EnvConfig.firebaseApiKey,
            appId: EnvConfig.firebaseAppId,
            messagingSenderId: EnvConfig.firebaseMessagingSenderId,
            projectId: EnvConfig.firebaseProjectId,
            storageBucket: EnvConfig.firebaseStorageBucket,
          ),
        );
      }
    } else {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: EnvConfig.firebaseApiKey,
          appId: EnvConfig.firebaseAppId,
          messagingSenderId: EnvConfig.firebaseMessagingSenderId,
          projectId: EnvConfig.firebaseProjectId,
          storageBucket: EnvConfig.firebaseStorageBucket,
        ),
      );
    }
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    return await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> updateDisplayName(String displayName) async {
    final user = auth.currentUser;
    if (user != null) {
      await user.updateDisplayName(displayName.trim());
      await user.reload();
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    await auth.signOut();
  }
}
