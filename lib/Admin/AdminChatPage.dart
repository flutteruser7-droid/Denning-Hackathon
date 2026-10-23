// ============================================================================
//  admin_chat_page.dart
//
//  Admin Chat Page — User List with Unread Badges
//
//  Architecture:
//  • Reads active users from Firestore `users` collection
//  • For each user, listens to their unread message count from
//    Chats/{roomId}/messages where read==false and sender==userId
//  • Uses appThemeNotifier (ValueNotifier<ThemeMode>) from emergency_chat.dart
//  • Zero hardcoded colors — every surface uses AppColors tokens
//  • Navigates to AdminConversationRoom on tile tap
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emergency_app/Admin/AdminConversationRoom.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// ── Re-export the shared theme notifier from your emergency_chat.dart ─────────
// Replace this import with your actual package path:
// import 'package:emergency_app/shared/emergency_chat.dart';
//
// For self-containment, the notifier + AppColors are redeclared below.
// If you already have them from emergency_chat.dart, DELETE the redeclarations
// and just import that file.

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED THEME NOTIFIER  (delete if imported from emergency_chat.dart)
// ─────────────────────────────────────────────────────────────────────────────
final ValueNotifier<ThemeMode> appThemeNotifier =
    ValueNotifier(ThemeMode.dark);

// ─────────────────────────────────────────────────────────────────────────────
//  COLOR TOKENS  (delete if imported from emergency_chat.dart)
// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  // Role accents
  static const ambulanceGreen = Color(0xFF10B981);
  static const policeBlue     = Color(0xFF3B7DE8);
  static const fireBrigadeRed = Color(0xFFE53E3E);
  static const white          = Color(0xFFFFFFFF);
  static const errorRed       = Color(0xFFC02828);

  // Light
  static const lBgPage     = Color(0xFFE8EEF8);
  static const lBgBody     = Color(0xFFEDF2FB);
  static const lBgCard     = Color(0xFFFFFFFF);
  static const lBgInput    = Color(0xFFF0F4FC);
  static const lCardBdr    = Color(0xFFD4E2F5);
  static const lTxtPrimary = Color(0xFF071830);
  static const lTxtSec     = Color(0xFF8FA2B5);
  static const lTxtMuted   = Color(0xFFA0B3C6);
  static const lDivider    = Color(0xFFEFF4FC);

  // Dark
  static const dBgPage     = Color(0xFF04091A);
  static const dBgBody     = Color(0xFF0D1625);
  static const dBgCard     = Color(0xFF101C36);
  static const dBgInput    = Color(0xFF152040);
  static const dCardBdr    = Color(0x12FFFFFF);
  static const dTxtPrimary = Color(0xFFF0F4FF);
  static const dTxtSec     = Color(0x80FFFFFF);
  static const dTxtMuted   = Color(0x47FFFFFF);
  static const dDivider    = Color(0x0DFFFFFF);

  // Header
  static const hdrFrom = Color(0xFF071D3F);
  static const hdrTo   = Color(0xFF0A2550);
}

// ─────────────────────────────────────────────────────────────────────────────
//  ROLE HELPERS
// ─────────────────────────────────────────────────────────────────────────────
Color roleAccent(String role) {
  switch (role.toLowerCase()) {
    case 'ambulance':    return AppColors.ambulanceGreen;
    case 'fire brigade': return AppColors.fireBrigadeRed;
    default:             return AppColors.policeBlue;
  }
}

IconData roleIcon(String role) {
  switch (role.toLowerCase()) {
    case 'ambulance':    return Icons.emergency_rounded;
    case 'fire brigade': return Icons.local_fire_department_rounded;
    default:             return Icons.local_police_rounded;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CHAT SERVICE  — decoupled from UI
// ─────────────────────────────────────────────────────────────────────────────
class AdminChatService {
  final _db  = FirebaseFirestore.instance;
  final _me  = FirebaseAuth.instance.currentUser!.uid;

  /// Deterministic room id so both sides agree
  String roomId(String otherUid) => _me.compareTo(otherUid) <= 0
      ? '${_me}_$otherUid'
      : '${otherUid}_$_me';

  // ── All active users (no limit — full list) ─────────────────────────────
  Stream<QuerySnapshot> activeUsersStream() => _db
      .collection('users')
      .where('applicationStatus', isEqualTo: 'active')
      .where('role', isEqualTo: 'user')
      .snapshots();

  // ── Latest message in a room ────────────────────────────────────────────
  Stream<QuerySnapshot> latestMessageStream(String otherUid) => _db
      .collection('Chats')
      .doc(roomId(otherUid))
      .collection('messages')
      .orderBy('timestamp', descending: true)
      .limit(1)
      .snapshots();

  // ── Unread count: messages sent BY the user that admin hasn't read ───────
  Stream<QuerySnapshot> unreadStream(String otherUid) => _db
      .collection('Chats')
      .doc(roomId(otherUid))
      .collection('messages')
      .where('sender', isEqualTo: otherUid)
      .where('read', isEqualTo: false)
      .snapshots();
}

// ─────────────────────────────────────────────────────────────────────────────
//  ADMIN CHAT PAGE
// ─────────────────────────────────────────────────────────────────────────────
class AdminChatPage extends StatefulWidget {
  /// Role of the currently logged-in responder: 'Police' | 'Ambulance' | 'Fire Brigade'
  final String role;
  const AdminChatPage({super.key, required this.role});

  @override
  State<AdminChatPage> createState() => _AdminChatPageState();
}

class _AdminChatPageState extends State<AdminChatPage> {
  final _service = AdminChatService();

  // ── Bottom nav tab index (0 = Requests/back, 1 = Chats active) ───────────
  int _tab = 1;

  // ── Theme helpers ──────────────────────────────────────────────────────────
  bool get _dark => appThemeNotifier.value == ThemeMode.dark;

  Color get _bgPage    => _dark ? AppColors.dBgPage    : AppColors.lBgPage;
  Color get _bgBody    => _dark ? AppColors.dBgBody    : AppColors.lBgBody;
  Color get _bgCard    => _dark ? AppColors.dBgCard    : AppColors.lBgCard;
  Color get _cardBdr   => _dark ? AppColors.dCardBdr   : AppColors.lCardBdr;
  Color get _txtPri    => _dark ? AppColors.dTxtPrimary: AppColors.lTxtPrimary;
  Color get _txtSec    => _dark ? AppColors.dTxtSec    : AppColors.lTxtSec;
  Color get _txtMuted  => _dark ? AppColors.dTxtMuted  : AppColors.lTxtMuted;
  Color get _divider   => _dark ? AppColors.dDivider   : AppColors.lDivider;
  Color get _accent    => roleAccent(widget.role);

  // Nav bar bg / border adapt to mode
  Color get _navBg  => _dark ? const Color(0xFF071D3F) : Colors.white;
  Color get _navBdr => _dark ? AppColors.dCardBdr      : AppColors.lCardBdr;

  void _toggleTheme() {
    appThemeNotifier.value =
        _dark ? ThemeMode.light : ThemeMode.dark;
    setState(() {});
  }

  // ── Time formatter ─────────────────────────────────────────────────────────
  String _fmt(Timestamp? ts) {
    if (ts == null) return '';
    final dt  = ts.toDate();
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return DateFormat.jm().format(dt);
    } else if (now.difference(dt).inDays < 7) {
      return DateFormat.E().format(dt);
    }
    return DateFormat('dd/MM/yy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (_, __, ___) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: _bgPage,
        child: Scaffold(
          backgroundColor: Colors.transparent,

          // ── Bottom Navigation Bar ─────────────────────────────────────
          bottomNavigationBar: _buildBottomNav(),

          body: Column(children: [
            _buildAppBar(),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: _bgBody,
                child: StreamBuilder<QuerySnapshot>(
                  stream: _service.activeUsersStream(),
                  builder: (_, snap) {
                    // ── Loading ──────────────────────────────────────────
                    if (snap.connectionState == ConnectionState.waiting) {
                      return _buildLoader();
                    }
                    // ── Error ────────────────────────────────────────────
                    if (snap.hasError) {
                      return _buildEmpty(
                        icon: Icons.error_outline_rounded,
                        title: 'Something went wrong',
                        subtitle: snap.error.toString(),
                        isError: true,
                      );
                    }
                    final docs = snap.data?.docs ?? [];
                    // ── Empty ────────────────────────────────────────────
                    if (docs.isEmpty) {
                      return _buildEmpty(
                        icon: Icons.people_outline_rounded,
                        title: 'No active users',
                        subtitle: 'Users will appear here once approved',
                      );
                    }
                    // ── List ─────────────────────────────────────────────
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 32),
                      physics: const BouncingScrollPhysics(),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: _divider,
                              indent: 78, endIndent: 0),
                      itemBuilder: (_, i) {
                        final data =
                            docs[i].data() as Map<String, dynamic>;
                        final uid = docs[i].id;
                        return _UserTile(
                          uid      : uid,
                          data     : data,
                          service  : _service,
                          role     : widget.role,
                          accent   : _accent,
                          dark     : _dark,
                          bgCard   : _bgCard,
                          cardBdr  : _cardBdr,
                          txtPri   : _txtPri,
                          txtSec   : _txtSec,
                          txtMuted : _txtMuted,
                          fmtTime  : _fmt,
                        );
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

  // ── Bottom Nav ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final items = [
      (
        icon      : Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label     : 'Requests',
      ),
      (
        icon      : Icons.chat_bubble_outline_rounded,
        activeIcon: Icons.chat_bubble_rounded,
        label     : 'Chats',
      ),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: _navBg,
        border: Border(top: BorderSide(color: _navBdr, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_dark ? 0.30 : 0.07),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20, 10, 20,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          return _NavPill(
            icon      : items[i].icon,
            activeIcon: items[i].activeIcon,
            label     : items[i].label,
            active    : _tab == i,
            accent    : _accent,
            dark      : _dark,
            txtMuted  : _txtMuted,
            onTap     : () {
              if (i == 0) {
                // "Requests" → go back to dashboard
                Navigator.maybePop(context);
                return;
              }
              setState(() => _tab = i);
            },
          );
        }),
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.hdrFrom, AppColors.hdrTo],
        ),
        border: Border(
          bottom: BorderSide(color: Color(0x12FFFFFF), width: 0.5)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 14, 20, 18),
      child: Row(children: [
        // Back
        GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.09),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.13)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 15),
          ),
        ),
        const SizedBox(width: 13),

        // Role badge
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.18),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _accent.withOpacity(0.3)),
          ),
          child: Icon(roleIcon(widget.role), color: _accent, size: 18),
        ),
        const SizedBox(width: 12),

        // Titles
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chat Inbox',
                style: TextStyle(
                  color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              const SizedBox(height: 2),
              Text('Active users — ${widget.role}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 11, fontWeight: FontWeight.w500)),
            ]),
        ),

        // Dark / light toggle
        GestureDetector(
          onTap: _toggleTheme,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.09),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.white.withOpacity(0.13), width: 0.5),
            ),
            child: Icon(
              _dark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              color: _dark
                  ? const Color(0xFFFBBF24)
                  : Colors.white.withOpacity(0.8),
              size: 19,
            ),
          ),
        ),
      ]),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _buildLoader() => Center(
    child: CircularProgressIndicator(color: _accent, strokeWidth: 2.5));

  Widget _buildEmpty({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isError = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              color: (isError ? AppColors.errorRed : _accent).withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: (isError ? AppColors.errorRed : _accent).withOpacity(0.2)),
            ),
            child: Icon(icon, size: 30,
                color: isError ? AppColors.errorRed : _accent),
          ),
          const SizedBox(height: 16),
          Text(title,
            style: TextStyle(color: _txtPri, fontSize: 15,
                fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: _txtSec, fontSize: 12, height: 1.5)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  USER TILE  — self-contained, holds its own unread + latest-msg streams
//  Using separate StatefulWidget prevents the parent list from rebuilding
//  when a single tile's unread count changes.
// ─────────────────────────────────────────────────────────────────────────────
class _UserTile extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> data;
  final AdminChatService service;
  final String role;
  final Color accent, bgCard, cardBdr, txtPri, txtSec, txtMuted;
  final bool dark;
  final String Function(Timestamp?) fmtTime;

  const _UserTile({
    required this.uid,
    required this.data,
    required this.service,
    required this.role,
    required this.accent,
    required this.dark,
    required this.bgCard,
    required this.cardBdr,
    required this.txtPri,
    required this.txtSec,
    required this.txtMuted,
    required this.fmtTime,
  });

  String get _name  => data['full_name'] as String? ?? 'Unknown';
  String get _phone => data['phone']     as String? ?? '';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(context,
          MaterialPageRoute(
            builder: (_) => AdminConversationRoom(
              userId  : uid,
              userName: _name,
              role    : role,
            ),
          ),
        ),
        splashColor: accent.withOpacity(0.06),
        highlightColor: accent.withOpacity(0.03),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
          child: Row(children: [

            // ── Avatar ──────────────────────────────────────────────────
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end  : Alignment.bottomRight,
                    colors: [
                      accent.withOpacity(0.85),
                      accent.withOpacity(0.50),
                    ],
                  ),
                  border: Border.all(
                      color: accent.withOpacity(0.35), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

              // ── Unread badge ─────────────────────────────────────────
              StreamBuilder<QuerySnapshot>(
                stream: service.unreadStream(uid),
                builder: (_, snap) {
                  final count = snap.data?.docs.length ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return Positioned(
                    top: -3, right: -3,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: count > 9 ? 5 : 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.fireBrigadeRed,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                            color: dark
                                ? AppColors.dBgBody
                                : AppColors.lBgBody,
                            width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.fireBrigadeRed.withOpacity(0.4),
                            blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ]),

            const SizedBox(width: 14),

            // ── Name + last message ──────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row: name + timestamp
                  Row(children: [
                    Expanded(
                      child: Text(_name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: txtPri, fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        )),
                    ),
                    const SizedBox(width: 8),
                    // Timestamp from latest message stream
                    StreamBuilder<QuerySnapshot>(
                      stream: service.latestMessageStream(uid),
                      builder: (_, snap) {
                        if (!snap.hasData || snap.data!.docs.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final ts = snap.data!.docs.first['timestamp']
                            as Timestamp?;
                        return Text(fmtTime(ts),
                          style: TextStyle(
                            color: txtMuted, fontSize: 11,
                            fontWeight: FontWeight.w500));
                      },
                    ),
                  ]),
                  const SizedBox(height: 4),

                  // Last message preview
                  StreamBuilder<QuerySnapshot>(
                    stream: service.latestMessageStream(uid),
                    builder: (_, snap) {
                      String preview = _phone.isNotEmpty
                          ? '📞 $_phone'
                          : 'Tap to start chatting';
                      bool isUnread = false;

                      if (snap.hasData && snap.data!.docs.isNotEmpty) {
                        final msg = snap.data!.docs.first.data()
                            as Map<String, dynamic>;
                        final txt    = msg['text'] as String? ?? '';
                        final sender = msg['sender'] as String? ?? '';
                        final read   = msg['read']   as bool?   ?? true;
                        final me     = FirebaseAuth.instance.currentUser?.uid ?? '';

                        preview = txt.isNotEmpty ? txt : '(empty)';
                        // Unread = message from them that admin hasn't read
                        isUnread = sender != me && !read;
                      }

                      return Row(children: [
                        Expanded(
                          child: Text(preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isUnread ? txtPri : txtSec,
                              fontSize: 12.5,
                              fontWeight: isUnread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              height: 1.3,
                            )),
                        ),
                      ]);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded,
                color: txtMuted, size: 18),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  NAV PILL  — animated pill with spring scale on press
//  Mirrors AdminDashboardUI's _NavItem exactly for visual consistency.
// ─────────────────────────────────────────────────────────────────────────────
class _NavPill extends StatefulWidget {
  final IconData     icon;
  final IconData     activeIcon;
  final String       label;
  final bool         active;
  final bool         dark;
  final Color        accent;
  final Color        txtMuted;
  final VoidCallback onTap;

  const _NavPill({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.dark,
    required this.accent,
    required this.txtMuted,
    required this.onTap,
  });

  @override
  State<_NavPill> createState() => _NavPillState();
}

class _NavPillState extends State<_NavPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync   : this,
      duration: const Duration(milliseconds: 110),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Inactive icon tint adapts to dark / light mode
    final inactiveTint = widget.dark
        ? Colors.white.withOpacity(0.28)
        : Colors.grey.shade400;

    return GestureDetector(
      onTapDown  : (_) => _ctrl.forward(),
      onTapUp    : (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: ()  => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve   : Curves.easeOutCubic,
          // Pill expands horizontally when active
          padding: widget.active
              ? const EdgeInsets.symmetric(horizontal: 22, vertical: 9)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: widget.active
                ? widget.accent.withOpacity(0.13)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: widget.active
                ? Border.all(color: widget.accent.withOpacity(0.30))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.active ? widget.activeIcon : widget.icon,
                size : 20,
                color: widget.active ? widget.accent : inactiveTint,
              ),
              // Label only visible when active (pill expands to show it)
              if (widget.active) ...[
                const SizedBox(width: 7),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize     : 13,
                    fontWeight   : FontWeight.w700,
                    color        : widget.accent,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
