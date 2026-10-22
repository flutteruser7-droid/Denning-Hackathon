import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart' hide Image;

import '../../auth/views/sign_in_view.dart';
import '../viewmodels/onboarding_view_model.dart';
import 'widgets/animated_btn.dart';

/// Clean, modern Welcome/Onboarding screen shown only on first launch.
class OnboardingView extends StatefulWidget {
  final OnboardingViewModel? viewModel;

  const OnboardingView({super.key, this.viewModel});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  late final OnboardingViewModel _viewModel;
  late RiveAnimationController _btnAnimationController;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ?? OnboardingViewModel();
    _btnAnimationController = OneShotAnimation(
      "active",
      autoplay: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFEEF1F8),
          body: Stack(
            children: [
              // Background decorative artwork
              Positioned(
                width: size.width * 1.7,
                left: 100,
                bottom: 100,
                child: Image.asset(
                  "assets/Backgrounds/Spline.png",
                ),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: const SizedBox(),
                ),
              ),
              // Background Rive shapes
              const RiveAnimation.asset(
                "assets/RiveAssets/shapes.riv",
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: const SizedBox(),
                ),
              ),
              // Main content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      SizedBox(
                        width: 280,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFDEE3F2),
                                ),
                              ),
                              child: const Text(
                                "WELCOME",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: Color(0xFF17203A),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Welcome",
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w700,
                                fontFamily: "Poppins",
                                height: 1.1,
                                color: Color(0xFF17203A),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Experience modern animated interactions, clean architecture, and secure authentication built with Flutter.",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.black54,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(flex: 2),
                      AnimatedBtn(
                        btnAnimationController: _btnAnimationController,
                        press: () {
                          _btnAnimationController.isActive = true;

                          Future.delayed(
                            const Duration(milliseconds: 800),
                            () async {
                              await _viewModel.completeOnboarding();
                              if (!context.mounted) return;
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SignInView(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          "Fast, secure, and intuitive experience.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                          ),
                        ),
                      ),
                    ],
                  ),
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
typedef OnbodingScreen = OnboardingView;
