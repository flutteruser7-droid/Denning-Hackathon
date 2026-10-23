// ignore_for_file: file_names

import 'dart:async';
import 'package:emergency_app/User/ConversationRoom.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  HOME PAGE  (Emergency Services Chat List)
// ══════════════════════════════════════════════════════════════════════════════
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // ── Auth ───────────────────────────────────────────────────────────────────
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Theme ──────────────────────────────────────────────────────────────────
  bool _isDarkMode = true;

  // ── Streams ────────────────────────────────────────────────────────────────
  final StreamController<List<Map<String, dynamic>>> _servicesController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  StreamSubscription? _emergencySub;
  List<Map<String, dynamic>> _emergencyList = [];

  // ════════════════════════════════════════════════════════════════════════════
  //  TOKENS  — 1 : 1 from UserDashboard
  // ════════════════════════════════════════════════════════════════════════════

  // dark
  static const _dBgPage = Color(0xFF04091A);
  static const _dBgBody = Color(0xFF0D1625);
  static const _dBgCard = Color(0xFF101C36);
  static const _dBgCardBdr = Color(0x12FFFFFF);
  static const _dHdrFrom = Color(0xFF071D3F);
  static const _dHdrTo = Color(0xFF0A2550);
  static const _dBgIco = Color(0x12FFFFFF);
  static const _dTxtPrimary = Color(0xFFF0F4FF);
  static const _dTxtSec = Color(0x80FFFFFF);
  static const _dTxtMuted = Color(0x47FFFFFF);
  static const _dDivider = Color(0x0DFFFFFF);

  // light
  static const _lBgPage = Color(0xFFE8EEF8);
  static const _lBgBody = Color(0xFFEDF2FB);
  static const _lBgCard = Color(0xFFFFFFFF);
  static const _lBgCardBdr = Color(0xFFD4E2F5);
  static const _lBgIco = Color(0xFFEEF2FB);
  static const _lTxtPrimary = Color(0xFF071830);
  static const _lTxtSec = Color(0xFF8FA2B5);
  static const _lTxtMuted = Color(0xFFA0B3C6);
  static const _lDivider = Color(0xFFEFF4FC);

  // shared accents
  static const _cGreen = Color(0xFF10B981);

  // ── Getters ────────────────────────────────────────────────────────────────
  Color get bgPage => _isDarkMode ? _dBgPage : _lBgPage;
  Color get bgBody => _isDarkMode ? _dBgBody : _lBgBody;
  Color get bgCard => _isDarkMode ? _dBgCard : _lBgCard;
  Color get bgCardBdr => _isDarkMode ? _dBgCardBdr : _lBgCardBdr;
  Color get bgIco => _isDarkMode ? _dBgIco : _lBgIco;
  Color get txtPrimary => _isDarkMode ? _dTxtPrimary : _lTxtPrimary;
  Color get txtSec => _isDarkMode ? _dTxtSec : _lTxtSec;
  Color get txtMuted => _isDarkMode ? _dTxtMuted : _lTxtMuted;
  Color get dividerClr => _isDarkMode ? _dDivider : _lDivider;

  // ════════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ════════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initStreams();
  }

  void _initStreams() {
    // 1) Fetch from EmergencyServices collection
    _emergencySub = FirebaseFirestore.instance
        .collection('EmergencyServices')
        .snapshots()
        .listen((snap) {
          _emergencyList = snap.docs
              .map((d) => d.data() as Map<String, dynamic>)
              .toList();
          _emitCombined();
        });
  }

  void _emitCombined() {
    final combined = [..._emergencyList];
    final existingTypes = combined
        .map((e) => (e['serviceType'] as String? ?? '').toLowerCase())
        .toSet();

    // Default fallback entries so they are ALWAYS available in the UI
    if (!existingTypes.contains('police')) {
      combined.add({
        'uid': 'default_police',
        'serviceType': 'Police',
        'stationName': 'Central Police Station',
        'status': 'active',
      });
    }
    if (!existingTypes.contains('ambulance')) {
      combined.add({
        'uid': 'default_ambulance',
        'serviceType': 'Ambulance',
        'stationName': 'City Hospital Ambulance',
        'status': 'active',
      });
    }
    if (!existingTypes.contains('fire brigade') &&
        !existingTypes.contains('fire')) {
      combined.add({
        'uid': 'default_fire',
        'serviceType': 'Fire Brigade',
        'stationName': 'Central Fire Brigade',
        'status': 'active',
      });
    }

    _servicesController.add(combined);
  }

  Future<void> _loadTheme() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => _isDarkMode = p.getBool('isDarkMode') ?? true);
  }

  @override
  void dispose() {
    _emergencySub?.cancel();
    _servicesController.close();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      color: bgPage,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                color: bgBody,
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _servicesController.stream,
                  builder: (context, snapshot) {
                    // Loading
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFE53E3E),
                          strokeWidth: 2.5,
                        ),
                      );
                    }
                    // Error
                    if (snapshot.hasError) {
                      return _buildEmpty(
                        icon: Icons.error_outline_rounded,
                        title: 'Something went wrong',
                        subtitle: 'Could not load services',
                      );
                    }
                    // Empty
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return _buildEmpty(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'No active services',
                        subtitle:
                            'No emergency services are available right now',
                      );
                    }

                    final docs = snapshot.data!;

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 18, 14, 36),
                      physics: const BouncingScrollPhysics(),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 11),
                      itemBuilder: (context, i) {
                        final data = docs[i];
                        final uid = data['uid'] as String? ?? 'unknown';
                        final stationName =
                            data['stationName'] as String? ?? '';
                        final serviceType =
                            data['serviceType'] as String? ?? '';

                        return _ServiceCard(
                          data: data,
                          isDarkMode: _isDarkMode,
                          bgCard: bgCard,
                          bgCardBdr: bgCardBdr,
                          bgIco: bgIco,
                          txtPrimary: txtPrimary,
                          txtSec: txtSec,
                          txtMuted: txtMuted,
                          dividerClr: dividerClr,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ConversationRoom(
                                userName: stationName.isNotEmpty
                                    ? stationName
                                    : serviceType,
                                userId: uid,
                                userImage: '',
                                receiverType:
                                    serviceType, // <-- NEW: Pass the service type here!
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  HEADER — same gradient / structure as UserDashboard
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_dHdrFrom, _dHdrTo],
        ),
        border: Border(
          bottom: BorderSide(color: Color(0x12FFFFFF), width: 0.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 14,
        20,
        22,
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.09),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.13)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 15,
              ),
            ),
          ),
          const SizedBox(width: 13),
          // Titles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chat with Services',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Active emergency responders',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.50),
                    fontSize: 11,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          // Live badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _cGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: _cGreen.withOpacity(0.28), width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _cGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Live',
                  style: TextStyle(
                    fontSize: 10,
                    color: _cGreen,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty / error state ────────────────────────────────────────────────────
  Widget _buildEmpty({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 46, color: txtMuted),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: txtSec,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: TextStyle(color: txtMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SERVICE CARD
// ══════════════════════════════════════════════════════════════════════════════
class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDarkMode;
  final Color bgCard, bgCardBdr, bgIco;
  final Color txtPrimary, txtSec, txtMuted, dividerClr;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.data,
    required this.isDarkMode,
    required this.bgCard,
    required this.bgCardBdr,
    required this.bgIco,
    required this.txtPrimary,
    required this.txtSec,
    required this.txtMuted,
    required this.dividerClr,
    required this.onTap,
  });

  // ── Shared accents ─────────────────────────────────────────────────────────
  static const _cRed = Color(0xFFE53E3E);
  static const _cOrange = Color(0xFFEA580C);
  static const _cBlue = Color(0xFF1D4ED8);
  static const _cGreen = Color(0xFF10B981);
  static const _cAmber = Color(0xFFF59E0B);

  // ── Data helpers ───────────────────────────────────────────────────────────
  String get _serviceType => (data['serviceType'] as String? ?? '').trim();
  String get _stationName => (data['stationName'] as String? ?? '').trim();
  String get _phone => (data['phone'] as String? ?? '').trim();
  String get _status => (data['status'] as String? ?? '').trim();
  String get _serviceId => (data['serviceId'] as String? ?? '').trim();
  String get _vehicleCount => (data['vehicleCount'] as String? ?? '0').trim();
  // ✅ NEW — cast via num first, then convert to int safely
  int get _totalRequests => (data['totalRequests'] as num? ?? 0).toInt();
  int get _rating => (data['rating'] as num? ?? 0).toInt();

  // ── Service type flags ─────────────────────────────────────────────────────
  bool get _isFire => _serviceType.toLowerCase() == 'fire brigade';
  bool get _isAmbulance => _serviceType.toLowerCase() == 'ambulance';
  bool get _isPolice => _serviceType.toLowerCase() == 'police';
  bool get _isKnown => _isFire || _isAmbulance || _isPolice;

  // ── Per-type theming ───────────────────────────────────────────────────────
  IconData get _serviceIcon {
    if (_isFire) return Icons.local_fire_department_rounded;
    if (_isAmbulance) return Icons.local_hospital_rounded;
    if (_isPolice) return Icons.shield_rounded;
    return Icons.miscellaneous_services_rounded;
  }

  Color get _serviceColor {
    if (_isFire) return _cOrange;
    if (_isAmbulance) return _cRed;
    if (_isPolice) return _cBlue;
    return _cAmber;
  }

  Color get _serviceBg => _serviceColor.withOpacity(0.12);
  Color get _serviceBdr => _serviceColor.withOpacity(0.28);

  bool get _isActive => _status.toLowerCase() == 'active';

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bgCardBdr, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 22,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: _serviceColor.withOpacity(0.06),
          highlightColor: _serviceColor.withOpacity(0.04),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── TOP ROW: avatar + name/type + chat CTA ────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Service avatar
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _serviceBg,
                        border: Border.all(color: _serviceBdr, width: 1.5),
                      ),
                      child: Icon(_serviceIcon, size: 26, color: _serviceColor),
                    ),
                    const SizedBox(width: 13),

                    // Name + type badge + status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _stationName.isNotEmpty
                                ? _stationName
                                : _serviceType,
                            style: TextStyle(
                              color: txtPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              // Service type pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _serviceBg,
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(
                                    color: _serviceBdr,
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  _serviceType,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: _serviceColor,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Status dot
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isActive ? _cGreen : _cAmber,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isActive ? 'Available' : 'Unavailable',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _isActive ? _cGreen : _cAmber,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Chat button
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _serviceBg,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: _serviceBdr, width: 0.5),
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 17,
                        color: _serviceColor,
                      ),
                    ),
                  ],
                ),

                // ── CONDITIONAL DETAIL SECTION (known types only) ─────────
                if (_isKnown) ...[
                  const SizedBox(height: 14),
                  Divider(height: 1, thickness: 0.5, color: dividerClr),
                  const SizedBox(height: 13),
                  _ServiceDetails(
                    isFire: _isFire,
                    isAmbulance: _isAmbulance,
                    isPolice: _isPolice,
                    phone: _phone,
                    serviceId: _serviceId,
                    vehicleCount: _vehicleCount,
                    totalRequests: _totalRequests,
                    rating: _rating,
                    serviceColor: _serviceColor,
                    bgIco: bgIco,
                    txtSec: txtSec,
                    txtMuted: txtMuted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SERVICE DETAILS  — conditional per service type
// ══════════════════════════════════════════════════════════════════════════════
class _ServiceDetails extends StatelessWidget {
  final bool isFire, isAmbulance, isPolice;
  final String phone, serviceId, vehicleCount;
  final int totalRequests, rating;
  final Color serviceColor, bgIco, txtSec, txtMuted;

  const _ServiceDetails({
    required this.isFire,
    required this.isAmbulance,
    required this.isPolice,
    required this.phone,
    required this.serviceId,
    required this.vehicleCount,
    required this.totalRequests,
    required this.rating,
    required this.serviceColor,
    required this.bgIco,
    required this.txtSec,
    required this.txtMuted,
  });

  static const _cGreen = Color(0xFF10B981);
  static const _cAmber = Color(0xFFF59E0B);
  static const _cOrange = Color(0xFFEA580C);
  static const _cRed = Color(0xFFE53E3E);
  static const _cBlue = Color(0xFF1D4ED8);
  static const _cPurple = Color(0xFF9B59B6);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // ── Phone — all service types ─────────────────────────────────────
        if (phone.isNotEmpty)
          _Chip(
            icon: Icons.phone_outlined,
            label: phone,
            color: serviceColor,
            bgIco: bgIco,
            txtSec: txtSec,
          ),

        // ── Fire Brigade specific ─────────────────────────────────────────
        if (isFire) ...[
          _Chip(
            icon: Icons.fire_truck_outlined,
            label: '$vehicleCount Trucks',
            color: _cOrange,
            bgIco: bgIco,
            txtSec: txtSec,
          ),
          _Chip(
            icon: Icons.local_fire_department_outlined,
            label: 'Fire Brigade',
            color: _cOrange,
            bgIco: bgIco,
            txtSec: txtSec,
          ),
        ],

        // ── Ambulance specific ────────────────────────────────────────────
        if (isAmbulance) ...[
          _Chip(
            icon: Icons.airport_shuttle_outlined,
            label: '$vehicleCount Vehicles',
            color: _cRed,
            bgIco: bgIco,
            txtSec: txtSec,
          ),
          _Chip(
            icon: Icons.medical_services_outlined,
            label: 'Medical Unit',
            color: _cRed,
            bgIco: bgIco,
            txtSec: txtSec,
          ),
        ],

        // ── Police specific ───────────────────────────────────────────────
        if (isPolice) ...[
          _Chip(
            icon: Icons.directions_car_outlined,
            label: '$vehicleCount Units',
            color: _cBlue,
            bgIco: bgIco,
            txtSec: txtSec,
          ),
          _Chip(
            icon: Icons.local_police_outlined,
            label: 'Law Enforcement',
            color: _cBlue,
            bgIco: bgIco,
            txtSec: txtSec,
          ),
        ],

        // ── Common: service ID ────────────────────────────────────────────
        if (serviceId.isNotEmpty)
          _Chip(
            icon: Icons.tag_rounded,
            label: serviceId,
            color: _cPurple,
            bgIco: bgIco,
            txtSec: txtSec,
          ),

        // ── Common: total requests handled ───────────────────────────────
        _Chip(
          icon: Icons.assignment_turned_in_outlined,
          label: '$totalRequests Handled',
          color: _cGreen,
          bgIco: bgIco,
          txtSec: txtSec,
        ),

        // ── Common: rating (only if > 0) ──────────────────────────────────
        if (rating > 0)
          _Chip(
            icon: Icons.star_outline_rounded,
            label: '$rating Rating',
            color: _cAmber,
            bgIco: bgIco,
            txtSec: txtSec,
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CHIP  — compact info pill
// ══════════════════════════════════════════════════════════════════════════════
class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bgIco, txtSec;

  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgIco,
    required this.txtSec,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgIco,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.20), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: txtSec,
            ),
          ),
        ],
      ),
    );
  }
}
