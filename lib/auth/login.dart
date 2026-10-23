import 'dart:math' as math;
import 'package:emergency_app/Ambulance/ambulance_dashboard.dart';
import 'package:emergency_app/Fire/fire_dashboard.dart';
import 'package:emergency_app/Poice/police.dart';
import 'package:emergency_app/User/user_dashboard.dart';
import 'package:emergency_app/auth/RegisterUser.dart';
import 'package:emergency_app/Admin/admin_dashboard_ui.dart';
import 'package:emergency_app/theme/darkmode.dart';
import 'package:emergency_app/auth/admin_selection.dart' as emergency_app_admin_selection;
// import 'package:emergency_app/theme/darkmode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  // ── Controllers ────────────────────────────────────────────────────────────
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // ── State ──────────────────────────────────────────────────────────────────
  bool _obscurePass = true;
  bool _rememberMe = false;
  bool _isLoading = true; // true on init for auto-login check

  // ── Animation ──────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _initPage();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // THEME COLORS — switches between dark / light
  // ══════════════════════════════════════════════════════════════════════════

  // Shared
  static const Color cRed = Color(0xFFE53E3E);
  static const Color cRedDark = Color(0xFFC02828);
  static const Color cNavy3 = Color(0xFF1A3A72);

  // Dark palette
  static const Color dBg = Color(0xFF060E1F);
  static const Color dNavy1 = Color(0xFF071D3F);
  static const Color dNavy2 = Color(0xFF0A2550);
  static const Color dCardBg = Color(0xFF0D1B2E);
  static const Color dInputBg = Color(0xFF101F35);
  static const Color dBorder = Color(0xFF1E3A5A);
  static const Color dText = Color(0xFFEAF0FB);
  static const Color dHint = Color(0xFF3D6080);
  static const Color dSub = Color(0xFF5A7FA0);
  static const Color dLabel = Color(0xFF6A90B0);

  // Light palette
  static const Color lBg = Color(0xFFF0F4FA);
  static const Color lNavy1 = Color(0xFF0D2550);
  static const Color lNavy2 = Color(0xFF0A2550);
  static const Color lCardBg = Color(0xFFFFFFFF);
  static const Color lInputBg = Color(0xFFF5F9FF);
  static const Color lBorder = Color(0xFFD4E2F5);
  static const Color lText = Color(0xFF071830);
  static const Color lHint = Color(0xFFB0C0D0);
  static const Color lSub = Color(0xFF8FA2B5);
  static const Color lLabel = Color(0xFF4A6380);

  // Reads from the global ThemeNotifier (no local state needed)
  // bool get _isDarkMode => context.isDarkMode;
  bool _isDarkMode = true;
  Color get cBg => _isDarkMode ? dBg : lBg;
  Color get cNavy1 => _isDarkMode ? dNavy1 : lNavy1;
  Color get cNavy2 => _isDarkMode ? dNavy2 : lNavy2;
  Color get cCardBg => _isDarkMode ? dCardBg : lCardBg;
  Color get cInputBg => _isDarkMode ? dInputBg : lInputBg;
  Color get cBorder => _isDarkMode ? dBorder : lBorder;
  Color get cText => _isDarkMode ? dText : lText;
  Color get cHint => _isDarkMode ? dHint : lHint;
  Color get cSub => _isDarkMode ? dSub : lSub;
  Color get cLabel => _isDarkMode ? dLabel : lLabel;
  Color get cWhite => _isDarkMode ? dText : lText; // text on dark bg

  // ══════════════════════════════════════════════════════════════════════════
  // SESSION MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _saveUserSession(
    String userId,
    String role,
    String email, {
    String? serviceType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setBool('rememberMe', _rememberMe);
    await prefs.setString('userId', userId);
    await prefs.setString('userRole', role);
    await prefs.setString('userEmail', email);
    if (serviceType != null) await prefs.setString('serviceType', serviceType);
  }

  Future<void> _loadTheme() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => _isDarkMode = p.getBool('isDarkMode') ?? true);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.setBool('rememberMe', false);
    await prefs.remove('userId');
    await prefs.remove('userRole');
    await prefs.remove('userEmail');
    await prefs.remove('serviceType');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AUTO LOGIN ON INIT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _initPage() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('rememberMe') ?? false;
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final savedEmail = prefs.getString('userEmail') ?? '';
    final savedUserId = prefs.getString('userId');
    final savedRole = prefs.getString('userRole');
    final savedSvcType = prefs.getString('serviceType');

    // Pre-fill email if remember me was on
    if (rememberMe && savedEmail.isNotEmpty) {
      _emailCtrl.text = savedEmail;
    }

    if (mounted) setState(() => _rememberMe = rememberMe);

    // No valid session — show login form
    if (!rememberMe || !isLoggedIn || savedUserId == null) {
      await FirebaseAuth.instance.signOut();
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final currentUser = await FirebaseAuth.instance
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 5));

      if (currentUser == null || currentUser.uid != savedUserId) {
        await _clearSession();
        await FirebaseAuth.instance.signOut();
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Auto-route
      if (savedRole == 'user') {
        _navigateTo(const UserDashboard());
        return;
      } else if (savedRole == 'service' && savedSvcType != null) {
        _routeToServiceDashboard(savedSvcType);
        return;
      }
    } catch (e) {
      debugPrint('Auto-login error: $e');
      await _clearSession();
      await FirebaseAuth.instance.signOut();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MAIN LOGIN LOGIC
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loginUser() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
      _showSnack('Please enter email and password', error: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      final uid = cred.user!.uid;
      final email = _emailCtrl.text.trim();

      // ── Check Emergency Service ────────────────────────────────────────
      final serviceDoc = await FirebaseFirestore.instance
          .collection('EmergencyServices')
          .doc(uid)
          .get();

      if (serviceDoc.exists) {
        final serviceType = serviceDoc['serviceType'] ?? 'Unknown';

        if (_rememberMe) {
          await _saveUserSession(
            uid,
            'service',
            email,
            serviceType: serviceType,
          );
        } else {
          await _clearSession();
        }

        _showSnack('Logged in as $serviceType');
        _emailCtrl.clear();
        _passCtrl.clear();
        _routeToServiceDashboard(serviceType);
        return;
      }

      // ── Check Admin User ──────────────────────────────────────────────
      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(uid)
          .get();

      if (adminDoc.exists) {
        final serviceType = adminDoc['department_type'] ?? 'Unknown';
        
        if (_rememberMe) {
          await _saveUserSession(
            uid,
            'service',
            email,
            serviceType: serviceType,
          );
        } else {
          await _clearSession();
        }

        _showSnack('Logged in as Admin ($serviceType)');
        _emailCtrl.clear();
        _passCtrl.clear();
        _routeToServiceDashboard(serviceType);
        return;
      }

      // ── Check Normal User ──────────────────────────────────────────────
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        final status = userDoc['applicationStatus'] ?? 'pending';

        if (status == 'active' || status == 'approved') {
          if (_rememberMe) {
            await _saveUserSession(uid, 'user', email);
          } else {
            await _clearSession();
          }
          _showSnack('Welcome back, ${userDoc['full_name'] ?? 'User'}!');
          _emailCtrl.clear();
          _passCtrl.clear();
          _navigateTo(const UserDashboard());
          return;
        } else {
          await FirebaseAuth.instance.signOut();
          _showSnack('Account is pending approval or inactive.', error: true);
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }



      // ── Not found in any collection ────────────────────────────────────
      await FirebaseAuth.instance.signOut();
      _showSnack('Account data not found in database.', error: true);
    } on FirebaseAuthException catch (e) {
      String msg = 'Login failed';
      if (e.code == 'user-not-found') msg = 'No user found with this email.';
      if (e.code == 'wrong-password') msg = 'Wrong password provided.';
      if (e.code == 'invalid-credential') msg = 'Invalid email or password.';
      _showSnack(msg, error: true);
    } catch (e) {
      _showSnack('Error: ${e.toString()}', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Service routing ────────────────────────────────────────────────────────
 void _routeToServiceDashboard(String serviceType) {
    final type = serviceType.toLowerCase();
    
    // Check if it's one of your recognized services
    if (type == 'fire brigade' || type == 'police' || type == 'ambulance') {
      _navigateTo(AdminDashboardUI(serviceType: serviceType, primaryColor: cNavy1, serviceIcon: Icons.security));
    } else {
      _showSnack('Invalid service type. Contact Support.', error: true);
      FirebaseAuth.instance.signOut();
      _clearSession();
    }
  }
  void _navigateTo(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  // ── Forgot Password Dialog ─────────────────────────────────────────────────
  void _forgotPasswordDialog() {
    final resetCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Reset Password',
          style: TextStyle(color: cText, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: resetCtrl,
          style: TextStyle(color: cText),
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'Enter your email',
            hintStyle: TextStyle(color: cHint),
            prefixIcon: Icon(Icons.email_outlined, color: cSub, size: 18),
            filled: true,
            fillColor: cInputBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: cNavy3),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: cSub)),
          ),
          TextButton(
            onPressed: () async {
              if (resetCtrl.text.trim().isEmpty) {
                _showSnack('Please enter your email', error: true);
                return;
              }
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: resetCtrl.text.trim(),
                );
                _showSnack('Password reset email sent!');
                if (mounted) Navigator.pop(ctx);
              } catch (e) {
                _showSnack('Error: ${e.toString()}', error: true);
              }
            },
            child: const Text('Send', style: TextStyle(color: cNavy3)),
          ),
        ],
      ),
    );
  }

  // ── Snack bar ──────────────────────────────────────────────────────────────
  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: error ? Colors.redAccent : Colors.teal[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      _isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );

    // Full-screen loader while auto-login check runs
    if (_isLoading) {
      return Scaffold(
        backgroundColor: cBg,
        body: Center(
          child: CircularProgressIndicator(
            color: _isDarkMode ? Colors.tealAccent : cNavy3,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: cBg,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [_buildTopSection(), _buildCardSection()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Background ─────────────────────────────────────────────────────────────
  Widget _buildBackground() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.6, -0.8),
          radius: 1.2,
          colors: _isDarkMode
              ? [const Color(0x8C0D3C82), const Color(0x00060E1F)]
              : [const Color(0x300D3C82), const Color(0x00F0F4FA)],
        ),
      ),
    );
  }

  // ── Top dark section with animated logo ────────────────────────────────────
  Widget _buildTopSection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cNavy1, cNavy2],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 52),
      child: Column(
        children: [
          // Dark mode toggle — top right
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () async {
                setState(() => _isDarkMode = !_isDarkMode);
                final p = await SharedPreferences.getInstance();
                await p.setBool('isDarkMode', _isDarkMode);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 52,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: _isDarkMode
                      ? const Color(0xFF1A3A72)
                      : const Color(0xFFE2E8F0),
                  border: Border.all(
                    color: _isDarkMode ? Colors.white24 : Colors.black12,
                  ),
                ),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      left: _isDarkMode ? 26 : 2,
                      top: 2,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isDarkMode
                              ? Colors.tealAccent
                              : const Color(0xFF0A2550),
                        ),
                        child: Icon(
                          _isDarkMode ? Icons.nightlight_round : Icons.wb_sunny,
                          size: 14,
                          color: _isDarkMode
                              ? const Color(0xFF060E1F)
                              : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Animated logo
          _buildAnimatedLogo(),
          const SizedBox(height: 12),

          const Text(
            'RescueNow',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'EMERGENCY SERVICES',
            style: TextStyle(
              color: Color(0x66FFFFFF),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  // ── SOS Animated Logo ──────────────────────────────────────────────────────
  Widget _buildAnimatedLogo() {
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _PulseRing(controller: _pulseCtrl, delay: 0.0, size: 80, color: cRed),
          _PulseRing(
            controller: _pulseCtrl,
            delay: 0.33,
            size: 80,
            color: cRed,
          ),
          _PulseRing(
            controller: _pulseCtrl,
            delay: 0.66,
            size: 80,
            color: cRed,
          ),
          SizedBox(
            width: 72,
            height: 72,
            // decoration: BoxDecoration(
            //   borderRadius: BorderRadius.circular(22),
            //   gradient: const LinearGradient(
            //     begin: Alignment.topLeft,
            //     end: Alignment.bottomRight,
            //     colors: [Color(0xFF0F2550), cNavy3],
            //   ),
            //   border: Border.all(color: Colors.white12, width: 1.5),
            //   boxShadow: const [
            //     BoxShadow(
            //       color: Color(0x66000000),
            //       blurRadius: 20,
            //       offset: Offset(0, 8),
            //     ),
            //   ],
            // ),
            child: Center(
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cRed, cRedDark],
                  ),
                  border: Border.all(color: Colors.white30, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x80C02828),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card section ───────────────────────────────────────────────────────────
  Widget _buildCardSection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      color: _isDarkMode ? dBg : const Color(0xFFEDF2FB),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      child: Column(
        children: [
          Transform.translate(
            offset: const Offset(0, -28),
            child: _buildSignInCard(),
          ),
          Transform.translate(
            offset: const Offset(0, -16),
            // child: _buildEmergencyNote(),
          ),
          Transform.translate(
            offset: const Offset(0, -8),
            child: _buildTerms(),
          ),
        ],
      ),
    );
  }

  // ── Sign In Card ───────────────────────────────────────────────────────────
  Widget _buildSignInCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: cCardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cBorder, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode
                ? const Color(0x40000000)
                : const Color(0x14000000),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back 👋',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: cText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sign in to your account to continue',
            style: TextStyle(fontSize: 12, color: cSub),
          ),
          const SizedBox(height: 22),

          // Email
          _buildInputGroup(
            label: 'EMAIL ADDRESS',
            controller: _emailCtrl,
            icon: Icons.email_outlined,
            hint: 'Enter your email',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),

          // Password
          _buildPasswordField(),
          const SizedBox(height: 16),

          // Remember + Forgot
          _buildRememberRow(),
          const SizedBox(height: 20),

          // Sign In button
          _buildSignInButton(),
          const SizedBox(height: 20),

          // Sign up row
          _buildSignupRow(),
        ],
      ),
    );
  }

  // ── Input Group ────────────────────────────────────────────────────────────
  Widget _buildInputGroup({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: cLabel,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: 14, color: cText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: cHint, fontSize: 14),
            prefixIcon: Icon(icon, color: cSub, size: 18),
            filled: true,
            fillColor: cInputBg,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: cBorder, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: cBorder, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: cNavy3, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ── Password Field ─────────────────────────────────────────────────────────
  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PASSWORD',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: cLabel,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _passCtrl,
          obscureText: _obscurePass,
          style: TextStyle(fontSize: 14, color: cText),
          decoration: InputDecoration(
            hintText: 'Enter your password',
            hintStyle: TextStyle(color: cHint, fontSize: 14),
            prefixIcon: Icon(Icons.lock_outline_rounded, color: cSub, size: 18),
            suffixIcon: GestureDetector(
              onTap: () => setState(() => _obscurePass = !_obscurePass),
              child: Icon(
                _obscurePass
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: cSub,
                size: 18,
              ),
            ),
            filled: true,
            fillColor: cInputBg,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: cBorder, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: cBorder, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: cNavy3, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ── Remember + Forgot row ──────────────────────────────────────────────────
  Widget _buildRememberRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => setState(() => _rememberMe = !_rememberMe),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: _rememberMe ? cNavy3 : cInputBg,
                  border: Border.all(
                    color: _rememberMe ? cNavy3 : cBorder,
                    width: 1.5,
                  ),
                ),
                child: _rememberMe
                    ? const Icon(Icons.check, color: Colors.white, size: 12)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                'Remember me',
                style: TextStyle(
                  fontSize: 12,
                  color: cSub,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _forgotPasswordDialog,
          child: Text(
            'Forgot password?',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cNavy3,
            ),
          ),
        ),
      ],
    );
  }

  // ── Sign In Button ─────────────────────────────────────────────────────────
  Widget _buildSignInButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _loginUser,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF0F2550), cNavy3],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x590F2550),
              blurRadius: 18,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.login_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Sign In',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Sign Up Row ────────────────────────────────────────────────────────────
  Widget _buildSignupRow() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account?",
              style: TextStyle(fontSize: 13, color: cSub),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserApplication()),
                );
              },
              child: const Text(
                'Create account',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cNavy3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const emergency_app_admin_selection.AdminSelection()),
            );
          },
          child: const Text(
            'Admin Setup',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: cRed,
            ),
          ),
        ),
      ],
    );
  }

  // ── Emergency Note ─────────────────────────────────────────────────────────
  Widget _buildEmergencyNote() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1A0A0A) : const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isDarkMode
              ? const Color(0xFF3D1212)
              : const Color(0xFFFECACA),
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFDC2626),
            size: 17,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 11,
                  color: _isDarkMode
                      ? const Color(0xFFFFAAAA)
                      : const Color(0xFF7F1D1D),
                  height: 1.5,
                ),
                children: const [
                  TextSpan(
                    text: 'In an emergency? ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  TextSpan(text: 'You do not need to sign in. Call '),
                  TextSpan(
                    text: '1122',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  TextSpan(text: ' or '),
                  TextSpan(
                    text: '15',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  TextSpan(text: ' directly for immediate help.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Terms ──────────────────────────────────────────────────────────────────
  Widget _buildTerms() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            fontSize: 10,
            color: cSub.withOpacity(0.7),
            height: 1.6,
          ),
          children: const [
            TextSpan(text: 'By signing in, you agree to our '),
            TextSpan(
              text: 'Terms of Service',
              style: TextStyle(color: cNavy3, fontWeight: FontWeight.w600),
            ),
            TextSpan(text: ' and '),
            TextSpan(
              text: 'Privacy Policy',
              style: TextStyle(color: cNavy3, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PULSE RING WIDGET
// ══════════════════════════════════════════════════════════════════════════════
class _PulseRing extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final double size;
  final Color color;

  const _PulseRing({
    required this.controller,
    required this.delay,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        final t = (controller.value + delay) % 1.0;
        final curved = 1 - math.pow(1 - t, 3).toDouble();
        final scale = 1.0 + curved * 0.6;
        final opacity = (1 - t) * 0.45;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(opacity), width: 1.5),
            ),
          ),
        );
      },
    );
  }
}
