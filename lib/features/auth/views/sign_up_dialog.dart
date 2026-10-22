import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../viewmodels/sign_up_view_model.dart';

void showSignUpDialog(BuildContext context, {ValueChanged? onValue}) {
  showGeneralDialog(
    context: context,
    barrierLabel: "Barrier",
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, anim1, anim2) {
      return AnimatedPadding(
        padding: MediaQuery.viewInsetsOf(context) +
            const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        duration: const Duration(milliseconds: 100),
        curve: Curves.decelerate,
        child: MediaQuery.removeViewInsets(
          removeLeft: true,
          removeTop: true,
          removeRight: true,
          removeBottom: true,
          context: context,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: Center(
              child: SingleChildScrollView(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      offset: const Offset(0, 30),
                      blurRadius: 60,
                    ),
                    const BoxShadow(
                      color: Colors.black45,
                      offset: Offset(0, 30),
                      blurRadius: 60,
                    ),
                  ],
                ),
                child: const Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Sign Up",
                        style: TextStyle(
                          fontSize: 32,
                          fontFamily: "Poppins",
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          "Create an account.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                      ),
                      SizedBox(height: 8),
                      SignUpFlow(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
},
    transitionBuilder: (context, anim, secondaryAnim, child) {
      final tween = Tween(begin: const Offset(0, -1), end: Offset.zero);
      return SlideTransition(
        position: tween.animate(
          CurvedAnimation(parent: anim, curve: Curves.easeInOut),
        ),
        child: child,
      );
    },
  ).then(onValue ?? (_) {});
}

class SignUpFlow extends StatefulWidget {
  final SignUpViewModel? viewModel;

  const SignUpFlow({super.key, this.viewModel});

  @override
  State<SignUpFlow> createState() => _SignUpFlowState();
}

class _SignUpFlowState extends State<SignUpFlow> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  late final SignUpViewModel _viewModel;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ?? SignUpViewModel();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
        if (_viewModel.resendSecondsLeft <= 0) {
          timer.cancel();
        }
      }
    });
  }

  Future<void> _initiateSignUp() async {
    if (_formKey.currentState!.validate()) {
      final success = await _viewModel.initiateSignUp(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
      );

      if (success) {
        _startTimer();
      }
    }
  }

  Future<void> _verifyOtp() async {
    final success = await _viewModel.verifyOtpAndRegister(_otpController.text);
    if (success && mounted) {
      _countdownTimer?.cancel();
    }
  }

  Future<void> _resendCode() async {
    final success = await _viewModel.resendOtp();
    if (success) {
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        if (_viewModel.currentStep == SignUpStep.otpVerification) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_viewModel.successMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _viewModel.successMessage!,
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_viewModel.errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _viewModel.errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Text(
                "Enter 6-Digit Verification Code",
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Check your email inbox or spam folder for the OTP code sent via EmailJS.",
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    counterText: "",
                    hintText: "000000",
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _viewModel.isLoading ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7553F6),
                  minimumSize: const Size(double.infinity, 54),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
                icon: _viewModel.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.checkmark_shield,
                        color: Colors.white,
                      ),
                label: Text(
                  _viewModel.isLoading
                      ? "Verifying..."
                      : "Verify & Create Account",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _viewModel.canResendOtp && !_viewModel.isLoading
                        ? _resendCode
                        : null,
                    child: Text(
                      _viewModel.canResendOtp
                          ? "Resend Code"
                          : "Resend in ${_viewModel.resendSecondsLeft}s",
                      style: TextStyle(
                        color: _viewModel.canResendOtp
                            ? const Color(0xFF7553F6)
                            : Colors.black38,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _countdownTimer?.cancel();
                      _viewModel.reset();
                    },
                    child: const Text(
                      "Change Email",
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        if (_viewModel.currentStep == SignUpStep.success) {
          return Column(
            children: [
              const SizedBox(height: 16),
              const Icon(
                CupertinoIcons.checkmark_circle_fill,
                color: Colors.green,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                "Welcome to the App!",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Poppins",
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Your account and profile have been created. Please sign in with your credentials.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7553F6),
                  minimumSize: const Size(double.infinity, 52),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
                child: const Text(
                  "Go to Sign In",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        }

        // Form Step
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_viewModel.errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _viewModel.errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Text(
                "Full Name",
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 10),
                child: TextFormField(
                  controller: _nameController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Please enter your name";
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: "Enter Your Name",
                    hintStyle: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ),
              ),
              const Text(
                "Email",
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 10),
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        !value.contains('@')) {
                      return "Please enter a valid email";
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: "name@example.com",
                    hintStyle: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ),
              ),
              const Text(
                "Password",
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 10),
                child: TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return "Password must be at least 6 characters";
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: "••••••••",
                    hintStyle: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ),
              ),
              const Text(
                "Confirm Password",
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                child: TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return "Passwords do not match";
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: "••••••••",
                    hintStyle: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _viewModel.isLoading ? null : _initiateSignUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF77D8E),
                  minimumSize: const Size(double.infinity, 54),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(25),
                      bottomRight: Radius.circular(25),
                      bottomLeft: Radius.circular(25),
                    ),
                  ),
                ),
                icon: _viewModel.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.arrow_right,
                        color: Colors.white,
                      ),
                label: Text(
                  _viewModel.isLoading
                      ? "Sending OTP..."
                      : "Verify Email & Sign Up",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Alias for backward compatibility
typedef SignUpForm = SignUpFlow;
