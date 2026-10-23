import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emergency_app/theme/darkmode.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HistoryTrackingPage extends StatefulWidget {
  const HistoryTrackingPage({super.key});

  @override
  State<HistoryTrackingPage> createState() => _HistoryTrackingPageState();
}

class _HistoryTrackingPageState extends State<HistoryTrackingPage>
    with SingleTickerProviderStateMixin {

  // ── State ──────────────────────────────────────────────────────────────────
  final Map<String, bool> _expandedState = {};

  // ── ThemeNotifier reference ────────────────────────────────────────────────
  ThemeNotifier? _themeNotifier;

  // ── FIX 1: Stream cached here — built ONCE in initState, never inside build() ──
  // Calling _getHistoryStream() inside build() was the root cause: every setState
  // (card expand, theme toggle) destroyed and re-created the Firestore subscription,
  // which both re-queried the DB and triggered the loading/error states visibly.
Stream<QuerySnapshot> _historyStream = const Stream.empty();


  // ════════════════════════════════════════════════════════════════════════════
  //  TOKENS
  // ════════════════════════════════════════════════════════════════════════════

  // dark
  static const _dBgPage    = Color(0xFF04091A);
  static const _dBgBody    = Color(0xFF0D1625);
  static const _dBgCard    = Color(0xFF101C36);
  static const _dBgCardBdr = Color(0x12FFFFFF);
  static const _dHdrFrom   = Color(0xFF071D3F);
  static const _dHdrTo     = Color(0xFF0A2550);
  static const _dBgIco     = Color(0x12FFFFFF);
  static const _dHdrBorder = Color(0x12FFFFFF);
  // ignore: unused_field
  static const _dHdrTxt    = Colors.white;
  // ignore: unused_field
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
  // ignore: unused_field
  static const _lHdrSubTxt  = Color(0xFF8FA2B5);

  // shared
  static const _cRed     = Color(0xFFE53E3E);
  static const _cRedDark = Color(0xFFC02828);
  static const _cGreen   = Color(0xFF10B981);
  static const _cAmber   = Color(0xFFF59E0B);
  static const _cBlue    = Color(0xFF3B7DE8);

  // ── Color getters ──────────────────────────────────────────────────────────
  bool  get _isDark       => context.isDarkMode;
  Color get bgPage        => _isDark ? _dBgPage     : _lBgPage;
  Color get bgBody        => _isDark ? _dBgBody     : _lBgBody;
  Color get bgCard        => _isDark ? _dBgCard     : _lBgCard;
  Color get bgCardBdr     => _isDark ? _dBgCardBdr  : _lBgCardBdr;
  Color get bgIco         => _isDark ? _dBgIco      : _lBgIco;
  Color get txtPrimary    => _isDark ? _dTxtPrimary : _lTxtPrimary;
  Color get txtSec        => _isDark ? _dTxtSec     : _lTxtSec;
  Color get txtMuted      => _isDark ? _dTxtMuted   : _lTxtMuted;
  Color get dividerClr    => _isDark ? _dDivider    : _lDivider;
  Color get hdrFrom       => _isDark ? _dHdrFrom    : _lHdrFrom;
  Color get hdrTo         => _isDark ? _dHdrTo      : _lHdrTo;
  Color get hdrBorder     => _isDark ? _dHdrBorder  : _lHdrBorder;
  Color get hdrTxt        => _isDark ? Colors.white : _lHdrTxt;
  Color get hdrIconBg     => _isDark ? const Color(0x12FFFFFF) : const Color(0xFFE8EEF8);
  Color get hdrIconBorder => _isDark ? const Color(0x1FFFFFFF) : const Color(0xFFCDDAEB);
  Color get hdrIconColor  => _isDark ? Colors.white : _lHdrTxt;
  Color get avatarFrom    => _isDark ? _dNavActFrom : const Color(0xFF3B7DE8);
  Color get avatarTo      => _isDark ? _dNavActTo   : const Color(0xFF1A4FB5);

  // ════════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ════════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    // Stream is created exactly once here. All subsequent rebuilds (theme toggle,
    // card expand/collapse) reuse this same subscription — zero extra DB calls.
    _historyStream = _buildHistoryStream();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newNotifier = context.themeNotifier;
    if (newNotifier != _themeNotifier) {
      _themeNotifier?.removeListener(_onThemeChanged);
      _themeNotifier = newNotifier;
      _themeNotifier?.addListener(_onThemeChanged);
    }
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _themeNotifier?.removeListener(_onThemeChanged);
    super.dispose();
  }

  // ── Database Queries ───────────────────────────────────────────────────────

  // FIX 2: Removed .orderBy('updatedAt', descending: true).
  //
  // Combining .where('userId', ...) and .orderBy('updatedAt', ...) on TWO
  // DIFFERENT FIELDS forces Firestore to require a composite index. Without
  // that index being manually created in the Firebase Console, the query
  // throws immediately — which is exactly the "Error loading history" crash
  // you were seeing.
  //
  // Solution: query with .where() only (no index needed) and sort the results
  // on the client side. See the sorted list below inside StreamBuilder.
  Stream<QuerySnapshot> _buildHistoryStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('requests')
        .where('userId', isEqualTo: user.uid)
        // ← orderBy removed intentionally; client-side sort is used instead
        .snapshots();
  }

  Future<void> _cancelRequest(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(docId)
          .update({'status': 'cancelled'});
    } catch (e) {
      debugPrint("Error cancelling request: $e");
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final hour =
          date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final amPm = date.hour >= 12 ? 'PM' : 'AM';
      final min = date.minute.toString().padLeft(2, '0');
      return "${date.day}/${date.month}/${date.year} at $hour:$min $amPm";
    }
    return 'Processing date...';
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
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
                child: StreamBuilder<QuerySnapshot>(
                  // Using the PRE-BUILT cached stream from initState.
                  // The StreamBuilder simply listens to it; it never creates a new one.
                  stream: _historyStream ?? const Stream.empty(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                            color: _cRed, strokeWidth: 2.5),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            "Error loading history.\n${snapshot.error}",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: txtSec),
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_rounded,
                                size: 60,
                                color: txtMuted.withOpacity(0.5)),
                            const SizedBox(height: 16),
                            Text('No history found',
                                style:
                                    TextStyle(color: txtSec, fontSize: 16)),
                          ],
                        ),
                      );
                    }

                    // FIX 2 (continued): Client-side sort replaces the removed
                    // .orderBy() — newest updatedAt appears first.
                    final docs = List.of(snapshot.data!.docs)
                      ..sort((a, b) {
                        final aTime =
                            (a.data() as Map<String, dynamic>)['updatedAt']
                                as Timestamp?;
                        final bTime =
                            (b.data() as Map<String, dynamic>)['updatedAt']
                                as Timestamp?;
                        if (aTime != null && bTime != null) {
                          return bTime.compareTo(aTime); // descending
                        }
                        return 0;
                      });

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 18, 14, 32),
                      physics: const BouncingScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildHistoryItem(doc.id, data);
                      },
                    );
                  },
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  HEADER
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: hdrIconBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: hdrIconBorder),
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
              'History',
              style: TextStyle(
                color: hdrTxt,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  HISTORY ITEM CARD
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildHistoryItem(String docId, Map<String, dynamic> data) {
    final status = data['status'] as String? ?? 'processing';
    final serviceType = data['serviceType'] as String? ?? 'Emergency Request';
    final timestamp = data['updatedAt'];
    final city = data['city'] as String? ?? '';
    final district = data['district'] as String? ?? '';

    final isExpanded = _expandedState[docId] ?? false;

    Color statusColor;
    IconData statusIcon;

    switch (status.toLowerCase()) {
      case 'sent':
        statusColor = _cBlue;
        statusIcon = Icons.send_rounded;
        break;
      case 'completed':
        statusColor = _cGreen;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'cancelled':
        statusColor = _cRed;
        statusIcon = Icons.cancel_rounded;
        break;
      case 'processing':
      default:
        statusColor = _cAmber;
        statusIcon = Icons.sync_rounded;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bgCardBdr, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedState[docId] = !isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serviceType,
                          style: TextStyle(
                            color: txtPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(timestamp),
                          style: TextStyle(
                            color: txtSec,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: txtMuted,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Tracking Area
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Column(
                    children: [
                      Divider(height: 1, thickness: 0.5, color: dividerClr),
                      if (city.isNotEmpty || district.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 14, color: txtMuted),
                              const SizedBox(width: 6),
                              Text(
                                [city, district]
                                    .where((e) => e.isNotEmpty)
                                    .join(', '),
                                style: TextStyle(
                                    color: txtSec,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: _buildTrackerLine(status),
                      ),
                      if (status.toLowerCase() == 'sent')
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: _buildCancelButton(docId),
                        ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  TRACKER LOGIC
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildTrackerLine(String status) {
    int currentStep = 0;
    bool isCancelled = false;

    switch (status.toLowerCase()) {
      case 'sent':
        currentStep = 1;
        break;
      case 'processing':
        currentStep = 2;
        break;
      case 'completed':
        currentStep = 3;
        break;
      case 'cancelled':
        isCancelled = true;
        break;
    }

    if (isCancelled) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, color: _cRed, size: 24),
          const SizedBox(width: 8),
          Text(
            'Request Cancelled',
            style: TextStyle(
                color: _cRed, fontWeight: FontWeight.bold, fontSize: 14),
          )
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _trackerStep('Sent', Icons.send, currentStep >= 1),
        _trackerDivider(currentStep >= 2),
        _trackerStep('Processing', Icons.sync, currentStep >= 2),
        _trackerDivider(currentStep >= 3),
        _trackerStep('Completed', Icons.check, currentStep >= 3),
      ],
    );
  }

  Widget _trackerStep(String label, IconData icon, bool isActive) {
    final color = isActive ? _cBlue : bgIco;
    final iconColor = isActive ? Colors.white : txtMuted;

    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border:
                Border.all(color: isActive ? _cBlue : bgCardBdr, width: 2),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive ? txtPrimary : txtMuted,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _trackerDivider(bool isActive) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(bottom: 20, left: 8, right: 8),
        height: 3,
        decoration: BoxDecoration(
          color: isActive ? _cBlue : bgIco,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  CANCEL BUTTON
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildCancelButton(String docId) {
    return GestureDetector(
      onTap: () => _confirmCancel(docId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_cRed, _cRedDark],
          ),
          boxShadow: [
            BoxShadow(
              color: _cRedDark.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
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
            Icon(Icons.cancel_outlined, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Cancel Request',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCancel(String docId) {
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
          'Cancel Request?',
          style: TextStyle(
            color: txtPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        content: Text(
          'Are you sure you want to cancel this emergency request? This action cannot be undone.',
          style: TextStyle(color: txtSec, fontSize: 13, height: 1.4),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: txtSec,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Go Back',
              style: TextStyle(
                color: txtSec,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.pop(ctx);
              _cancelRequest(docId);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                color: _cRed,
              ),
              child: const Text(
                'Yes, Cancel',
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