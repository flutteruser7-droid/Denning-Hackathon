import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class UserApplication extends StatefulWidget {
  const UserApplication({super.key});

  @override
  State<UserApplication> createState() => _UserApplicationState();
}

class _UserApplicationState extends State<UserApplication>
    with TickerProviderStateMixin {
  // ── Firebase ───────────────────────────────────────────────────────────────
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Controllers ────────────────────────────────────────────────────────────
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _nicNumberController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _homeAddressController = TextEditingController();
  final TextEditingController _emergency1Controller = TextEditingController();
  final TextEditingController _emergency2Controller = TextEditingController();

  // ── Dropdowns ──────────────────────────────────────────────────────────────
  String? _selectedBloodGroup;
  final List<String> _bloodGroups = [
    'A+',
    'A−',
    'B+',
    'B−',
    'AB+',
    'AB−',
    'O+',
    'O−',
  ];

  // ── Logic State ────────────────────────────────────────────────────────────
  bool _isUploading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _currentStep = 0;
  bool _isEmailAvailable = true;
  bool _isCheckingEmail = false;
  String _emailError = '';
  bool _isOtpSent = false;
  bool _isOtpVerified = false;
  String _generatedOtp = '';
  DateTime? _otpExpiresAt;
  String _otpEmail = '';
  Map<String, String>? _emailJsConfig;

  // ── UI State ───────────────────────────────────────────────────────────────
  // Dark mode is managed globally via ThemeNotifier (see lib/theme/darkmode.dart).
  // Use _isDarkMode getter below to read the current value.

  // ── Animation ──────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;

  final _formKey = GlobalKey<FormState>();

  // ══════════════════════════════════════════════════════════════════════════
  // THEME COLORS
  // ══════════════════════════════════════════════════════════════════════════

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

  // Reads dark mode from the global ThemeNotifier (no local state needed)
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

  // Teal accent adapts to mode
  Color get cAccent =>
      _isDarkMode ? Colors.tealAccent : const Color(0xFF00897B);

  // ══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
     _loadTheme(); 
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }
Future<void> _loadTheme() async {
  final p = await SharedPreferences.getInstance();
  if (mounted) setState(() => _isDarkMode = p.getBool('isDarkMode') ?? true);
}
  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicNumberController.dispose();
    _otpController.dispose();
    _homeAddressController.dispose();
    _emergency1Controller.dispose();
    _emergency2Controller.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOGIC
  // ══════════════════════════════════════════════════════════════════════════

  String _generateOtp() {
    final rand = Random.secure();
    return List.generate(6, (_) => rand.nextInt(10)).join();
  }

  Future<Map<String, String>> _loadEmailJsConfig() async {
    final cached = _emailJsConfig;
    if (cached != null) return cached;

    final contents = await rootBundle.loadString('lib/.env');
    final values = <String, String>{};
    for (final rawLine in contents.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final separator = line.indexOf('=');
      if (separator <= 0) continue;

      final key = line.substring(0, separator).trim();
      var value = line.substring(separator + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      values[key] = value;
    }

    const requiredKeys = [
      'EMAILJS_SERVICE_ID',
      'EMAILJS_TEMPLATE_ID',
      'EMAILJS_PUBLIC_KEY',
      'EMAILJS_PRIVATE_KEY',
    ];
    final missing = requiredKeys.where((key) {
      final value = values[key];
      return value == null || value.isEmpty;
    }).toList();
    if (missing.isNotEmpty) {
      throw StateError(
        'Email OTP configuration is missing: ${missing.join(', ')}',
      );
    }

    _emailJsConfig = values;
    return values;
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.redAccent : Colors.teal[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<bool> _checkEmailAvailability(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _isEmailAvailable = false);
      return false;
    }
    setState(() {
      _isCheckingEmail = true;
      _emailError = '';
    });
    try {
      final activeApp = await _firestore
          .collection('active_applications')
          .where('email', isEqualTo: email)
          .where('applicationStatus', isEqualTo: 'active')
          .limit(1)
          .get();
      if (activeApp.docs.isNotEmpty) {
        setState(() {
          _isEmailAvailable = false;
          _emailError = 'You already have an active application';
        });
        return false;
      }
      final approvedApp = await _firestore
          .collection('active_applications')
          .where('email', isEqualTo: email)
          .where('applicationStatus', isEqualTo: 'approved')
          .limit(1)
          .get();
      if (approvedApp.docs.isNotEmpty) {
        setState(() {
          _isEmailAvailable = false;
          _emailError = 'Your account is already approved. Please login';
        });
        return false;
      }
      final user = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (user.docs.isNotEmpty) {
        setState(() {
          _isEmailAvailable = false;
          _emailError = 'An account with this email already exists';
        });
        return false;
      }
      setState(() {
        _isEmailAvailable = true;
        _emailError = '';
      });
      return true;
    } catch (e) {
      debugPrint('Error checking email: $e');
      setState(() {
        _isEmailAvailable = true;
        _emailError = '';
      });
      return true;
    } finally {
      if (mounted) setState(() => _isCheckingEmail = false);
    }
  }

  Future<void> _sendEmailOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Please enter a valid email in Step 1 first.', error: true);
      return;
    }
    final isAvailable = await _checkEmailAvailability(email);
    if (!isAvailable) {
      _showSnack(_emailError, error: true);
      return;
    }
    setState(() => _isUploading = true);

    try {
      final emailJs = await _loadEmailJsConfig();
      _generatedOtp = _generateOtp();
      _otpEmail = email;

      // Setting expiration time to 15 minutes to match template description
      final expiresAtTime = DateTime.now().add(const Duration(minutes: 15));
      _otpExpiresAt = expiresAtTime;
      final formattedTime = TimeOfDay.fromDateTime(
        expiresAtTime,
      ).format(context);

      final response = await http
          .post(
            Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
            headers: {
              'Content-Type': 'application/json',
              'Origin': 'http://localhost',
            },
            body: jsonEncode({
              'service_id': emailJs['EMAILJS_SERVICE_ID'],
              'template_id': emailJs['EMAILJS_TEMPLATE_ID'],
              'user_id': emailJs['EMAILJS_PUBLIC_KEY'],
              'accessToken': emailJs['EMAILJS_PRIVATE_KEY'],
              'template_params': {
                'email': email,
                'passcode': _generatedOtp,
                'time': formattedTime,
              },
            }),
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw Exception(
              'Request timed out. Check your internet connection.',
            ),
          );

      if (response.statusCode == 200) {
        setState(() {
          _isOtpSent = true;
          _isOtpVerified = false;
          _otpController.clear();
        });
        _showSnack('OTP sent to $email. Valid for 15 minutes.');
      } else {
        final details = response.statusCode == 412
            ? 'EmailJS Gmail account authorization is invalid. Reconnect Gmail in the EmailJS service dashboard.'
            : response.body;
        _showSnack(
          'Failed to send OTP (${response.statusCode}): $details',
          error: true,
        );
      }
    } on Exception catch (e) {
      _showSnack('Error: ${e.toString()}', error: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _verifyEmailOtp() async {
    final entered = _otpController.text.trim();
    if (entered.isEmpty) {
      _showSnack('Please enter the OTP.', error: true);
      return;
    }
    setState(() => _isUploading = true);
    try {
      if (_generatedOtp.isEmpty || _otpExpiresAt == null) {
        _showSnack('Please request a new OTP.', error: true);
        return;
      }
      if (_otpEmail != _emailController.text.trim()) {
        _showSnack('Email changed. Please request a new OTP.', error: true);
        return;
      }
      if (DateTime.now().isAfter(_otpExpiresAt!)) {
        _showSnack('OTP has expired.', error: true);
        setState(() {
          _isOtpSent = false;
          _generatedOtp = '';
          _otpExpiresAt = null;
          _otpEmail = '';
          _otpController.clear();
        });
        return;
      }
      if (entered != _generatedOtp) {
        _showSnack('Incorrect OTP.', error: true);
        return;
      }
      setState(() {
        _isOtpVerified = true;
        _generatedOtp = '';
        _otpExpiresAt = null;
        _otpEmail = '';
        _currentStep = 2;
      });
      _showSnack('Email verified successfully!');
    } catch (e) {
      _showSnack('Verification error: $e', error: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isOtpVerified) {
      _showSnack('Please verify your email first.', error: true);
      return;
    }
    if (_nicNumberController.text.trim().isEmpty) {
      _showSnack('Please enter your NIC number.', error: true);
      return;
    }
    if (_selectedBloodGroup == null) {
      _showSnack('Please select your blood group.', error: true);
      return;
    }
    setState(() => _isUploading = true);
    User? createdUser;
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final isAvailable = await _checkEmailAvailability(email);
      if (!isAvailable) {
        _showSnack(_emailError, error: true);
        return;
      }

      final UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      createdUser = cred.user;
      final userId = createdUser!.uid;

      _showSnack('Account created! Submitting application...');

      final Map<String, dynamic> userData = {
        'uid': userId,
        'full_name': _fullNameController.text.trim(),
        'email': email,
        'phone': _phoneController.text.trim(),
        'nicNumber': _nicNumberController.text.trim(),
        'bloodGroup': _selectedBloodGroup,
        'homeAddress': _homeAddressController.text.trim(),
        'emergencyContact1': _emergency1Controller.text.trim(),
        'emergencyContact2': _emergency2Controller.text.trim(),
        'role': 'user',
        'applicationStatus': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(userId).set(userData);
      await _firestore.collection('active_applications').doc(userId).set({
        ...userData,
        'applicationId': userId,
        'userID': userId,
        'submittedAt': FieldValue.serverTimestamp(),
        'reviewedBy': null,
        'reviewedAt': null,
        'adminComments': null,
      });

      await _auth.signOut();

      if (mounted) {
        _showSnack('✅ Application submitted! Please wait for admin approval.');
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Auth Error: ${e.code} - ${e.message}');
      String msg = 'An error occurred';
      if (e.code == 'email-already-in-use')
        msg = 'Email already registered. Try logging in.';
      if (e.code == 'weak-password') msg = 'Password is too weak.';
      if (e.code == 'invalid-email') msg = 'Invalid email address.';
      _showSnack(msg, error: true);
      if (createdUser != null)
        try {
          await createdUser.delete();
        } catch (_) {}
    } catch (e) {
      debugPrint('CRITICAL ERROR: $e');
      _showSnack('Registration Error: ${e.toString()}', error: true);
      if (createdUser != null)
        try {
          await createdUser.delete();
        } catch (_) {}
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _onStepContinue() {
    if (_currentStep == 0) {
      if (_formKey.currentState!.validate()) setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (!_isOtpVerified) {
        _showSnack('Please verify your email OTP first.', error: true);
      } else {
        setState(() => _currentStep = 2);
      }
    } else {
      _registerUser();
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.of(context).pop();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      _isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );

    return Scaffold(
      backgroundColor: cBg,
      body: Stack(
        children: [
          AnimatedContainer(
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
          ),
          SafeArea(
            child: _isUploading
                ? _buildLoader()
                : Column(
                    children: [
                      _buildTopBar(),
                      Expanded(
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            canvasColor: Colors.transparent,
                            colorScheme: ColorScheme.dark().copyWith(
                              primary: cAccent,
                              secondary: cAccent,
                            ),
                          ),
                          child: Stepper(
                            physics: const BouncingScrollPhysics(),
                            currentStep: _currentStep,
                            onStepContinue: _onStepContinue,
                            onStepCancel: _onStepCancel,
                            controlsBuilder: _buildStepControls,
                            stepIconBuilder: _buildStepIcon,
                            steps: [
                              Step(
                                title: Text(
                                  'Personal Info',
                                  style: TextStyle(
                                    color: cText,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                isActive: _currentStep >= 0,
                                state: _currentStep > 0
                                    ? StepState.complete
                                    : StepState.indexed,
                                content: _glassCard(
                                  child: _buildPersonalInfoForm(),
                                ),
                              ),
                              Step(
                                title: Text(
                                  'Email Verification',
                                  style: TextStyle(
                                    color: cText,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                isActive: _currentStep >= 1,
                                state: _currentStep > 1
                                    ? StepState.complete
                                    : StepState.indexed,
                                content: _glassCard(
                                  child: _buildEmailOtpForm(),
                                ),
                              ),
                              Step(
                                title: Text(
                                  'NIC Details',
                                  style: TextStyle(
                                    color: cText,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                isActive: _currentStep >= 2,
                                content: _glassCard(child: _buildNICForm()),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── Full-screen loader ─────────────────────────────────────────────────────
  Widget _buildLoader() {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: cCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDarkMode ? 0.5 : 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: cAccent),
            const SizedBox(height: 16),
            Text(
              'Processing...',
              style: TextStyle(
                color: cText,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar: back + title + dark mode toggle ───────────────────────────────
  Widget _buildTopBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cNavy1, cNavy2],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          _buildMiniLogo(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'User Registration',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'RESCUENOW · NEW ACCOUNT',
                  style: TextStyle(
                    color: Color(0x66FFFFFF),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
          _buildDarkModeToggle(),
        ],
      ),
    );
  }

  // ── Mini animated SOS logo for top bar ────────────────────────────────────
  Widget _buildMiniLogo() {
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _PulseRing(
            controller: _pulseCtrl,
            delay: 0.0,
            size: 36,
            color: const Color(0xFFE53E3E),
          ),
          _PulseRing(
            controller: _pulseCtrl,
            delay: 0.4,
            size: 36,
            color: const Color(0xFFE53E3E),
          ),
          SizedBox(
            width: 30,
            height: 30,
            child: Center(
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE53E3E), Color(0xFFC02828)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
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

  // ── Dark mode toggle ───────────────────────────────────────────────────────
  Widget _buildDarkModeToggle() {
    return GestureDetector(
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
                  color: _isDarkMode ? const Color(0xFF060E1F) : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Glass card ─────────────────────────────────────────────────────────────
  Widget _glassCard({required Widget child}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cBorder, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── Stepper controls ───────────────────────────────────────────────────────
  Widget _buildStepControls(BuildContext context, ControlsDetails details) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: details.onStepContinue,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F2550), cNavy3],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x590F2550),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _currentStep == 2 ? 'Submit Application' : 'Next Step',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_currentStep > 0) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: details.onStepCancel,
              style: TextButton.styleFrom(
                foregroundColor: cSub,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 20,
                ),
              ),
              child: const Text(
                'Back',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _buildStepIcon(int stepIndex, StepState stepState) {
    if (stepState == StepState.complete) {
      return Icon(Icons.check_circle, color: cAccent, size: 22);
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: stepState == StepState.indexed
            ? cAccent.withOpacity(0.15)
            : Colors.transparent,
        border: Border.all(
          color: stepState == StepState.indexed ? cAccent : cBorder,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          '${stepIndex + 1}',
          style: TextStyle(
            color: stepState == StepState.indexed ? cAccent : cHint,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 1 — Personal Info
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPersonalInfoForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('BASIC DETAILS'),
          const SizedBox(height: 12),
          _field(
            controller: _fullNameController,
            label: 'Full Name',
            icon: Icons.person_outline_rounded,
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(
                controller: _emailController,
                label: 'Email Address',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) =>
                    _checkEmailAvailability(_emailController.text.trim()),
                suffix: _isCheckingEmail
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cAccent,
                        ),
                      )
                    : (_isEmailAvailable &&
                          _emailController.text.isNotEmpty &&
                          _emailController.text.contains('@'))
                    ? const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 18,
                      )
                    : null,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Invalid email format';
                  if (!_isEmailAvailable && _emailError.isNotEmpty)
                    return _emailError;
                  return null;
                },
              ),
              if (_emailError.isNotEmpty && !_isEmailAvailable)
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: Text(
                    _emailError,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _field(
            controller: _phoneController,
            label: 'Phone Number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (v) =>
                (v == null || v.length < 10) ? 'Valid phone required' : null,
          ),
          const SizedBox(height: 20),

          _sectionLabel('HEALTH INFO'),
          const SizedBox(height: 12),
          _buildBloodGroupDropdown(),
          const SizedBox(height: 20),

          _sectionLabel('ADDRESS & EMERGENCY'),
          const SizedBox(height: 12),
          _field(
            controller: _homeAddressController,
            label: 'Home Address',
            icon: Icons.home_outlined,
            maxLines: 2,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Home address is required' : null,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _emergency1Controller,
            label: 'Emergency Contact 1 (Optional)',
            icon: Icons.emergency_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _emergency2Controller,
            label: 'Emergency Contact 2 (Optional)',
            icon: Icons.emergency_share_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),

          _sectionLabel('ACCOUNT SECURITY'),
          const SizedBox(height: 12),
          _field(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePassword,
            toggleObscure: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            validator: (v) => (v == null || v.length < 6)
                ? 'Minimum 6 characters required'
                : null,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscureConfirmPassword,
            toggleObscure: () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword,
            ),
            validator: (v) =>
                v != _passwordController.text ? 'Passwords do not match' : null,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: cLabel,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: cBorder, height: 1)),
      ],
    );
  }

  Widget _buildBloodGroupDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedBloodGroup,
      dropdownColor: cCardBg,
      style: TextStyle(color: cText, fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Blood Group',
        labelStyle: TextStyle(color: cLabel, fontSize: 13),
        prefixIcon: Icon(Icons.bloodtype_outlined, color: cSub, size: 18),
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
          borderSide: BorderSide(color: cAccent, width: 1.5),
        ),
        filled: true,
        fillColor: cInputBg,
      ),
      hint: Text(
        'Select Blood Group',
        style: TextStyle(color: cHint, fontSize: 13),
      ),
      items: _bloodGroups
          .map(
            (bg) => DropdownMenuItem(
              value: bg,
              child: Text(bg, style: TextStyle(color: cText)),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _selectedBloodGroup = v),
      validator: (v) => v == null ? 'Please select your blood group' : null,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 2 — Email OTP
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildEmailOtpForm() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cAccent.withOpacity(0.1),
            border: Border.all(color: cAccent.withOpacity(0.3), width: 2),
          ),
          child: Icon(
            Icons.mark_email_unread_outlined,
            size: 30,
            color: cAccent,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _emailController.text.isEmpty
              ? 'Enter your email in Step 1 first.'
              : 'We\'ll send a verification code to',
          style: TextStyle(color: cSub, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        if (_emailController.text.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _emailController.text.trim(),
            style: TextStyle(
              color: cText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),

        if (_isOtpVerified) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  color: Colors.greenAccent,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  'Email Verified!',
                  style: TextStyle(
                    color: cText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ] else if (!_isOtpSent) ...[
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _emailController.text.trim().isEmpty
                  ? null
                  : _sendEmailOtp,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F2550), cNavy3],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x590F2550),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Send OTP',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ] else ...[
          TextFormField(
            controller: _otpController,
            style: TextStyle(
              color: cText,
              letterSpacing: 10,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: 'Enter 6-digit OTP',
              labelStyle: TextStyle(
                color: cLabel,
                fontSize: 13,
                letterSpacing: 0,
              ),
              counterStyle: TextStyle(color: cHint, fontSize: 11),
              filled: true,
              fillColor: cInputBg,
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
                borderSide: BorderSide(color: cAccent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _verifyEmailOtp,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F2550), cNavy3],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x590F2550),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Verify OTP',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _sendEmailOtp,
            icon: Icon(Icons.refresh_rounded, color: cSub, size: 16),
            label: Text(
              'Resend OTP',
              style: TextStyle(color: cSub, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 3 — Manual NIC Entry
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildNICForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('NIC NUMBER'),
        const SizedBox(height: 12),
        TextFormField(
          controller: _nicNumberController,
          style: TextStyle(color: cText, fontSize: 14),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'CNIC Number',
            labelStyle: TextStyle(color: cLabel, fontSize: 13),
            hintText: '12345-1234567-1',
            hintStyle: TextStyle(color: cHint, fontSize: 13),
            prefixIcon: Icon(Icons.badge_outlined, color: cSub, size: 18),
            suffixIcon: _nicNumberController.text.isNotEmpty
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.greenAccent,
                    size: 18,
                  )
                : null,
            filled: true,
            fillColor: cInputBg,
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
              borderSide: BorderSide(color: cAccent, width: 1.5),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'NIC number required';
            final clean = v.replaceAll('-', '');
            if (clean.length != 13) return 'Valid 13-digit NIC required';
            return null;
          },
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SHARED FIELD WIDGET
  // ══════════════════════════════════════════════════════════════════════════

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool? obscure,
    VoidCallback? toggleObscure,
    String? Function(String?)? validator,
    Function(String)? onChanged,
    Widget? suffix,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: cLabel,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure ?? false,
          keyboardType: keyboardType,
          maxLines: obscure == true ? 1 : maxLines,
          style: TextStyle(fontSize: 14, color: cText),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: cHint, fontSize: 13),
            prefixIcon: Icon(icon, color: cSub, size: 18),
            suffixIcon:
                suffix ??
                (toggleObscure != null
                    ? GestureDetector(
                        onTap: toggleObscure,
                        child: Icon(
                          obscure!
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: cSub,
                          size: 18,
                        ),
                      )
                    : null),
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
              borderSide: BorderSide(color: cAccent, width: 1.5),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PULSE RING
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
