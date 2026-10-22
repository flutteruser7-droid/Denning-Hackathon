import 'package:flutter_test/flutter_test.dart';
import 'package:rive_animation/features/auth/data/auth_repository.dart';
import 'package:rive_animation/features/auth/models/user_model.dart';
import 'package:rive_animation/features/auth/viewmodels/forgot_password_view_model.dart';
import 'package:rive_animation/features/auth/viewmodels/sign_in_view_model.dart';
import 'package:rive_animation/features/auth/viewmodels/sign_up_view_model.dart';

class MockAuthRepository implements AuthRepository {
  @override
  Future<UserModel> signIn({required String email, required String password}) async {
    if (password == 'wrong') {
      throw Exception('Invalid email or password.');
    }
    return UserModel(uid: '123', email: email, name: 'Test User');
  }

  @override
  Future<String> sendSignupOtp({required String email, required String name}) async {
    if (email == 'fail@example.com') {
      throw Exception('Failed to send OTP');
    }
    return '123456';
  }

  @override
  Future<UserModel> completeSignUpWithOtp({
    required String name,
    required String email,
    required String password,
  }) async {
    return UserModel(uid: 'new_uid', email: email, name: name);
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    if (email == 'fail@example.com') {
      throw Exception('Network error');
    }
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<UserModel?> getCurrentUserProfile() async => null;

  @override
  UserModel? getCurrentUser() => null;

  @override
  Future<UserModel> signUp({required String email, required String password, String name = 'User'}) async {
    return completeSignUpWithOtp(name: name, email: email, password: password);
  }

  @override
  Future<String> sendPasswordResetOtp({required String email}) async => '123456';

  @override
  bool verifyOtp({required String enteredOtp, required String expectedOtp}) => enteredOtp == expectedOtp;

  @override
  Future<void> resetPassword({required String email, required String newPassword}) async {}
}

void main() {
  group('Auth ViewModels Tests', () {
    test('SignInViewModel success and failure states', () async {
      final repo = MockAuthRepository();
      final viewModel = SignInViewModel(repository: repo);

      expect(viewModel.isLoading, isFalse);

      final success = await viewModel.signIn(email: 'test@example.com', password: 'password123');
      expect(success, isTrue);
      expect(viewModel.currentUser?.email, 'test@example.com');
      expect(viewModel.errorMessage, isNull);

      final failure = await viewModel.signIn(email: 'test@example.com', password: 'wrong');
      expect(failure, isFalse);
      expect(viewModel.errorMessage, isNotNull);

      // Verify Remember Me toggle
      expect(viewModel.rememberMe, isFalse);
      viewModel.setRememberMe(true);
      expect(viewModel.rememberMe, isTrue);
      viewModel.setRememberMe(false);
      expect(viewModel.rememberMe, isFalse);
    });

    test('SignUpViewModel validation: checks name, email, password match and length', () async {
      final repo = MockAuthRepository();
      final viewModel = SignUpViewModel(repository: repo);

      // Empty name
      final noName = await viewModel.initiateSignUp(
        name: '',
        email: 'test@example.com',
        password: 'password123',
        confirmPassword: 'password123',
      );
      expect(noName, isFalse);
      expect(viewModel.errorMessage, 'Please enter your name.');

      // Passwords mismatch
      final mismatch = await viewModel.initiateSignUp(
        name: 'John',
        email: 'test@example.com',
        password: 'password123',
        confirmPassword: 'mismatch',
      );
      expect(mismatch, isFalse);
      expect(viewModel.errorMessage, 'Passwords do not match.');

      // Short password
      final shortPass = await viewModel.initiateSignUp(
        name: 'John',
        email: 'test@example.com',
        password: '123',
        confirmPassword: '123',
      );
      expect(shortPass, isFalse);
      expect(viewModel.errorMessage, 'Password must be at least 6 characters.');
    });

    test('SignUpViewModel OTP flow: send OTP, failed attempts, and verify to complete', () async {
      final repo = MockAuthRepository();
      final viewModel = SignUpViewModel(repository: repo);

      // 1. Initiate SignUp sends OTP
      final sent = await viewModel.initiateSignUp(
        name: 'John Doe',
        email: 'test@example.com',
        password: 'password123',
        confirmPassword: 'password123',
      );
      expect(sent, isTrue);
      expect(viewModel.currentStep, SignUpStep.otpVerification);
      expect(viewModel.remainingAttempts, 5);

      // 2. Incorrect OTP increments failed attempts
      final wrong = await viewModel.verifyOtpAndRegister('000000');
      expect(wrong, isFalse);
      expect(viewModel.remainingAttempts, 4);

      // 3. Correct OTP completes registration
      final success = await viewModel.verifyOtpAndRegister('123456');
      expect(success, isTrue);
      expect(viewModel.currentStep, SignUpStep.success);
      expect(viewModel.registeredUser?.name, 'John Doe');
      expect(viewModel.registeredUser?.uid, 'new_uid');
    });

    test('ForgotPasswordViewModel sendPasswordResetEmail', () async {
      final repo = MockAuthRepository();
      final viewModel = ForgotPasswordViewModel(repository: repo);

      expect(viewModel.isEmailSent, isFalse);

      // Invalid email
      final invalid = await viewModel.sendPasswordResetEmail('not-an-email');
      expect(invalid, isFalse);
      expect(viewModel.errorMessage, 'Please enter a valid email address.');

      // Valid email
      final success = await viewModel.sendPasswordResetEmail('user@example.com');
      expect(success, isTrue);
      expect(viewModel.isEmailSent, isTrue);
      expect(viewModel.successMessage, isNotNull);
    });
  });
}
