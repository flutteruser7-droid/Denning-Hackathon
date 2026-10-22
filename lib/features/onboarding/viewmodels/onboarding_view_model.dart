import 'package:flutter/foundation.dart';
import '../../../core/services/preferences_service.dart';

class OnboardingViewModel extends ChangeNotifier {
  final PreferencesService _preferencesService;

  bool _isBtnActive = false;

  OnboardingViewModel({PreferencesService? preferencesService})
      : _preferencesService = preferencesService ?? PreferencesService();

  bool get isBtnActive => _isBtnActive;

  void setBtnActive(bool active) {
    _isBtnActive = active;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    await _preferencesService.setOnboardingCompleted(true);
  }

  // Backward compatibility aliases
  bool get isShowSignInDialog => false;
  void openSignInDialog() {}
  void closeSignInDialog() {}
}
