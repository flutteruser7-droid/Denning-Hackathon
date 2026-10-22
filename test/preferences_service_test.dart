import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rive_animation/core/services/preferences_service.dart';

void main() {
  group('PreferencesService Tests', () {
    late PreferencesService preferencesService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      preferencesService = PreferencesService();
    });

    test('Onboarding completion status defaults to false and persists when set', () async {
      expect(await preferencesService.isOnboardingCompleted(), isFalse);

      await preferencesService.setOnboardingCompleted(true);
      expect(await preferencesService.isOnboardingCompleted(), isTrue);

      await preferencesService.setOnboardingCompleted(false);
      expect(await preferencesService.isOnboardingCompleted(), isFalse);
    });

    test('Remember Me preference defaults to false and persists when set', () async {
      expect(await preferencesService.isRememberMeEnabled(), isFalse);

      await preferencesService.setRememberMeEnabled(true);
      expect(await preferencesService.isRememberMeEnabled(), isTrue);

      await preferencesService.setRememberMeEnabled(false);
      expect(await preferencesService.isRememberMeEnabled(), isFalse);
    });

    test('clearAuthPreferences resets Remember Me without resetting onboarding', () async {
      await preferencesService.setOnboardingCompleted(true);
      await preferencesService.setRememberMeEnabled(true);

      expect(await preferencesService.isOnboardingCompleted(), isTrue);
      expect(await preferencesService.isRememberMeEnabled(), isTrue);

      await preferencesService.clearAuthPreferences();

      // Onboarding must remain true, remember me must be false
      expect(await preferencesService.isOnboardingCompleted(), isTrue);
      expect(await preferencesService.isRememberMeEnabled(), isFalse);
    });

    test('resetAll clears all stored preferences', () async {
      await preferencesService.setOnboardingCompleted(true);
      await preferencesService.setRememberMeEnabled(true);

      await preferencesService.resetAll();

      expect(await preferencesService.isOnboardingCompleted(), isFalse);
      expect(await preferencesService.isRememberMeEnabled(), isFalse);
    });
  });
}
