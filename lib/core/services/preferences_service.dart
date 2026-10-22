import 'package:shared_preferences/shared_preferences.dart';

/// Service responsible for managing local persistent settings including:
/// - Onboarding / Welcome screen completion status
/// - "Remember Me" authentication preference
class PreferencesService {
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyRememberMe = 'remember_me';

  final SharedPreferences? _injectedPrefs;

  PreferencesService([this._injectedPrefs]);

  Future<SharedPreferences> get _prefs async =>
      _injectedPrefs ?? await SharedPreferences.getInstance();

  /// Returns true if the user has completed the welcome/onboarding screen.
  Future<bool> isOnboardingCompleted() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyOnboardingCompleted) ?? false;
  }

  /// Sets whether onboarding has been completed.
  Future<void> setOnboardingCompleted(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyOnboardingCompleted, value);
  }

  /// Returns true if the user selected 'Remember me' during login.
  Future<bool> isRememberMeEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyRememberMe) ?? false;
  }

  /// Sets whether 'Remember me' is enabled.
  Future<void> setRememberMeEnabled(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyRememberMe, value);
  }

  /// Clears remember-me preference on logout. Does not reset onboarding.
  Future<void> clearAuthPreferences() async {
    final prefs = await _prefs;
    await prefs.setBool(_keyRememberMe, false);
  }

  /// Resets all preferences (for clean testing or account wipes).
  Future<void> resetAll() async {
    final prefs = await _prefs;
    await prefs.clear();
  }
}
