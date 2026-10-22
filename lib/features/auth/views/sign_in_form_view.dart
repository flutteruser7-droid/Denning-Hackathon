import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import '../../../core/services/preferences_service.dart';
import '../../entry_point/views/entry_point_view.dart';
import '../viewmodels/sign_in_view_model.dart';
import 'forgot_password_dialog.dart';
import 'sign_up_dialog.dart';

class SignInFormView extends StatefulWidget {
  final SignInViewModel? viewModel;

  const SignInFormView({super.key, this.viewModel});

  @override
  State<SignInFormView> createState() => _SignInFormViewState();
}

class _SignInFormViewState extends State<SignInFormView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late final SignInViewModel _viewModel;

  SMITrigger? error;
  SMITrigger? success;
  SMITrigger? reset;
  SMITrigger? confetti;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ?? SignInViewModel();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onCheckRiveInit(Artboard artboard) {
    StateMachineController? controller = StateMachineController.fromArtboard(
      artboard,
      'State Machine 1',
    );

    if (controller != null) {
      artboard.addController(controller);
      error = controller.findInput<bool>('Error') as SMITrigger?;
      success = controller.findInput<bool>('Check') as SMITrigger?;
      reset = controller.findInput<bool>('Reset') as SMITrigger?;
    }
  }

  void _onConfettiRiveInit(Artboard artboard) {
    StateMachineController? controller = StateMachineController.fromArtboard(
      artboard,
      "State Machine 1",
    );
    if (controller != null) {
      artboard.addController(controller);
      confetti = controller.findInput<bool>("Trigger explosion") as SMITrigger?;
      confetti?.fire();
    }
  }

  Future<void> signIn(BuildContext context) async {
    _viewModel.setShowLoading(true);

    await Future.delayed(const Duration(seconds: 1));

    if (_formKey.currentState!.validate()) {
      final isSuccess = await _viewModel.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (isSuccess) {
        success?.fire();
        await Future.delayed(const Duration(seconds: 2));

        _viewModel.setShowLoading(false);
        _viewModel.setShowConfetti(true);
        confetti?.fire();

        await PreferencesService().setRememberMeEnabled(_viewModel.rememberMe);
        if (!context.mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const EntryPointView()),
          (route) => false,
        );
      } else {
        error?.fire();
        await Future.delayed(const Duration(seconds: 2));
        _viewModel.setShowLoading(false);
        _viewModel.setShowConfetti(false);
        reset?.fire();
      }
    } else {
      error?.fire();
      await Future.delayed(const Duration(seconds: 2));
      _viewModel.setShowLoading(false);
      _viewModel.setShowConfetti(false);
      reset?.fire();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Stack(
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_viewModel.errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                  const Text("Email", style: TextStyle(color: Colors.black54)),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    child: TextFormField(
                      controller: _emailController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "";
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hint: Text(
                          "hello@gmail.com",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    "Password",
                    style: TextStyle(color: Colors.black54),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "";
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hint: Text(
                          "********",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _viewModel.rememberMe,
                              activeColor: const Color(0xFFF77D8E),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (val) {
                                _viewModel.setRememberMe(val ?? false);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              _viewModel.setRememberMe(!_viewModel.rememberMe);
                            },
                            child: const Text(
                              "Remember me",
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          showForgotPasswordDialog(context);
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          "Forgot Password?",
                          style: TextStyle(
                            color: Color(0xFFF77D8E),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        signIn(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF77D8E),
                        minimumSize: const Size(double.infinity, 56),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(25),
                            bottomRight: Radius.circular(25),
                            bottomLeft: Radius.circular(25),
                          ),
                        ),
                      ),
                      icon: const Icon(
                        CupertinoIcons.arrow_right,
                        color: Colors.white,
                      ),
                      label: const Text("Sign In"),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          showSignUpDialog(context);
                        },
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          child: Text(
                            "Sign Up",
                            style: TextStyle(
                              color: Color(0xFFF77D8E),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _viewModel.isShowLoading
                ? CustomPositioned(
                    child: RiveAnimation.asset(
                      'assets/RiveAssets/check.riv',
                      fit: BoxFit.cover,
                      onInit: _onCheckRiveInit,
                    ),
                  )
                : const SizedBox(),
            _viewModel.isShowConfetti
                ? CustomPositioned(
                    scale: 6,
                    child: RiveAnimation.asset(
                      "assets/RiveAssets/confetti.riv",
                      onInit: _onConfettiRiveInit,
                      fit: BoxFit.cover,
                    ),
                  )
                : const SizedBox(),
          ],
        );
      },
    );
  }
}

class CustomPositioned extends StatelessWidget {
  const CustomPositioned({super.key, this.scale = 1, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Column(
          children: [
            const Spacer(),
            SizedBox(
              height: 100,
              width: 100,
              child: Transform.scale(scale: scale, child: child),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}

// Alias for backward compatibility
typedef SignInForm = SignInFormView;
