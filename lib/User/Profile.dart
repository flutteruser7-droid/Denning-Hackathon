import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emergency_app/auth/logout.dart';
import 'package:emergency_app/theme/darkmode.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {

  // ── User data ──────────────────────────────────────────────────────────────
  String _fullName          = '';
  String _email             = '';
  String _phone             = '';
  String _bloodGroup        = '';
  String _nicNumber         = '';
  String _homeAddress       = '';
  String _emergencyContact1 = '';
  String _emergencyContact2 = '';
  bool   _isLoading         = true;

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _shimmerCtrl;
  late Animation<double>   _shimmerAnim;

  // ── ThemeNotifier reference (stored so we can remove listener) ─────────────
  // FIX #1: Store a reference to the notifier so we can add/remove listener
  //         properly instead of relying on didChangeDependencies alone.
  ThemeNotifier? _themeNotifier;

  // ════════════════════════════════════════════════════════════════════════════
  //  TOKENS
  // ════════════════════════════════════════════════════════════════════════════

  // dark
  static const _dBgPage     = Color(0xFF04091A);
  static const _dBgBody     = Color(0xFF0D1625);
  static const _dBgCard     = Color(0xFF101C36);
  static const _dBgCardBdr  = Color(0x12FFFFFF);
  static const _dHdrFrom    = Color(0xFF071D3F);
  static const _dHdrTo      = Color(0xFF0A2550);
  static const _dBgIco      = Color(0x12FFFFFF);
  static const _dHdrBorder  = Color(0x12FFFFFF);
  static const _dHdrTxt     = Colors.white;
  static const _dHdrSubTxt  = Color(0x8CFFFFFF);
  static const _dTxtPrimary = Color(0xFFF0F4FF);
  static const _dTxtSec     = Color(0x80FFFFFF);
  static const _dTxtMuted   = Color(0x47FFFFFF);
  static const _dDivider    = Color(0x0DFFFFFF);
  static const _dNavActFrom = Color(0xFF1A3A72);
  static const _dNavActTo   = Color(0xFF0F2550);

  // light
  static const _lBgPage     = Color(0xFFE8EEF8);
  static const _lBgBody     = Color(0xFFEDF2FB);
  static const _lBgCard     = Color(0xFFFFFFFF);
  static const _lBgCardBdr  = Color(0xFFD4E2F5);
  static const _lBgIco      = Color(0xFFEEF2FB);
  static const _lTxtPrimary = Color(0xFF071830);
  static const _lTxtSec     = Color(0xFF8FA2B5);
  static const _lTxtMuted   = Color(0xFFA0B3C6);
  static const _lDivider    = Color(0xFFEFF4FC);
  static const _lHdrFrom    = Color(0xFFFFFFFF);
  static const _lHdrTo      = Color(0xFFF0F5FF);
  static const _lHdrBorder  = Color(0xFFD4E2F5);
  static const _lHdrTxt     = Color(0xFF071830);
  static const _lHdrSubTxt  = Color(0xFF8FA2B5);

  // shared
  static const _cRed        = Color(0xFFE53E3E);
  static const _cRedDark    = Color(0xFFC02828);
  static const _cGreen      = Color(0xFF10B981);
  static const _cAmber      = Color(0xFFF59E0B);
  static const _cBlue       = Color(0xFF3B7DE8);

  // ── Color getters (driven by ThemeNotifier, NOT context.isDarkMode) ────────
  // FIX #2: Use _themeNotifier?.isDark directly instead of context.isDarkMode
  //         so these getters always reflect the latest value without waiting
  //         for a rebuild cycle from didChangeDependencies.
  // Uses context.isDarkMode directly — always reads current theme state
  bool   get _isDark     => context.isDarkMode;
  Color  get bgPage      => _isDark ? _dBgPage     : _lBgPage;
  Color  get bgBody      => _isDark ? _dBgBody     : _lBgBody;
  Color  get bgCard      => _isDark ? _dBgCard     : _lBgCard;
  Color  get bgCardBdr   => _isDark ? _dBgCardBdr  : _lBgCardBdr;
  Color  get bgIco       => _isDark ? _dBgIco      : _lBgIco;
  Color  get txtPrimary  => _isDark ? _dTxtPrimary : _lTxtPrimary;
  Color  get txtSec      => _isDark ? _dTxtSec     : _lTxtSec;
  Color  get txtMuted    => _isDark ? _dTxtMuted   : _lTxtMuted;
  Color  get dividerClr  => _isDark ? _dDivider    : _lDivider;
  Color  get hdrFrom     => _isDark ? _dHdrFrom    : _lHdrFrom;
  Color  get hdrTo       => _isDark ? _dHdrTo      : _lHdrTo;
  Color  get hdrBorder   => _isDark ? _dHdrBorder  : _lHdrBorder;
  Color  get hdrTxt      => _isDark ? Colors.white  : _lHdrTxt;
  Color  get hdrSubTxt   => _isDark ? _dHdrSubTxt  : _lHdrSubTxt;
  Color  get hdrIconBg   => _isDark ? const Color(0x12FFFFFF) : const Color(0xFFE8EEF8);
  Color  get hdrIconBorder => _isDark ? const Color(0x1FFFFFFF) : const Color(0xFFCDDAEB);
  Color  get hdrIconColor  => _isDark ? Colors.white : _lHdrTxt;
  Color  get avatarFrom  => _isDark ? _dNavActFrom : const Color(0xFF3B7DE8);
  Color  get avatarTo    => _isDark ? _dNavActTo   : const Color(0xFF1A4FB5);

  // ════════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ════════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _shimmerAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // FIX #3: Grab ThemeNotifier via Provider/InheritedWidget once here,
    //         attach our _onThemeChanged listener, and remove the old one
    //         first so we never double-subscribe across hot-reloads.
    final newNotifier = context.themeNotifier; // however your app exposes it
    if (newNotifier != _themeNotifier) {
      _themeNotifier?.removeListener(_onThemeChanged);
      _themeNotifier = newNotifier;
      _themeNotifier?.addListener(_onThemeChanged);
    }
  }

  // FIX #4: Dedicated callback — forces an immediate synchronous rebuild
  //         the moment the notifier fires, with no extra round-trips.
  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // FIX #5: Always remove listener before disposing to prevent memory leaks
    //         and setState-after-dispose crashes.
    _themeNotifier?.removeListener(_onThemeChanged);
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────
  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final d = doc.data() ?? {};
      if (mounted) {
        setState(() {
          _fullName = d['full_name']  as String?
              ?? d['fullName']         as String?
              ?? d['name']             as String?
              ?? user.displayName      ?? 'User';
          _email             = d['email']             as String? ?? user.email ?? '';
          _phone             = d['phone']             as String? ?? '';
          _bloodGroup        = d['bloodGroup']        as String? ?? '';
          _nicNumber         = d['nicNumber']         as String? ?? '';
          _homeAddress       = d['homeAddress']       as String? ?? '';
          _emergencyContact1 = d['emergencyContact1'] as String? ?? '';
          _emergencyContact2 = d['emergencyContact2'] as String? ?? '';
          _isLoading         = false;
        });
      }
    } catch (_) {
      final u = FirebaseAuth.instance.currentUser;
      if (mounted) {
        setState(() {
          _fullName  = u?.displayName ?? 'User';
          _email     = u?.email ?? '';
          _isLoading = false;
        });
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String get _initials {
    final name = _fullName.trim();
    if (name.isEmpty) return '?';
    final parts =
        name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return parts.take(2).map((w) => w[0].toUpperCase()).join();
  }

  String _orDash(String v) => v.trim().isEmpty ? '—' : v.trim();

  // ════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    // ListenableBuilder ensures the ENTIRE tree rebuilds the moment
    // ThemeNotifier fires — no lag, no partial updates.
    return ListenableBuilder(
      listenable: context.themeNotifier,
      builder: (context, _) => AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: bgPage,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(children: [
          _buildHeader(),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              color: bgBody,
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: _cRed,
                        strokeWidth: 2.5,
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 18, 14, 32),
                      physics: const BouncingScrollPhysics(),
                      child: Column(children: [
                        _buildAccountCard(),
                        const SizedBox(height: 13),
                        _buildEmergencyCard(),
                        const SizedBox(height: 28),
                        _buildLogoutButton(),
                      ]),
                    ),
            ),
          ),
        ]),
      ),
    ), // end AnimatedContainer
    ); // end ListenableBuilder
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  HEADER
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [hdrFrom, hdrTo],
        ),
        border: Border(
          bottom: BorderSide(color: hdrBorder, width: 0.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 14,
        20,
        28,
      ),
      child: Column(children: [
        Row(children: [
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
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: hdrIconColor,
                size: 15,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Text(
            'My Profile',
            style: TextStyle(
              color: hdrTxt,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ]),

        const SizedBox(height: 26),

        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          AnimatedBuilder(
            animation: _shimmerAnim,
            builder: (_, child) {
              return Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(avatarFrom, _isDark ? const Color(0xFF203F78) : const Color(0xFF5B93F0),
                          _shimmerAnim.value)!,
                      avatarTo,
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(
                _fullName.isEmpty ? 'User' : _fullName,
                style: TextStyle(
                  color: hdrTxt,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _email,
                style: TextStyle(
                  color: hdrSubTxt,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _cGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: _cGreen.withOpacity(0.28),
                    width: 0.5,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
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
                    'Active Account',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: _cGreen,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  ACCOUNT INFORMATION CARD
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildAccountCard() {
    return _cardSection(
      label: 'ACCOUNT INFORMATION',
      children: [
        _infoRow(
          icon: Icons.person_outline_rounded,
          iconColor: _cBlue,
          label: 'Full Name',
          value: _orDash(_fullName),
        ),
        _divider(),
        _infoRow(
          icon: Icons.email_outlined,
          iconColor: _cAmber,
          label: 'Email Address',
          value: _orDash(_email),
        ),
        _divider(),
        _infoRow(
          icon: Icons.phone_outlined,
          iconColor: _cGreen,
          label: 'Phone Number',
          value: _phone.trim().isEmpty ? 'Not provided' : _phone.trim(),
          dimIfEmpty: _phone.trim().isEmpty,
        ),
        _divider(),
        _infoRow(
          icon: Icons.bloodtype_outlined,
          iconColor: _cRed,
          label: 'Blood Group',
          value: _bloodGroup.trim().isEmpty
              ? 'Not provided'
              : _bloodGroup.trim(),
          valueColor: _bloodGroup.trim().isNotEmpty ? _cRed : null,
          dimIfEmpty: _bloodGroup.trim().isEmpty,
        ),
        _divider(),
        _infoRow(
          icon: Icons.badge_outlined,
          iconColor: const Color(0xFF9B59B6),
          label: 'NIC Number',
          value: _nicNumber.trim().isEmpty ? 'Not provided' : _nicNumber.trim(),
          dimIfEmpty: _nicNumber.trim().isEmpty,
        ),
        _divider(),
        _infoRow(
          icon: Icons.home_outlined,
          iconColor: const Color(0xFF0EA5E9),
          label: 'Home Address',
          value: _homeAddress.trim().isEmpty
              ? 'Not provided'
              : _homeAddress.trim(),
          dimIfEmpty: _homeAddress.trim().isEmpty,
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  EMERGENCY CONTACTS CARD
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildEmergencyCard() {
    final c1 = _emergencyContact1.trim();
    final c2 = _emergencyContact2.trim();
    final hasAny = c1.isNotEmpty || c2.isNotEmpty;

    return _cardSection(
      label: 'EMERGENCY CONTACTS',
      children: [
        _infoRow(
          icon: Icons.emergency_outlined,
          iconColor: _cRed,
          label: 'Contact 1',
          value: c1.isEmpty ? 'Not provided' : c1,
          dimIfEmpty: c1.isEmpty,
        ),
        _divider(),
        _infoRow(
          icon: Icons.emergency_share_outlined,
          iconColor: _cRed,
          label: 'Contact 2',
          value: c2.isEmpty ? 'Not provided' : c2,
          dimIfEmpty: c2.isEmpty,
        ),
        if (!hasAny) ...[
          _divider(),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 14, color: txtMuted),
              const SizedBox(width: 8),
              Text(
                'No emergency contacts saved',
                style: TextStyle(fontSize: 12, color: txtMuted),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  LOGOUT BUTTON
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _confirmLogout,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_cRed, _cRedDark],
          ),
          boxShadow: [
            BoxShadow(
              color: _cRedDark.withOpacity(0.45),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
            width: 0.5,
          ),
        ),
        child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Icon(Icons.logout_rounded, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Text(
            'Log Out',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ════════════════════════════════════════════════════════════════════════════

  Widget _cardSection({
    required String label,
    required List<Widget> children,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 9),
        child: Row(children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: txtSec,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Divider(color: bgCardBdr, height: 1, thickness: 0.5)),
        ]),
      ),
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: bgCardBdr, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 22,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(children: children),
      ),
    ]);
  }

  Widget _infoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
    bool dimIfEmpty = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: bgIco,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 17, color: iconColor),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: txtMuted,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: dimIfEmpty ? txtMuted : (valueColor ?? txtPrimary),
                letterSpacing: 0.1,
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _divider() => Divider(
        height: 1,
        thickness: 0.5,
        color: dividerClr,
        indent: 66,
      );

  // ════════════════════════════════════════════════════════════════════════════
  //  LOGOUT DIALOG
  // ════════════════════════════════════════════════════════════════════════════

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: bgCardBdr, width: 0.5),
        ),
        title: Text(
          'Log Out?',
          style: TextStyle(
            color: txtPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        content: Text(
          'You will be signed out of your account.',
          style: TextStyle(color: txtSec, fontSize: 13, height: 1.4),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: txtSec,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                  color: txtSec,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.pop(ctx);
              LogoutHelper.logout(context);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: const LinearGradient(
                  colors: [_cRed, _cRedDark],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _cRedDark.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Text(
                'Log Out',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}