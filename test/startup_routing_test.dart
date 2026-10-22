import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rive_animation/core/services/preferences_service.dart';
import 'package:rive_animation/features/auth/views/sign_in_view.dart';
import 'package:rive_animation/features/onboarding/views/onboarding_view.dart';
import 'package:rive_animation/main.dart';

void main() {
  group('Startup Routing Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('First launch shows OnboardingView', () async {
      final prefs = PreferencesService();
      expect(await prefs.isOnboardingCompleted(), isFalse);

      final screen = await determineInitialScreen(preferencesService: prefs);
      expect(screen.runtimeType, OnboardingView);
    });

    test('Second launch (onboarding completed, not remembered) shows SignInView directly', () async {
      final prefs = PreferencesService();
      await prefs.setOnboardingCompleted(true);
      await prefs.setRememberMeEnabled(false);

      final screen = await determineInitialScreen(preferencesService: prefs);
      expect(screen.runtimeType, SignInView);
    });
  });
}
