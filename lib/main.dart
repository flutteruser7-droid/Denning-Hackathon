import 'package:flutter/material.dart';
import 'package:rive_animation/features/onboarding/views/onboarding_view.dart';

import 'package:rive_animation/core/services/firebase_auth_service.dart';
import 'package:rive_animation/core/services/preferences_service.dart';
import 'package:rive_animation/core/utils/env_config.dart';
import 'package:rive_animation/features/auth/views/sign_in_view.dart';
import 'package:rive_animation/features/entry_point/views/entry_point_view.dart';

Future<Widget> determineInitialScreen({
  PreferencesService? preferencesService,
  FirebaseAuthService? authService,
}) async {
  final prefs = preferencesService ?? PreferencesService();
  final auth = authService ?? FirebaseAuthService();

  // 1. Check whether onboarding has been completed
  final bool hasCompletedOnboarding = await prefs.isOnboardingCompleted();
  if (!hasCompletedOnboarding) {
    return const OnboardingView();
  }

  // 2. Check Remember Me preference
  final bool isRemembered = await prefs.isRememberMeEnabled();

  // 3. Check Firebase current user safely
  try {
    final user = auth.currentUser;

    if (isRemembered && user != null) {
      try {
        await user.reload();
        return const EntryPointView();
      } catch (_) {
        // If token is invalid or expired, clear and route to sign in
        await prefs.clearAuthPreferences();
        await auth.signOut();
        return const SignInView();
      }
    }

    // If user was signed in but Remember Me was unchecked, require sign-in on fresh launch
    if (!isRemembered && user != null) {
      await auth.signOut();
    }
  } catch (e) {
    debugPrint("Startup auth session check note: $e");
    await prefs.clearAuthPreferences();
  }

  return const SignInView();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.init();

  Object? initError;
  try {
    await FirebaseAuthService.initializeFirebase();
  } catch (error, stackTrace) {
    debugPrint("Firebase initialization failed: $error\n$stackTrace");
    initError = error;
  }

  if (initError != null) {
    runApp(FirebaseErrorApp(errorMessage: initError.toString()));
    return;
  }

  final initialScreen = await determineInitialScreen();
  runApp(MyApp(initialScreen: initialScreen));
}

class FirebaseErrorApp extends StatefulWidget {
  final String errorMessage;

  const FirebaseErrorApp({super.key, required this.errorMessage});

  @override
  State<FirebaseErrorApp> createState() => _FirebaseErrorAppState();
}

class _FirebaseErrorAppState extends State<FirebaseErrorApp> {
  bool _isRetrying = false;
  String? _currentError;

  @override
  void initState() {
    super.initState();
    _currentError = widget.errorMessage;
  }

  Future<void> _retryInitialization() async {
    setState(() {
      _isRetrying = true;
    });

    try {
      await FirebaseAuthService.initializeFirebase();
      if (mounted) {
        final initialScreen = await determineInitialScreen();
        runApp(MyApp(initialScreen: initialScreen));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentError = e.toString();
          _isRetrying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFEEF1F8),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 30,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEAEA),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_off_rounded,
                        color: Color(0xFFD32F2F),
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Firebase Setup Required",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: "Poppins",
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF17203A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Firebase could not establish a connection. If you are developing locally, please run the app on an Android device or emulator (e.g. flutter run -d 33081JEHN10548) where Firebase plugins are supported.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDEE3F2)),
                      ),
                      child: Text(
                        _currentError ?? "Unknown error",
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: "monospace",
                          color: Color(0xFFC62828),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF77D8E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isRetrying ? null : _retryInitialization,
                        child: _isRetrying
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "Retry Connection",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;

  const MyApp({super.key, this.initialScreen = const OnboardingView()});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'The Flutter Way',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFEEF1F8),
        primarySwatch: Colors.blue,
        fontFamily: "Intel",
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(foregroundColor: Colors.white),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          errorStyle: TextStyle(height: 0),
          border: defaultInputBorder,
          enabledBorder: defaultInputBorder,
          focusedBorder: defaultInputBorder,
          errorBorder: defaultInputBorder,
        ),
      ),
      home: initialScreen,
    );
  }
}

const defaultInputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(16)),
  borderSide: BorderSide(color: Color(0xFFDEE3F2), width: 1),
);
