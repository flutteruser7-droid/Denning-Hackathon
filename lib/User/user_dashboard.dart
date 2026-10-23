import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emergency_app/User/Profile.dart';
import 'package:emergency_app/User/History.dart';
import 'package:emergency_app/User/ChatPage.dart';
import 'package:emergency_app/User/FirstAidChatPage.dart';
import 'package:emergency_app/User/EmergencyContacts.dart';
import 'package:emergency_app/theme/darkmode.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emergency_app/services/sos_sms_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  ENTRY
// ══════════════════════════════════════════════════════════════════════════════
class UserDashboard extends StatelessWidget {
  const UserDashboard({super.key});
  @override
  Widget build(BuildContext context) => const DashboardScreen();
}

// ══════════════════════════════════════════════════════════════════════════════
//  SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  // ── nav
  int _selectedNav = 0;

  // ── theme (managed globally — see lib/theme/darkmode.dart)

  // ── user
  String _userFullName = '';
  String _userInitials = '';
  String _userEmail = '';
  String? _activeRequestId;

  // ── location
  double? _lat;
  double? _lng;
  String _locationLabel = 'Locating…';
  String _locationArea = '';
  String _locationCity = '';
  String _locationDistrict = '';
  bool _locationLoading = false;

  // ── request
  String _requestStatus =
      ''; // '' | 'sent' | 'accepted' | 'on_the_way' | 'arrived' | 'rejected'
  StreamSubscription<DocumentSnapshot>? _reqSub;

  // ── hold-to-call
  Timer? _holdTimer;
  String? _holdingService;
  double _holdProgress = 0;

  // ── animations
  late AnimationController _pulseCtrl;
  late AnimationController _blinkCtrl;
  late Animation<double> _blinkAnim;
  late AnimationController _sosPressCtrl;
  late Animation<double> _sosPressAnim;

  // ════════════════════════════════════════════════════════════════════════════
  //  TOKENS  — 1:1 from HTML CSS variables
  // ════════════════════════════════════════════════════════════════════════════

  // ── dark palette
  static const _lHdrFrom = Color(0xFF1565C0); // or whatever light tone you want
  static const _lHdrTo = Color(0xFF1976D2);
  static const _dBgPage = Color(0xFF04091A);
  static const _dBgPhoneRim = Color(0xFF0B1528);
  static const _dHdrFrom = Color(0xFF071D3F);
  static const _dHdrTo = Color(0xFF0A2550);

  static const _dBgBody = Color(0xFF0D1625);
  static const _dBgCard = Color(0xFF101C36); // rgba(16,28,54,.85)
  static const _dBgCardBdr = Color(0x12FFFFFF); // rgba(255,255,255,0.07)
  static const _dBgActionIco = Color(0x12FFFFFF);
  static const _dBgNav = Color(0xF70A1226);
  static const _dNavActFrom = Color(0xFF1A3A72);
  static const _dNavActTo = Color(0xFF0F2550);
  static const _dMapFrom = Color(0xFF0E2040);
  static const _dMapTo = Color(0xFF142B52);
  static const _dMapBlk1 = Color(0xFF112239);
  static const _dMapBlk2 = Color(0xFF0E1E33);
  static const _dMapPark = Color(0xFF193D2E);
  static const _dMapParkDot = Color(0xFF1A5C3E);
  static const _dMapRoad = Color(0x1FFFFFFF); // rgba(255,255,255,.12)
  static const _dLocBar = Color(0xF20A1224);
  static const _dLocBdr = Color(0x14FFFFFF);
  static const _dSvcAmbBg = Color(0x14EF4444);
  static const _dSvcAmbBdr = Color(0x33EF4444);
  static const _dSvcPolBg = Color(0x141D4ED8);
  static const _dSvcPolBdr = Color(0x331D4ED8);
  static const _dSvcFireBg = Color(0x14F97316);
  static const _dSvcFireBdr = Color(0x33F97316);
  static const _dDotPending = Color(0xFF111E35);
  static const _dDotPenBdr = Color(0x1AFFFFFF);
  static const _dLinePending = Color(0x1AFFFFFF);
  static const _dTxtPrimary = Color(0xFFF0F4FF);
  static const _dTxtSec = Color(0x80FFFFFF);
  static const _dTxtMuted = Color(0x47FFFFFF);
  static const _dTxtNavIn = Color(0x4DFFFFFF);
  static const _dLocCity = Color(0xFFE0EAFF);
  static const _dActionDivider = Color(0x0DFFFFFF);
  static const _dActionLabel = Color(0xFFD0DDF5);
  static const _dActionArrow = Color(0x33FFFFFF);

  // ── light palette
  static const _lBgPage = Color(0xFFE8EEF8);
  static const _lBgBody = Color(0xFFEDF2FB);
  static const _lBgCard = Color(0xFFFFFFFF);
  static const _lBgCardBdr = Color(0xFFD4E2F5);
  static const _lBgActionIco = Color(0xFFEEF2FB);
  static const _lBgNav = Color(0xFFFFFFFF);
  static const _lMapFrom = Color(0xFFCFE0F0);
  static const _lMapTo = Color(0xFFD8EAF8);
  static const _lMapBlk1 = Color(0xFFC0D4E8);
  static const _lMapBlk2 = Color(0xFFB5CCE2);
  static const _lMapPark = Color(0xFFB8D9C5);
  static const _lMapParkDot = Color(0xFF96C9A2);
  static const _lMapRoad = Color(0x99FFFFFF);
  static const _lLocBar = Color(0xF7FFFFFF);
  static const _lLocBdr = Color(0x0F000000);
  static const _lSvcAmbBg = Color(0xFFFEF2F2);
  static const _lSvcAmbBdr = Color(0xFFFECACA);
  static const _lSvcPolBg = Color(0xFFEFF6FF);
  static const _lSvcPolBdr = Color(0xFFBFDBFE);
  static const _lSvcFireBg = Color(0xFFFFF7ED);
  static const _lSvcFireBdr = Color(0xFFFED7AA);
  static const _lDotPending = Color(0xFFEDF2FA);
  static const _lDotPenBdr = Color(0xFFCDDAEB);
  static const _lLinePending = Color(0xFFCDDAEB);
  static const _lTxtPrimary = Color(0xFF071830);
  static const _lTxtSec = Color(0xFF8FA2B5);
  static const _lTxtMuted = Color(0xFFA0B3C6);
  static const _lTxtNavIn = Color(0xFF9BA8B7);
  static const _lLocCity = Color(0xFF071830);
  static const _lActionDivider = Color(0xFFEFF4FC);
  static const _lActionLabel = Color(0xFF071830);
  static const _lActionArrow = Color(0xFFAABDCE);

  // ── shared
  static const _cRed = Color(0xFFE53E3E);
  static const _cRedDark = Color(0xFFC02828);
  static const _cGreen = Color(0xFF10B981);

  // ── getters (reads from the global ThemeNotifier via context extension)
  bool get _isDarkMode => context.isDarkMode;

  Color get bgPage => _isDarkMode ? _dBgPage : _lBgPage;
  Color get bgBody => _isDarkMode ? _dBgBody : _lBgBody;
  Color get bgCard => _isDarkMode ? _dBgCard : _lBgCard;
  Color get bgCardBdr => _isDarkMode ? _dBgCardBdr : _lBgCardBdr;
  Color get bgActionIco => _isDarkMode ? _dBgActionIco : _lBgActionIco;
  Color get bgNav => _isDarkMode ? _dBgNav : _lBgNav;
  Color get mapFrom => _isDarkMode ? _dMapFrom : _lMapFrom;
  Color get mapTo => _isDarkMode ? _dMapTo : _lMapTo;
  Color get mapBlk1 => _isDarkMode ? _dMapBlk1 : _lMapBlk1;
  Color get mapBlk2 => _isDarkMode ? _dMapBlk2 : _lMapBlk2;
  Color get mapPark => _isDarkMode ? _dMapPark : _lMapPark;
  Color get mapParkDot => _isDarkMode ? _dMapParkDot : _lMapParkDot;
  Color get mapRoad => _isDarkMode ? _dMapRoad : _lMapRoad;
  Color get locBar => _isDarkMode ? _dLocBar : _lLocBar;
  Color get locBdr => _isDarkMode ? _dLocBdr : _lLocBdr;
  Color get svcAmbBg => _isDarkMode ? _dSvcAmbBg : _lSvcAmbBg;
  Color get svcAmbBdr => _isDarkMode ? _dSvcAmbBdr : _lSvcAmbBdr;
  Color get svcPolBg => _isDarkMode ? _dSvcPolBg : _lSvcPolBg;
  Color get svcPolBdr => _isDarkMode ? _dSvcPolBdr : _lSvcPolBdr;
  Color get svcFireBg => _isDarkMode ? _dSvcFireBg : _lSvcFireBg;
  Color get svcFireBdr => _isDarkMode ? _dSvcFireBdr : _lSvcFireBdr;
  Color get dotPending => _isDarkMode ? _dDotPending : _lDotPending;
  Color get dotPenBdr => _isDarkMode ? _dDotPenBdr : _lDotPenBdr;
  Color get linePending => _isDarkMode ? _dLinePending : _lLinePending;
  Color get txtPrimary => _isDarkMode ? _dTxtPrimary : _lTxtPrimary;
  Color get txtSec => _isDarkMode ? _dTxtSec : _lTxtSec;
  Color get txtMuted => _isDarkMode ? _dTxtMuted : _lTxtMuted;
  Color get txtNavIn => _isDarkMode ? _dTxtNavIn : _lTxtNavIn;
  Color get locCity => _isDarkMode ? _dLocCity : _lLocCity;
  Color get actionDivider => _isDarkMode ? _dActionDivider : _lActionDivider;
  Color get actionLabel => _isDarkMode ? _dActionLabel : _lActionLabel;
  Color get actionArrow => _isDarkMode ? _dActionArrow : _lActionArrow;

  // ════════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ════════════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadUserInfo();
    _fetchLocation();

    // Initialize SOS Service
    SosSmsService().init();
    SosSmsService().onSosTriggered = (svc) {
      if (mounted) _toast('SOS Triggered: $svc! Sending SMS...');
    };
    SosSmsService().onSmsSent = (svc, num) {
      if (mounted) _toast('SOS SMS sent to $svc ($num)');
    };
    SosSmsService().onSmsError = (err) {
      if (mounted) _toast(err);
    };

    // 👇 Add this — triggers setState whenever theme changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.themeNotifier.addListener(_onThemeChange);
    });
  }

  void _onThemeChange() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    // Called whenever the inherited ThemeNotifier changes — guarantees rebuild
    super.didChangeDependencies();
    setState(() {});
  }

  void _initAnimations() {
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _blinkAnim = Tween<double>(
      begin: 1.0,
      end: 0.4,
    ).animate(CurvedAnimation(parent: _blinkCtrl, curve: Curves.easeInOut));

    _sosPressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _sosPressAnim = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _sosPressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    context.themeNotifier.removeListener(_onThemeChange);
    SosSmsService().dispose();
    _pulseCtrl.dispose();
    _blinkCtrl.dispose();
    _sosPressCtrl.dispose();
    _holdTimer?.cancel();
    _reqSub?.cancel();
    super.dispose();
  }

  // Theme is now handled globally via ThemeNotifier (lib/theme/darkmode.dart).
  // Call context.themeNotifier.toggle() from any widget to toggle the theme.

  // ════════════════════════════════════════════════════════════════════════════
  //  USER INFO
  // ════════════════════════════════════════════════════════════════════════════
  Future<void> _loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      // Support both snake_case and camelCase field names used across the app
      final name =
          data?['full_name'] as String? ??
          data?['fullName'] as String? ??
          data?['name'] as String? ??
          user.displayName ??
          '';
      final email = data?['email'] as String? ?? user.email ?? '';
      _applyUserName(name, email);
    } catch (_) {
      _applyUserName(user.displayName ?? '', user.email ?? '');
    }
    _listenToActiveRequest(user.uid);
  }

  void _applyUserName(String name, String email) {
    final initials = name.trim().isEmpty
        ? '?'
        : name
              .trim()
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .take(2)
              .map((w) => w[0].toUpperCase())
              .join();
    if (mounted) {
      setState(() {
        _userFullName = name.isEmpty ? 'User' : name;
        _userInitials = initials;
        _userEmail = email;
      });
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  String get _firstName => _userFullName.split(' ').first;

  // ════════════════════════════════════════════════════════════════════════════
  //  LOCATION
  // ════════════════════════════════════════════════════════════════════════════
  Future<void> _fetchLocation() async {
    if (_locationLoading) return;
    setState(() => _locationLoading = true);
    try {
      bool svcEnabled = await Geolocator.isLocationServiceEnabled();
      if (!svcEnabled) {
        if (mounted)
          setState(() {
            _locationLabel = 'GPS disabled';
            _locationLoading = false;
          });
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted)
          setState(() {
            _locationLabel = perm == LocationPermission.deniedForever
                ? 'Permission denied'
                : 'Location permission required';
            _locationLoading = false;
          });
        return;
      }
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) {
        if (mounted)
          setState(() {
            _locationLabel = 'Location unavailable';
            _locationLoading = false;
          });
        return;
      }
      // Phase 1: set coordinates immediately so spinner stops
      if (mounted) {
        setState(() {
          _lat = pos!.latitude;
          _lng = pos.longitude;
          _locationLabel =
              '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
          _locationLoading = false;
        });
      }
      // Phase 2: reverse-geocode in background
      _reverseGeocode(pos.latitude, pos.longitude);
    } catch (e) {
      debugPrint('[Loc] _fetchLocation error: $e');
      if (mounted)
        setState(() {
          _locationLabel = 'Location unavailable';
          _locationLoading = false;
        });
    }
  }

  /// Reverse-geocodes using OpenStreetMap Nominatim -- no API key, works globally.
  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lng&zoom=14&addressdetails=1',
      );
      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent': 'EmergencyApp/1.0 (contact@emergency-app.local)',
              'Accept-Language': 'en',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('[Loc] Nominatim HTTP ${response.statusCode}');
        return;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final addr = data['address'] as Map<String, dynamic>? ?? {};

      debugPrint('[Loc] Nominatim address: $addr');

      // Area: suburb -> neighbourhood -> village -> town -> city_district
      String area =
          addr['suburb'] as String? ??
          addr['neighbourhood'] as String? ??
          addr['village'] as String? ??
          addr['city_district'] as String? ??
          addr['town'] as String? ??
          '';

      // City: city -> town -> county -> state_district
      String city =
          addr['city'] as String? ??
          addr['town'] as String? ??
          addr['county'] as String? ??
          addr['state_district'] as String? ??
          addr['state'] as String? ??
          '';

      // District: county -> state_district -> state
      String district =
          addr['county'] as String? ??
          addr['state_district'] as String? ??
          addr['state'] as String? ??
          city;

      final parts = <String>[];
      if (area.isNotEmpty) parts.add(area);
      if (city.isNotEmpty && city != area) parts.add(city);
      final label = parts.isNotEmpty ? parts.join(', ') : '$lat, $lng';

      debugPrint('[Loc] label resolved: $label  (area=$area city=$city)');

      if (mounted)
        setState(() {
          _locationArea = area;
          _locationCity = city;
          _locationDistrict = district;
          _locationLabel = label;
        });
    } catch (e) {
      debugPrint('[Loc] geocoding failed: $e');
      // Coordinates are already showing -- non-fatal
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  FIRESTORE – CREATE REQUEST
  // ════════════════════════════════════════════════════════════════════════════
  // ── Map service button labels to Firestore serviceType values ──
  String _normalizeServiceType(String svc) {
    switch (svc.toLowerCase()) {
      case 'ambulance':
        return 'Ambulance';
      case 'police':
        return 'Police';
      case 'fire':
        return 'Fire Brigade';
      default:
        return svc;
    }
  }

  Future<void> _createRequest(String serviceType) async {
    // Refresh location before creating request
    if (_lat == null) await _fetchLocation();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Determine the Firestore serviceType label
    final fsServiceType = serviceType == 'SOS'
        ? 'SOS'
        : _normalizeServiceType(serviceType);

    // ── Smart city targeting ──
    // 1. Find services of the same type in the user's city.
    // 2. If none found, fall back to all services of that type.
    String? targetServiceUid;
    String? targetCity;
    try {
      if (fsServiceType != 'SOS' && _locationCity.isNotEmpty) {
        final citySnap = await FirebaseFirestore.instance
            .collection('EmergencyServices')
            .where('serviceType', isEqualTo: fsServiceType)
            .where('city', isEqualTo: _locationCity)
            .where('status', isEqualTo: 'active')
            .limit(1)
            .get();
        if (citySnap.docs.isNotEmpty) {
          targetServiceUid = citySnap.docs.first.id;
          targetCity = _locationCity;
        }
      }
      // If SOS or no city match found, we leave targetServiceUid null
      // (the request is visible to all services of that type via their query)
    } catch (_) {} // targeting is best-effort

    try {
      String targetLabel = fsServiceType.toLowerCase();
      if (targetLabel.contains('police'))
        targetLabel = 'police';
      else if (targetLabel.contains('fire'))
        targetLabel = 'fire';
      else if (targetLabel.contains('ambulance'))
        targetLabel = 'ambulance';
      else
        targetLabel = 'all';

      final ref = FirebaseFirestore.instance.collection('requests').doc();
      await ref.set({
        'requestId': ref.id,
        'userId': user.uid,
        'userEmail': _userEmail,
        'userFullName': _userFullName,
        'serviceType': fsServiceType,
        'alert_target': targetLabel,
        'status': 'sent',
        'location': {
          'latitude': _lat,
          'longitude': _lng,
          'address': _locationLabel,
          'area': _locationArea,
          'city': _locationCity,
          'district': _locationDistrict,
        },
        // City-targeting fields so service dashboards can filter by their city
        'targetCity': targetCity ?? _locationCity,
        if (targetServiceUid != null) 'assignedServiceId': targetServiceUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      setState(() {
        _activeRequestId = ref.id;
        _requestStatus = 'sent';
      });
      _subscribeToRequest(ref.id);
      HapticFeedback.heavyImpact();
      final targetMsg = targetCity != null
          ? '$serviceType request sent to $targetCity responders!'
          : '$serviceType request sent to all available responders!';
      _toast(targetMsg);
    } catch (_) {
      _toast('Failed to send request. Try again.');
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  FIRESTORE – LISTEN
  // ════════════════════════════════════════════════════════════════════════════
  void _listenToActiveRequest(String uid) {
    if (_activeRequestId != null) {
      _subscribeToRequest(_activeRequestId!);
      return;
    }
    FirebaseFirestore.instance
        .collection('requests')
        .where('userId', isEqualTo: uid)
        .where('status', whereNotIn: ['arrived', 'rejected'])
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get()
        .then((snap) {
          if (snap.docs.isNotEmpty) _subscribeToRequest(snap.docs.first.id);
        });
  }

  void _subscribeToRequest(String id) {
    _reqSub?.cancel();
    _activeRequestId = id;
    _reqSub = FirebaseFirestore.instance
        .collection('requests')
        .doc(id)
        .snapshots()
        .listen((snap) {
          if (!snap.exists) return;
          final s = snap.data()?['status'] as String? ?? '';
          if (mounted) setState(() => _requestStatus = s);
        });
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  HOLD-TO-CALL
  // ════════════════════════════════════════════════════════════════════════════
  void _holdStart(String svc) {
    if (_holdingService != null) return;
    _fetchLocation();
    setState(() {
      _holdingService = svc;
      _holdProgress = 0;
    });
    int elapsed = 0;
    const total = 1500, tick = 30;
    _holdTimer = Timer.periodic(const Duration(milliseconds: tick), (t) {
      elapsed += tick;
      if (mounted)
        setState(() => _holdProgress = (elapsed / total).clamp(0, 1));
      if (elapsed >= total) {
        t.cancel();
        _holdComplete(svc);
      }
    });
  }

  void _holdEnd() {
    _holdTimer?.cancel();
    if (mounted)
      setState(() {
        _holdingService = null;
        _holdProgress = 0;
      });
  }

  void _holdComplete(String svc) {
    setState(() {
      _holdingService = null;
      _holdProgress = 0;
    });
    _createRequest(svc);
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  HELPER
  // ════════════════════════════════════════════════════════════════════════════
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _isDarkMode ? _dHdrTo : _dHdrFrom,
      ),
    );
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
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: _selectedNav == 0
              ? FloatingActionButton(
                  heroTag: 'firstAidAssistant',
                  tooltip: 'Open first-aid assistant',
                  backgroundColor: const Color(0xFFE53E3E),
                  foregroundColor: Colors.white,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FirstAidChatPage()),
                  ),
                  child: const Icon(Icons.medical_services_rounded),
                )
              : null,
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          body: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: IndexedStack(
                  index: _selectedNav,
                  children: [
                    // ── 0: Home ──
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      color: bgBody,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(13, 13, 13, 8),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            _buildSOSServiceCard(),
                            const SizedBox(height: 11),
                            _buildMapCard(),
                            if (_requestStatus.isNotEmpty) ...[
                              const SizedBox(height: 11),
                              _buildStatusCard(),
                            ],
                            const SizedBox(height: 11),
                            _buildActionsCard(),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                    // ── 1: History ──
                    const HistoryTrackingPage(),
                    // ── 2: Profile ──
                    const ProfilePage(),
                  ],
                ),
              ),
              _buildBottomNav(),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  HEADER  (matches HTML exactly: status bar + greeting row)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _isDarkMode ? _dHdrFrom : _lHdrFrom,
            _isDarkMode ? _dHdrTo : _lHdrTo,
          ],
        ),
        border: const Border(
          bottom: BorderSide(color: Color(0x12FFFFFF), width: 0.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 10,
        20,
        20,
      ),
      child: Column(
        children: [
          // Status bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _timeString(),
                style: const TextStyle(
                  color: Color(0x73FFFFFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: const [
                  Icon(
                    Icons.signal_cellular_alt,
                    color: Color(0x80FFFFFF),
                    size: 13,
                  ),
                  SizedBox(width: 5),
                  Icon(Icons.wifi, color: Color(0x80FFFFFF), size: 13),
                  SizedBox(width: 5),
                  Icon(Icons.battery_3_bar, color: Color(0x80FFFFFF), size: 14),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          // Greeting row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting,
                    style: const TextStyle(
                      color: Color(0x66FFFFFF),
                      fontSize: 11,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        _firstName.isEmpty ? 'User' : _firstName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text('👋', style: TextStyle(fontSize: 20)),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  // theme toggle – pill style from HTML
                  GestureDetector(
                    onTap: () => context.themeNotifier.toggle(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isDarkMode
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                            color: Colors.white.withOpacity(0.7),
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isDarkMode ? 'DARK' : 'LIGHT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.7),
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // toggle track
                          Container(
                            width: 32,
                            height: 17,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                              ),
                            ),
                            child: Stack(
                              children: [
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  left: _isDarkMode ? 2 : 16,
                                  top: 2.5,
                                  child: Container(
                                    width: 11,
                                    height: 11,
                                    decoration: const BoxDecoration(
                                      color: Color(0xE6FFFFFF),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // bell
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        color: Colors.white.withOpacity(0.65),
                        size: 22,
                      ),
                      Positioned(
                        top: -1,
                        right: -1,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            border: Border.all(color: _dHdrFrom, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // avatar
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A3A72), Color(0xFF0F2550)],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _userInitials.isEmpty ? '?' : _userInitials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _timeString() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  SOS + SERVICE CARD  (card comes FIRST like the HTML layout)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildSOSServiceCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: bgCardBdr, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Subtle red glow in top-right corner (::before from HTML)
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFEF4444).withOpacity(0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 15),
              child: Column(
                children: [
                  // SOS button
                  _buildSOSButton(),
                  const SizedBox(height: 8),
                  Text(
                    'Hold button to call emergency service',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: txtMuted,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 13),
                  // Service buttons row
                  Row(
                    children: [
                      _buildServiceBtn(
                        svc: 'ambulance',
                        icon: Icons.local_hospital_rounded,
                        label: 'Ambulance',
                        color: const Color(0xFFDC2626),
                        bg: svcAmbBg,
                        bdr: svcAmbBdr,
                      ),
                      const SizedBox(width: 9),
                      _buildServiceBtn(
                        svc: 'police',
                        icon: Icons.shield_outlined,
                        label: 'Police',
                        color: const Color(0xFF1D4ED8),
                        bg: svcPolBg,
                        bdr: svcPolBdr,
                      ),
                      const SizedBox(width: 9),
                      _buildServiceBtn(
                        svc: 'fire',
                        icon: Icons.local_fire_department_rounded,
                        label: 'Fire',
                        color: const Color(0xFFEA580C),
                        bg: svcFireBg,
                        bdr: svcFireBdr,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSOSButton() {
    return GestureDetector(
      onTapDown: (_) => _sosPressCtrl.forward(),
      onTapUp: (_) => _sosPressCtrl.reverse(),
      onTapCancel: () => _sosPressCtrl.reverse(),
      onLongPress: () {
        HapticFeedback.heavyImpact();
        _createRequest('SOS');
      },
      child: AnimatedBuilder(
        animation: _sosPressAnim,
        builder: (_, child) =>
            Transform.scale(scale: _sosPressAnim.value, child: child),
        child: SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _PulseRing(ctrl: _pulseCtrl, delay: 0.0),
              _PulseRing(ctrl: _pulseCtrl, delay: 0.87 / 2.6),
              _PulseRing(ctrl: _pulseCtrl, delay: 1.73 / 2.6),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE8383F), _cRedDark],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _cRedDark.withOpacity(0.55),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: _cRedDark.withOpacity(0.07),
                      blurRadius: 0,
                      spreadRadius: 6,
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.2),
                      blurRadius: 0,
                      offset: const Offset(0, 1),
                      spreadRadius: -1,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceBtn({
    required String svc,
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
    required Color bdr,
  }) {
    final isHolding = _holdingService == svc;

    return Expanded(
      child: GestureDetector(
        onLongPressStart: (_) => _holdStart(svc),
        onLongPressEnd: (_) => _holdEnd(),
        onLongPressCancel: () => _holdEnd(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHolding ? color.withOpacity(0.6) : bdr,
              width: isHolding ? 1.5 : 0.5,
            ),
            boxShadow: isHolding
                ? [BoxShadow(color: color.withOpacity(0.22), blurRadius: 12)]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 5),
              // progress bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                height: isHolding ? 3 : 0,
                child: isHolding
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: _holdProgress,
                          backgroundColor: bdr,
                          valueColor: AlwaysStoppedAnimation(color),
                          minHeight: 3,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 3),
              Text(
                isHolding ? 'Calling…' : 'Hold to call',
                style: TextStyle(
                  fontSize: 8.5,
                  color: isHolding ? color : color.withOpacity(0.45),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  MAP CARD
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildMapCard() {
    return GestureDetector(
      onTap: _fetchLocation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        height: 168,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-0.5, -0.5),
            end: const Alignment(0.5, 0.5),
            colors: [mapFrom, mapTo],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: bgCardBdr, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Map blocks
            _mapBlock(left: .03, top: .04, w: .24, h: .24, color: mapBlk1),
            _mapBlock(left: .03, top: .34, w: .24, h: .26, color: mapBlk2),
            _mapBlock(left: .03, top: .66, w: .24, h: .28, color: mapBlk1),
            _mapBlock(left: .29, top: .04, w: .36, h: .24, color: mapBlk2),
            _mapBlock(
              left: .29,
              top: .34,
              w: .36,
              h: .26,
              color: mapPark,
              radius: 6,
            ),
            _mapBlock(
              left: .40,
              top: .41,
              w: .14,
              h: .14,
              color: mapParkDot,
              radius: 100,
            ),
            _mapBlock(left: .29, top: .66, w: .36, h: .28, color: mapBlk2),
            _mapBlock(left: .67, top: .04, w: .28, h: .24, color: mapBlk1),
            _mapBlock(left: .67, top: .34, w: .28, h: .26, color: mapBlk2),
            _mapBlock(left: .67, top: .66, w: .28, h: .28, color: mapBlk1),
            // Roads
            Positioned(
              left: 0,
              right: 0,
              top: 168 * .32,
              child: Container(height: 2, color: mapRoad),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 168 * .64,
              child: Container(height: 2, color: mapRoad),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              left: MediaQuery.of(context).size.width * .27 - 13,
              child: Container(width: 2, color: mapRoad),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              left: MediaQuery.of(context).size.width * .65 - 13,
              child: Container(width: 2, color: mapRoad),
            ),
            // You-here dot
            const Positioned(
              top: 168 * .4,
              left: 168, // rough centre on 344px wide card
              child: _YouHereDot(),
            ),
            // Location bar
            Positioned(
              bottom: 9,
              left: 9,
              right: 9,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: locBar,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: locBdr, width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFFEF4444),
                          size: 17,
                        ),
                        const SizedBox(width: 9),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your live location  (tap to refresh)',
                              style: TextStyle(
                                fontSize: 9,
                                color: txtSec,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 1),
                            _locationLoading
                                ? SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: locCity,
                                    ),
                                  )
                                : Text(
                                    _locationLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: locCity,
                                    ),
                                  ),
                          ],
                        ),
                      ],
                    ),
                    // Live badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.25),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          FadeTransition(
                            opacity: _blinkAnim,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: _cGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 10,
                              color: _cGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapBlock({
    required double left,
    required double top,
    required double w,
    required double h,
    required Color color,
    double radius = 4,
  }) {
    return LayoutBuilder(
      builder: (_, cns) {
        return Positioned(
          left: cns.maxWidth > 0 ? cns.maxWidth * left : 0,
          top: 168 * top,
          width: cns.maxWidth > 0 ? cns.maxWidth * w : 0,
          height: 168 * h,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  STATUS CARD
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildStatusCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: bgCardBdr, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'REQUEST STATUS',
                style: TextStyle(
                  fontSize: 10,
                  color: txtSec,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              if (_requestStatus == 'rejected')
                _statusBadge('Rejected', const Color(0xFFDC2626))
              else if (_requestStatus == 'arrived')
                _statusBadge('Arrived ✓', _cGreen),
            ],
          ),
          const SizedBox(height: 15),
          _buildTracker(),
        ],
      ),
    );
  }

  Widget _statusBadge(String label, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: c.withOpacity(0.12),
      borderRadius: BorderRadius.circular(100),
      border: Border.all(color: c.withOpacity(0.35)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 9, color: c, fontWeight: FontWeight.w700),
    ),
  );

  Widget _buildTracker() {
    final order = ['sent', 'accepted', 'on_the_way', 'arrived'];
    int cur = order.indexOf(_requestStatus);

    _TS stateAt(int i) {
      if (_requestStatus == 'rejected')
        return i == 0 ? _TS.rejected : _TS.pending;
      if (cur < 0) return _TS.pending;
      if (i < cur) return _TS.done;
      if (i == cur) return _TS.active;
      return _TS.pending;
    }

    final steps = [
      _Step('Request\nsent', Icons.check, 'sent'),
      _Step('Service\naccepted', Icons.check, 'accepted'),
      _Step('Help on\nthe way', Icons.local_hospital_rounded, 'on_the_way'),
      _Step('Arrived', Icons.flag_outlined, 'arrived'),
    ];

    return Row(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _stepDot(steps[i], stateAt(i)),
          if (i < steps.length - 1) _stepLine(stateAt(i), stateAt(i + 1)),
        ],
      ],
    );
  }

  Widget _stepDot(_Step step, _TS state) {
    Color bg;
    Color ic;
    switch (state) {
      case _TS.done:
        bg = _cGreen;
        ic = Colors.white;
        break;
      case _TS.active:
        bg = const Color(0xFF0F2550);
        ic = Colors.white;
        break;
      case _TS.rejected:
        bg = const Color(0xFFDC2626);
        ic = Colors.white;
        break;
      case _TS.pending:
        bg = dotPending;
        ic = dotPenBdr;
    }
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: state == _TS.pending
                ? Border.all(color: dotPenBdr, width: 1.5)
                : null,
            boxShadow: state == _TS.done
                ? [
                    BoxShadow(
                      color: _cGreen.withOpacity(0.15),
                      blurRadius: 0,
                      spreadRadius: 4,
                    ),
                  ]
                : state == _TS.active
                ? [
                    BoxShadow(
                      color: const Color(0xFF0A2864).withOpacity(0.45),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            state == _TS.rejected ? Icons.close : step.icon,
            size: 12,
            color: ic,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          step.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            height: 1.4,
            fontWeight: state == _TS.active ? FontWeight.w700 : FontWeight.w500,
            color:
                state == _TS.pending ||
                    state == _TS.rejected && step.key != 'sent'
                ? txtMuted
                : (state == _TS.active ? txtPrimary : txtSec),
          ),
        ),
      ],
    );
  }

  Widget _stepLine(_TS from, _TS to) {
    final bool fromDone = from == _TS.done;
    final bool toDone = to == _TS.done;
    final bool toActive = to == _TS.active;
    final bool dashed = fromDone && toActive;

    return Expanded(
      child: Container(
        height: 0,
        margin: const EdgeInsets.only(bottom: 22),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: fromDone ? _cGreen : linePending,
              width: 2,
              style: dashed
                  ? BorderStyle.solid
                  : BorderStyle
                        .solid, // Flutter doesn't natively do dashed; use solid
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  QUICK ACTIONS CARD
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildActionsCard() {
    final items = [
      _Action(
        Icons.group_outlined,
        'Emergency contacts',
        const Color(0xFF3B7DE8),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmergencyContactsPage()),
        ),
      ),
      _Action(
        Icons.settings_accessibility,
        'Enable Background SOS',
        const Color(0xFF8B5CF6),
        onTap: () {
          SosSmsService().openAccessibilitySettings();
          _toast(
            'Enable Accessibility for Emergency App.\nNote (Android 13+): If greyed out, go to Phone Settings > Apps > Emergency App > Top Right Dots > Allow Restricted Settings.',
          );
        },
      ),
      _Action(
        Icons.chat_bubble_outline,
        'Chat with admin',
        const Color(0xFF10B981),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatPage()),
        ),
      ),
    ];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: bgCardBdr, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++)
            _actionRow(items[i], isLast: i == items.length - 1),
        ],
      ),
    );
  }

  Widget _actionRow(_Action item, {required bool isLast}) {
    return InkWell(
      onTap: item.onTap ?? () {},
      splashColor: Colors.transparent,
      highlightColor: _isDarkMode
          ? Colors.white.withOpacity(0.04)
          : const Color(0xFFF8FAFF),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: actionDivider, width: 0.5)),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgActionIco,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, size: 17, color: item.color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: actionLabel,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 15, color: actionArrow),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  BOTTOM NAV
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildBottomNav() {
    final items = [
      _Nav(Icons.home_rounded, 'Home'),
      // _Nav(Icons.map_outlined,         'Map'),
      _Nav(Icons.access_time_rounded, 'History'),
      _Nav(Icons.person_outline, 'Profile'),
    ];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        color: bgNav,
        border: Border(top: BorderSide(color: bgCardBdr, width: 0.5)),
      ),
      padding: EdgeInsets.fromLTRB(
        8,
        10,
        8,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final active = _selectedNav == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedNav = i),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (active)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A3A72), Color(0xFF0F2550)],
                      ),
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0A2864).withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(items[i].icon, size: 17, color: Colors.white),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(items[i].icon, size: 18, color: txtNavIn),
                  ),
                const SizedBox(height: 3),
                Text(
                  items[i].label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? txtPrimary : txtNavIn,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  YOU-HERE DOT  (static to avoid capturing context)
// ════════════════════════════════════════════════════════════════════════════
class _YouHereDot extends StatelessWidget {
  const _YouHereDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Color(0x38EF4444), blurRadius: 0, spreadRadius: 5),
          BoxShadow(color: Color(0x14EF4444), blurRadius: 0, spreadRadius: 11),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PULSE RING  (pr keyframe from HTML: scale 1→3.8, opacity .18→0)
// ════════════════════════════════════════════════════════════════════════════
class _PulseRing extends StatelessWidget {
  final AnimationController ctrl;
  final double delay;
  const _PulseRing({required this.ctrl, required this.delay});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = (ctrl.value + delay) % 1.0;
        final scale = 1.0 + (1 - math.pow(1 - t, 2.5).toDouble()) * 2.8;
        final opacity = (1 - t) * 0.18;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFC02020).withOpacity(opacity),
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  DATA
// ════════════════════════════════════════════════════════════════════════════
enum _TS { done, active, pending, rejected }

class _Step {
  final String label, key;
  final IconData icon;
  const _Step(this.label, this.icon, this.key);
}

class _Action {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _Action(this.icon, this.label, this.color, {this.onTap});
}

class _Nav {
  final IconData icon;
  final String label;
  const _Nav(this.icon, this.label);
}
