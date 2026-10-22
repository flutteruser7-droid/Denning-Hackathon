import 'package:flutter/foundation.dart';
import '../data/auth_repository.dart';

class ForgotPasswordViewModel extends ChangeNotifier {
  final AuthRepository _repository;

  bool _isLoading = false;
  bool _isEmailSent = false;
  String? _errorMessage;
  String? _successMessage;

  ForgotPasswordViewModel({AuthRepository? repository})
      : _repository = repository ?? FirebaseAuthRepository();

  bool get isLoading => _isLoading;
  bool get isEmailSent => _isEmailSent;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  Future<bool> sendPasswordResetEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@') || !trimmed.contains('.')) {
      _errorMessage = "Please enter a valid email address.";
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _repository.sendPasswordResetEmail(email: trimmed);
      _isLoading = false;
      _isEmailSent = true;
      _successMessage =
          "If an account exists with this email, a password reset link has been sent to your inbox.";
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll("Exception: ", "");
      notifyListeners();
      return false;
    }
  }

  void reset() {
    _isLoading = false;
    _isEmailSent = false;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  // --- Backward compatibility aliases ---
  int get currentStep => _isEmailSent ? 1 : 0;
  String get email => '';
  Future<bool> sendOtp(String email) => sendPasswordResetEmail(email);
  bool verifyOtp(String otp) => true;
  Future<bool> resetPassword({required String newPassword, required String confirmPassword}) async => true;
}
