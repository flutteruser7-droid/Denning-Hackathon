import 'package:flutter/foundation.dart';
import '../data/auth_repository.dart';
import '../models/user_model.dart';

enum SignUpStep {
  form,
  otpVerification,
  success,
}

class SignUpViewModel extends ChangeNotifier {
  final AuthRepository _repository;

  SignUpStep _currentStep = SignUpStep.form;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  UserModel? _registeredUser;

  String _name = '';
  String _email = '';
  String _password = '';

  String? _generatedOtp;
  DateTime? _otpExpiresAt;
  DateTime? _resendAvailableAt;
  int _failedAttempts = 0;
  static const int maxAttempts = 5;
  static const Duration otpLifetime = Duration(minutes: 5);
  static const Duration resendCooldown = Duration(seconds: 60);

  SignUpViewModel({AuthRepository? repository})
      : _repository = repository ?? FirebaseAuthRepository();

  SignUpStep get currentStep => _currentStep;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  UserModel? get registeredUser => _registeredUser;
  String get email => _email;
  int get remainingAttempts => maxAttempts - _failedAttempts;

  int get resendSecondsLeft {
    if (_resendAvailableAt == null) return 0;
    final diff = _resendAvailableAt!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  bool get canResendOtp => resendSecondsLeft <= 0;

  Future<bool> initiateSignUp({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final trimmedName = name.trim();
    final trimmedEmail = email.trim();

    if (trimmedName.isEmpty) {
      _errorMessage = "Please enter your name.";
      notifyListeners();
      return false;
    }

    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@') || !trimmedEmail.contains('.')) {
      _errorMessage = "Please enter a valid email address.";
      notifyListeners();
      return false;
    }

    if (password.length < 6) {
      _errorMessage = "Password must be at least 6 characters.";
      notifyListeners();
      return false;
    }

    if (password != confirmPassword) {
      _errorMessage = "Passwords do not match.";
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      _name = trimmedName;
      _email = trimmedEmail;
      _password = password;

      // Send 6-digit OTP via EmailJS
      _generatedOtp = await _repository.sendSignupOtp(
        email: _email,
        name: _name,
      );

      _otpExpiresAt = DateTime.now().add(otpLifetime);
      _resendAvailableAt = DateTime.now().add(resendCooldown);
      _failedAttempts = 0;
      _currentStep = SignUpStep.otpVerification;
      _successMessage = "A 6-digit verification code has been sent to $_email";
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll("Exception: ", "");
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtpAndRegister(String enteredOtp) async {
    final code = enteredOtp.trim();
    if (code.length != 6) {
      _errorMessage = "Please enter the complete 6-digit code.";
      notifyListeners();
      return false;
    }

    // Check expiry
    if (_otpExpiresAt == null || DateTime.now().isAfter(_otpExpiresAt!)) {
      _errorMessage = "The verification code has expired. Please request a new one.";
      notifyListeners();
      return false;
    }

    // Check failed attempts
    if (_failedAttempts >= maxAttempts) {
      _errorMessage = "Maximum attempts reached. Please request a new code.";
      notifyListeners();
      return false;
    }

    // Verify OTP match
    if (code != _generatedOtp) {
      _failedAttempts++;
      if (_failedAttempts >= maxAttempts) {
        _errorMessage = "Maximum attempts reached. Please request a new code.";
      } else {
        _errorMessage = "Invalid code. $remainingAttempts attempt(s) remaining.";
      }
      notifyListeners();
      return false;
    }

    // OTP Verified! Now execute real registration in Firebase and Firestore
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _registeredUser = await _repository.completeSignUpWithOtp(
        name: _name,
        email: _email,
        password: _password,
      );

      _currentStep = SignUpStep.success;
      _successMessage = "Account created successfully!";
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll("Exception: ", "");
      notifyListeners();
      return false;
    }
  }

  Future<bool> resendOtp() async {
    if (!canResendOtp) {
      _errorMessage = "Please wait $resendSecondsLeft seconds before resending.";
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _generatedOtp = await _repository.sendSignupOtp(
        email: _email,
        name: _name,
      );

      _otpExpiresAt = DateTime.now().add(otpLifetime);
      _resendAvailableAt = DateTime.now().add(resendCooldown);
      _failedAttempts = 0;
      _successMessage = "A new verification code has been sent.";
      _isLoading = false;
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
    _currentStep = SignUpStep.form;
    _isLoading = false;
    _errorMessage = null;
    _successMessage = null;
    _registeredUser = null;
    _name = '';
    _email = '';
    _password = '';
    _generatedOtp = null;
    _otpExpiresAt = null;
    _resendAvailableAt = null;
    _failedAttempts = 0;
    notifyListeners();
  }

  // Backward compatibility method
  Future<bool> signUp({
    required String email,
    required String password,
    required String confirmPassword,
    String name = 'User',
  }) async {
    return initiateSignUp(
      name: name,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
    );
  }
}
