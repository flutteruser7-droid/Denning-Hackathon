import 'package:flutter/foundation.dart';
import '../data/auth_repository.dart';
import '../models/user_model.dart';

class SignInViewModel extends ChangeNotifier {
  final AuthRepository _repository;

  bool _isLoading = false;
  bool _isShowLoading = false;
  bool _isShowConfetti = false;
  bool _rememberMe = false;
  String? _errorMessage;
  UserModel? _currentUser;

  SignInViewModel({AuthRepository? repository})
      : _repository = repository ?? FirebaseAuthRepository();

  bool get isLoading => _isLoading;
  bool get isShowLoading => _isShowLoading;
  bool get isShowConfetti => _isShowConfetti;
  bool get rememberMe => _rememberMe;
  String? get errorMessage => _errorMessage;
  UserModel? get currentUser => _currentUser;

  void setShowLoading(bool value) {
    _isShowLoading = value;
    notifyListeners();
  }

  void setShowConfetti(bool value) {
    _isShowConfetti = value;
    notifyListeners();
  }

  void setRememberMe(bool value) {
    _rememberMe = value;
    notifyListeners();
  }

  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _repository.signIn(
        email: email,
        password: password,
      );
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
    _isLoading = false;
    _isShowLoading = false;
    _isShowConfetti = false;
    _errorMessage = null;
    notifyListeners();
  }
}
