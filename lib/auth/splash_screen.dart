import 'package:emergency_app/auth/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _waveAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // Heartbeat / Pulse for the main logo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.1).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 40),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 20),
    ]).animate(_pulseController);

    _pulseController.repeat();

    // Radar / Ripple wave effect behind the logo
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _waveAnimation = Tween<double>(begin: 0.0, end: 1.5).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeOutQuad),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeOutQuad),
    );

    _waveController.repeat();

    // Navigate to LoginScreen after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 800),
            pageBuilder: (_, __, ___) => const LoginPage(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A dark, professional emergency theme gradient
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Color(0xFF1E141E), // Subtle dark reddish-purple
              Color(0xFF0A0A0E), // Almost black
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            
            // Logo with Radar Waves and Heartbeat Pulse
            SizedBox(
              width: 250,
              height: 250,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Expanding Waves
                  AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: List.generate(3, (index) {
                          final double offset = index * 0.33;
                          double t = (_waveController.value + offset) % 1.0;
                          
                          // Convert t to custom curve values
                          double scale = 1.0 + (t * 1.5);
                          double opacity = 1.0 - t;
                          
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFE53E3E).withOpacity(opacity * 0.5),
                                  width: 2.0,
                                ),
                                color: const Color(0xFFE53E3E).withOpacity(opacity * 0.1),
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  
                  // Pulsing Logo
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: child,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53E3E), // Urgent Emergency Red
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE53E3E).withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(12),
                          child: Image.asset(
                            'assets/emergency-services.png',
                            width: 100,
                            height: 100,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.health_and_safety_rounded,
                                  size: 100,
                                  color: Color(0xFFE53E3E),
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 50),
            
            // App Title
            Text(
              "EMERGENCY APP",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "FAST • RELIABLE • SECURE",
              style: GoogleFonts.inter(
                color: const Color(0xFFE53E3E),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 4.0,
              ),
            ),
            
            const Spacer(),
            
            // Bottom Loading Indicator
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE53E3E)),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Initializing secure connection...",
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}