import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminRegisterScreen extends StatefulWidget {
  final String departmentType;
  const AdminRegisterScreen({super.key, required this.departmentType});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen> with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  
  final _field1Ctrl = TextEditingController();
  final _field2Ctrl = TextEditingController();
  final _field3Ctrl = TextEditingController();
  final _field4Ctrl = TextEditingController();

  bool _obscurePass = true;
  bool _isLoading = false;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _field1Ctrl.dispose();
    _field2Ctrl.dispose();
    _field3Ctrl.dispose();
    _field4Ctrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // THEME COLORS (Mirroring login.dart)
  // ══════════════════════════════════════════════════════════════════════════
  static const Color cRed = Color(0xFFE53E3E);
  static const Color cRedDark = Color(0xFFC02828);
  static const Color cNavy3 = Color(0xFF1A3A72);

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

  Future<void> _loadTheme() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => _isDarkMode = p.getBool('isDarkMode') ?? true);
  }

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

  Future<void> _registerAdmin() async {
    if (_emailCtrl.text.trim().isEmpty || 
        _passCtrl.text.trim().isEmpty ||
        _field1Ctrl.text.trim().isEmpty ||
        _field2Ctrl.text.trim().isEmpty ||
        _field3Ctrl.text.trim().isEmpty ||
        _field4Ctrl.text.trim().isEmpty) {
      _showSnack('Please fill all fields', error: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      final uid = cred.user!.uid;
      final expectedDept = widget.departmentType.toLowerCase();
      String normalizedExpected = expectedDept;
      if (expectedDept.contains('fire')) normalizedExpected = 'fire';
      if (expectedDept.contains('police')) normalizedExpected = 'police';
      if (expectedDept.contains('ambulance')) normalizedExpected = 'ambulance';

      final Map<String, dynamic> adminData = {
        'uid': uid,
        'email': _emailCtrl.text.trim(),
        'department_type': normalizedExpected,
        'created_at': FieldValue.serverTimestamp(),
      };

      if (normalizedExpected == 'police') {
        adminData['station_name'] = _field1Ctrl.text.trim();
        adminData['officer_id'] = _field2Ctrl.text.trim();
        adminData['city_zone'] = _field3Ctrl.text.trim();
        adminData['official_contact'] = _field4Ctrl.text.trim();
      } else if (normalizedExpected == 'fire') {
        adminData['fire_station_name'] = _field1Ctrl.text.trim();
        adminData['battalion_number'] = _field2Ctrl.text.trim();
        adminData['city'] = _field3Ctrl.text.trim();
        adminData['emergency_number'] = _field4Ctrl.text.trim();
      } else if (normalizedExpected == 'ambulance') {
        adminData['hospital_name'] = _field1Ctrl.text.trim();
        adminData['vehicle_number'] = _field2Ctrl.text.trim();
        adminData['zone'] = _field3Ctrl.text.trim();
        adminData['driver_contact'] = _field4Ctrl.text.trim();
      }

      await FirebaseFirestore.instance.collection('admins').doc(uid).set(adminData);

      _showSnack('Admin Registered Successfully!');
      if (mounted) Navigator.pop(context); // Go back to login
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      _isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );

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
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                  color: _isDarkMode ? const Color(0xFF1A3A72) : const Color(0xFFE2E8F0),
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
                          color: _isDarkMode ? Colors.tealAccent : const Color(0xFF0A2550),
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
            ),
          ),
          const SizedBox(height: 8),
          _buildAnimatedLogo(),
          const SizedBox(height: 12),
          Text(
            widget.departmentType,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'ADMIN REGISTRATION',
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

  Widget _buildAnimatedLogo() {
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _PulseRing(controller: _pulseCtrl, delay: 0.0, size: 80, color: cRed),
          _PulseRing(controller: _pulseCtrl, delay: 0.33, size: 80, color: cRed),
          _PulseRing(controller: _pulseCtrl, delay: 0.66, size: 80, color: cRed),
          SizedBox(
            width: 72,
            height: 72,
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
                    BoxShadow(color: Color(0x80C02828), blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      color: _isDarkMode ? dBg : const Color(0xFFEDF2FB),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      child: Column(
        children: [
          Transform.translate(
            offset: const Offset(0, -28),
            child: _buildRegisterCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterCard() {
    final lower = widget.departmentType.toLowerCase();
    String f1Label = '', f2Label = '', f3Label = '', f4Label = '';
    
    if (lower.contains('police')) {
      f1Label = 'Station Name';
      f2Label = 'Officer ID';
      f3Label = 'City/Zone';
      f4Label = 'Official Contact';
    } else if (lower.contains('ambulance')) {
      f1Label = 'Hospital Name';
      f2Label = 'Vehicle Number';
      f3Label = 'Zone';
      f4Label = 'Driver Contact';
    } else if (lower.contains('fire')) {
      f1Label = 'Fire Station Name';
      f2Label = 'Battalion Number';
      f3Label = 'City';
      f4Label = 'Emergency Number';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: cCardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cBorder, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? const Color(0x40000000) : const Color(0x14000000),
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
            'Create Account',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: cText),
          ),
          const SizedBox(height: 4),
          Text(
            'Set up a new admin for your department',
            style: TextStyle(fontSize: 12, color: cSub),
          ),
          const SizedBox(height: 22),
          
          _buildInputGroup(label: f1Label.toUpperCase(), controller: _field1Ctrl, icon: Icons.business, hint: 'Enter $f1Label'),
          const SizedBox(height: 14),
          _buildInputGroup(label: f2Label.toUpperCase(), controller: _field2Ctrl, icon: Icons.badge, hint: 'Enter $f2Label'),
          const SizedBox(height: 14),
          _buildInputGroup(label: f3Label.toUpperCase(), controller: _field3Ctrl, icon: Icons.location_city, hint: 'Enter $f3Label'),
          const SizedBox(height: 14),
          _buildInputGroup(label: f4Label.toUpperCase(), controller: _field4Ctrl, icon: Icons.phone, hint: 'Enter $f4Label'),
          const SizedBox(height: 14),
          
          _buildInputGroup(
            label: 'ADMIN EMAIL',
            controller: _emailCtrl,
            icon: Icons.email_outlined,
            hint: 'Enter your admin email',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _buildPasswordField(),
          const SizedBox(height: 20),
          _buildRegisterButton(),
        ],
      ),
    );
  }

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
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cLabel, letterSpacing: 0.4),
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
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: cBorder, width: 1.5)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: cBorder, width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: cNavy3, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PASSWORD',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cLabel, letterSpacing: 0.4),
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
              child: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: cSub, size: 18),
            ),
            filled: true,
            fillColor: cInputBg,
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: cBorder, width: 1.5)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: cBorder, width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: cNavy3, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _registerAdmin,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color(0xFF0F2550), cNavy3]),
          boxShadow: const [BoxShadow(color: Color(0x590F2550), blurRadius: 18, offset: Offset(0, 4))],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_add, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Register', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final double size;
  final Color color;

  const _PulseRing({required this.controller, required this.delay, required this.size, required this.color});

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
