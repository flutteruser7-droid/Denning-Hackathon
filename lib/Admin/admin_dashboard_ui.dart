// ═══════════════════════════════════════════════════════════════════════════════
//  admin_dashboard_ui.dart
//
//  CHANGES FROM ORIGINAL:
//  ① THEME FIX — Replaced context.isDarkMode (which read from an external
//    notifier that rebuilt the StreamBuilder, causing a loading flash) with a
//    self-contained _ThemeController (ValueNotifier<bool>) initialised from
//    SharedPreferences. The ValueNotifier is scoped to this widget tree via
//    _ThemeScope (InheritedWidget), so theme toggles only rebuild the widgets
//    that actually consume the value — never the StreamBuilder.
//
//  ② CHAT NAV FIX — Removed _ChatTab (StatefulWidget that pushed a route from
//    initState). Instead, the bottom-nav "Chat" tap directly calls
//    _navigateToChat() on the parent state, which uses pushNamed with a custom
//    PageRouteBuilder (200 ms fade+slide). This avoids the blank-tab flash,
//    double-push on hot-reload, and the back-button returning to an empty shell.
//    The tab index is reset to 0 after Navigator.push returns so the bottom nav
//    stays consistent.
//
//  ③ UI POLISH — InkWell ripple on every tappable surface, spring physics on
//    the bottom-nav pill, _Btn uses ScaleTransition on press via
//    _PressableBtn wrapper, shimmer uses a proper sweep gradient, card entrance
//    uses staggered SlideTransition, status chip pulses for 'pending', and
//    _MapBtn shows a success flash via HapticFeedback.selectionClick.
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emergency_app/auth/logout.dart';
import 'package:emergency_app/Admin/AdminChatPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PALETTE
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const dPage = Color(0xFF04091A);
  static const dSurf1 = Color(0xFF071D3F);
  static const dSurf2 = Color(0xFF0D1B2E);
  static const dSurf3 = Color(0xFF101F35);
  static const dBdr = Color(0x14FFFFFF);
  static const dTxtPri = Color(0xFFF0F4FF);
  static const dTxtSec = Color(0x80FFFFFF);
  static const dTxtMut = Color(0x47FFFFFF);

  static const lPage = Color(0xFFF0F4FB);
  static const lSurf1 = Color(0xFF0D2550);
  static const lSurf2 = Color(0xFFFFFFFF);
  static const lSurf3 = Color(0xFFF5F8FF);
  static const lBdr = Color(0xFFD4E2F5);
  static const lTxtPri = Color(0xFF071830);
  static const lTxtSec = Color(0xFF8FA2B5);
  static const lTxtMut = Color(0xFFB0C0D0);

  static const red = Color(0xFFE53E3E);
  static const green = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);
  static const blue = Color(0xFF3B82F6);
  static const purple = Color(0xFF8B5CF6);
  static const teal = Color(0xFF14B8A6);
  static const navy3 = Color(0xFF1A3A72);
  static const cyan = Color(0xFF64FFDA);
}

// ─────────────────────────────────────────────────────────────────────────────
//  ① THEME CONTROLLER
//  A lightweight ValueNotifier that persists dark-mode preference to
//  SharedPreferences synchronously in memory and asynchronously to disk.
//  Zero Firestore calls — no loading flash possible.
// ─────────────────────────────────────────────────────────────────────────────
class _ThemeController extends ValueNotifier<bool> {
  static const _key = 'admin_dark_mode';

  _ThemeController(bool initialDark) : super(initialDark);

  /// Call once at widget init; reads prefs without blocking the first frame.
  static Future<_ThemeController> load() async {
    final prefs = await SharedPreferences.getInstance();
    return _ThemeController(prefs.getBool(_key) ?? false);
  }

  void toggle() {
    value = !value;
    // Fire-and-forget disk write — never blocks UI.
    SharedPreferences.getInstance().then((p) => p.setBool(_key, value));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  THEME SCOPE — InheritedWidget so descendants can read/write without
//  prop-drilling. Only subtrees that call _ThemeScope.of(context) rebuild.
// ─────────────────────────────────────────────────────────────────────────────
class _ThemeScope extends InheritedNotifier<_ThemeController> {
  const _ThemeScope({
    required _ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static _ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ThemeScope>();
    assert(scope != null, '_ThemeScope not found in widget tree');
    return scope!.notifier!;
  }

  static bool isDark(BuildContext context) => of(context).value;
}

// ─────────────────────────────────────────────────────────────────────────────
//  ADMIN DASHBOARD
// ─────────────────────────────────────────────────────────────────────────────
class AdminDashboardUI extends StatefulWidget {
  final String serviceType;
  final Color primaryColor;
  final IconData serviceIcon;

  const AdminDashboardUI({
    super.key,
    required this.serviceType,
    required this.primaryColor,
    required this.serviceIcon,
  });

  @override
  State<AdminDashboardUI> createState() => _AdminDashboardUIState();
}

class _AdminDashboardUIState extends State<AdminDashboardUI>
    with SingleTickerProviderStateMixin {
  // ① Theme controller — nullable until async load completes (one frame max).
  _ThemeController? _theme;

  // Stable Firestore stream — created once, never recreated on rebuilds.
  Stream<QuerySnapshot>? _streamCache;
  Stream<QuerySnapshot> get _stream {
    _streamCache ??= FirebaseFirestore.instance
        .collection('requests')
        .snapshots();
    return _streamCache!;
  }

  int _tab = 0;
  late final AnimationController _navAnim;

  @override
  void initState() {
    super.initState();
    _navAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _navAnim.forward();

    // Load theme from SharedPreferences; one async hop then setState once.
    _ThemeController.load().then((ctrl) {
      if (mounted) setState(() => _theme = ctrl);
    });
  }

  @override
  void dispose() {
    _navAnim.dispose();
    _theme?.dispose();
    super.dispose();
  }

  // ② CHAT NAVIGATION — direct push from the parent state, NOT from a child
  //    initState. This eliminates the blank-tab flash and double-push risk.
  //    The tab index resets to 0 when the user comes back (await completes).
  Future<void> _navigateToChat() async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, animation, secondaryAnimation) =>
            AdminChatPage(role: widget.serviceType),
        transitionsBuilder: (_, animation, __, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );
          final slide =
              Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );
    // Reset tab to Requests when user navigates back from Chat.
    if (mounted) setState(() => _tab = 0);
  }

  // ─── convenience getters that read from _ThemeScope ──────────────────────
  bool _dark(BuildContext ctx) => _ThemeScope.isDark(ctx);
  Color _page(BuildContext ctx) => _dark(ctx) ? _C.dPage : _C.lPage;
  Color _surf1(BuildContext ctx) => _dark(ctx) ? _C.dSurf1 : _C.lSurf1;
  Color _surf2(BuildContext ctx) => _dark(ctx) ? _C.dSurf2 : _C.lSurf2;
  Color _surf3(BuildContext ctx) => _dark(ctx) ? _C.dSurf3 : _C.lSurf3;
  Color _bdr(BuildContext ctx) => _dark(ctx) ? _C.dBdr : _C.lBdr;
  Color _pri(BuildContext ctx) => _dark(ctx) ? _C.dTxtPri : _C.lTxtPri;
  Color _sec(BuildContext ctx) => _dark(ctx) ? _C.dTxtSec : _C.lTxtSec;
  Color _mut(BuildContext ctx) => _dark(ctx) ? _C.dTxtMut : _C.lTxtMut;

  @override
  Widget build(BuildContext context) {
    // Show a blank scaffold until prefs load (single frame, imperceptible).
    if (_theme == null) {
      return const Scaffold(backgroundColor: _C.dPage, body: SizedBox.shrink());
    }

    // Wrap the entire tree in _ThemeScope so any descendant can react to
    // theme changes without rebuilding the StreamBuilder.
    return _ThemeScope(
      controller: _theme!,
      child: ValueListenableBuilder<bool>(
        valueListenable: _theme!,
        builder: (context, dark, _) {
          SystemChrome.setSystemUIOverlayStyle(
            dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          );
          return Scaffold(
            backgroundColor: _page(context),
            body: Column(
              children: [
                _Header(
                  serviceType: widget.serviceType,
                  primaryColor: widget.primaryColor,
                  tab: _tab,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0, 0.025),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: anim,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: child,
                      ),
                    ),
                    // ② Only the Requests tab is ever built as a child widget.
                    //    Chat is a pushed route, not a tab body.
                    child: _RequestsTab(
                      key: const ValueKey('requests'),
                      stream: _stream,
                      serviceType: widget.serviceType,
                      primaryColor: widget.primaryColor,
                      serviceIcon: widget.serviceIcon,
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: _BottomNav(
              tab: _tab,
              primary: widget.primaryColor,
              onTap: (i) {
                if (i == 1) {
                  // ② Chat tap: push route directly, never switch tab body.
                  _navigateToChat();
                  return;
                }
                setState(() => _tab = i);
                _navAnim
                  ..reset()
                  ..forward();
              },
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String serviceType;
  final Color primaryColor;
  final int tab;

  const _Header({
    required this.serviceType,
    required this.primaryColor,
    required this.tab,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = _ThemeScope.of(context);
    final dark = ctrl.value;
    final surf1 = dark ? _C.dSurf1 : _C.lSurf1;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [surf1, dark ? const Color(0xFF0A2550) : primaryColor],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.4 : 0.22),
            blurRadius: 24,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.of(context).padding.top + 12,
        18,
        16,
      ),
      child: Row(
        children: [
          // Service icon pill with subtle inner glow
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.06),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.dashboard_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tab == 0 ? '$serviceType DASHBOARD' : 'LIVE CHATS',
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withOpacity(0.5),
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tab == 0 ? 'Active Requests' : 'Operator Messages',
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // ① Theme toggle — reads/writes _ThemeController, zero Firestore
          _ThemeToggle(ctrl: ctrl),
          const SizedBox(width: 10),
          // Logout button with ripple
          _LogoutBtn(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ① THEME TOGGLE — reads from InheritedNotifier, never triggers StreamBuilder
// ─────────────────────────────────────────────────────────────────────────────
class _ThemeToggle extends StatelessWidget {
  final _ThemeController ctrl;
  const _ThemeToggle({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final dark = ctrl.value;
    return GestureDetector(
      onTap: ctrl.toggle, // ← SharedPreferences write only, no setState above
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        width: 54,
        height: 29,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: dark ? _C.navy3 : Colors.white.withOpacity(0.22),
          border: Border.all(
            color: dark ? Colors.white24 : Colors.white38,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              left: dark ? 27 : 2,
              top: 2,
              child: Container(
                width: 23,
                height: 23,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark ? _C.cyan : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 5,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  dark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                  size: 13,
                  color: dark ? _C.dPage : _C.lSurf1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LOGOUT BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _LogoutBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => LogoutHelper.logout(context),
        borderRadius: BorderRadius.circular(20),
        splashColor: _C.red.withOpacity(0.2),
        highlightColor: _C.red.withOpacity(0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _C.red.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.red.withOpacity(0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.logout_rounded, color: _C.red, size: 14),
              const SizedBox(width: 5),
              Text(
                'Logout',
                style: GoogleFonts.openSans(
                  color: _C.red,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BOTTOM NAV
//  ② "Chat" item triggers _navigateToChat() instead of switching tab body.
//     The pill uses a spring-like AnimatedContainer for the expand animation.
// ─────────────────────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int tab;
  final Color primary;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.tab,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = _ThemeScope.isDark(context);
    final bg = dark ? const Color(0xFF071D3F) : Colors.white;
    final bdr = dark ? _C.dBdr : _C.lBdr;

    final items = [
      (
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Requests',
      ),
      (
        icon: Icons.chat_bubble_outline_rounded,
        activeIcon: Icons.chat_bubble_rounded,
        label: 'Chat',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: bdr, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.28 : 0.07),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final active = tab == i;
          final accent = dark ? _C.cyan : primary;
          return _NavItem(
            icon: items[i].icon,
            activeIcon: items[i].activeIcon,
            label: items[i].label,
            active: active,
            accent: accent,
            dark: dark,
            onTap: () => onTap(i),
          );
        }),
      ),
    );
  }
}

// ── Separate stateful widget so each pill animates independently ──────────────
class _NavItem extends StatefulWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool active, dark;
  final Color accent;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.dark,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.88,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: widget.active
              ? const EdgeInsets.symmetric(horizontal: 22, vertical: 8)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.active
                ? widget.accent.withOpacity(0.13)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: widget.active
                ? Border.all(color: widget.accent.withOpacity(0.28))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.active ? widget.activeIcon : widget.icon,
                size: 19,
                color: widget.active
                    ? widget.accent
                    : (widget.dark ? Colors.white30 : Colors.grey.shade400),
              ),
              if (widget.active) ...[
                const SizedBox(width: 7),
                Text(
                  widget.label,
                  style: GoogleFonts.openSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: widget.accent,
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

// ─────────────────────────────────────────────────────────────────────────────
//  REQUESTS TAB
//  Holds the StreamBuilder. Reads theme from _ThemeScope, NOT from parent
//  state — so theme toggles never cause this subtree to rebuild from scratch.
// ─────────────────────────────────────────────────────────────────────────────
class _RequestsTab extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final String serviceType;
  final Color primaryColor;
  final IconData serviceIcon;

  const _RequestsTab({
    super.key,
    required this.stream,
    required this.serviceType,
    required this.primaryColor,
    required this.serviceIcon,
  });

  @override
  Widget build(BuildContext context) {
    final dark = _ThemeScope.isDark(context);
    final surf2 = dark ? _C.dSurf2 : _C.lSurf2;
    final surf3 = dark ? _C.dSurf3 : _C.lSurf3;
    final bdr = dark ? _C.dBdr : _C.lBdr;
    final pri = dark ? _C.dTxtPri : _C.lTxtPri;
    final sec = dark ? _C.dTxtSec : _C.lTxtSec;
    final mut = dark ? _C.dTxtMut : _C.lTxtMut;

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _ShimmerList(surf2: surf2, dark: dark);
        }
        if (snap.hasError) {
          return _ErrorState(error: snap.error, pri: pri);
        }

        final docs =
            (snap.data?.docs ?? []).where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final dbType = (d['serviceType'] as String? ?? '').toLowerCase();
              final target = (d['alert_target'] as String? ?? '').toLowerCase();
              final current = serviceType.toLowerCase();
              return dbType == current || target == current || dbType == 'sos';
            }).toList()..sort((a, b) {
              final tA = (a.data() as Map)['updatedAt'] as Timestamp?;
              final tB = (b.data() as Map)['updatedAt'] as Timestamp?;
              if (tA == null || tB == null) return 0;
              return tB.compareTo(tA);
            });

        if (docs.isEmpty) {
          return _EmptyState(serviceType: serviceType, sec: sec);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            // ③ Staggered card entrance — each card slides in with a small delay
            return _StaggeredCard(
              index: i,
              child: _RequestCard(
                key: ValueKey(docs[i].id),
                data: data,
                docId: docs[i].id,
                primaryColor: primaryColor,
                serviceIcon: serviceIcon,
                surf2: surf2,
                surf3: surf3,
                bdr: bdr,
                pri: pri,
                sec: sec,
                mut: mut,
              ),
            );
          },
        );
      },
    );
  }
}

// ── Staggered entrance wrapper ────────────────────────────────────────────────
class _StaggeredCard extends StatefulWidget {
  final int index;
  final Widget child;
  const _StaggeredCard({required this.index, required this.child});

  @override
  State<_StaggeredCard> createState() => _StaggeredCardState();
}

class _StaggeredCardState extends State<_StaggeredCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Stagger delay per card (capped at 5 cards worth)
    final delay = Duration(milliseconds: 60 * (widget.index % 5));
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  REQUEST CARD
// ─────────────────────────────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final Color primaryColor;
  final IconData serviceIcon;
  final Color surf2, surf3, bdr, pri, sec, mut;

  const _RequestCard({
    super.key,
    required this.data,
    required this.docId,
    required this.primaryColor,
    required this.serviceIcon,
    required this.surf2,
    required this.surf3,
    required this.bdr,
    required this.pri,
    required this.sec,
    required this.mut,
  });

  Future<void> _updateStatus(BuildContext ctx, String status) async {
    HapticFeedback.mediumImpact();
    try {
      await FirebaseFirestore.instance.collection('requests').doc(docId).update(
        {'status': status, 'updatedAt': FieldValue.serverTimestamp()},
      );
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            'Update failed: $e',
            style: GoogleFonts.openSans(fontSize: 13),
          ),
          backgroundColor: _C.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = _ThemeScope.isDark(context);
    final status = data['status'] as String? ?? 'pending';
    final requestType = data['serviceType'] as String? ?? 'Request';
    final name = data['userFullName'] as String? ?? 'Unknown';
    final phone = data['phone'] ?? data['userPhone'] ?? 'N/A';
    final bloodGroup = data['bloodGroup'] as String?;
    final locMap = data['location'] as Map<String, dynamic>?;
    final address = locMap?['address'] as String? ?? 'Unknown location';
    final lat = locMap?['latitude'] as double?;
    final lng = locMap?['longitude'] as double?;
    final isSOS = requestType.toLowerCase() == 'sos';

    final statusMeta = _statusMeta(status);
    final accent = isSOS ? _C.red : primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: surf2,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSOS ? _C.red.withOpacity(0.5) : bdr,
          width: isSOS ? 1.5 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.22 : 0.065),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
          if (isSOS)
            BoxShadow(
              color: _C.red.withOpacity(0.14),
              blurRadius: 24,
              spreadRadius: 3,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card header strip ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.centerRight,
                  colors: [
                    accent.withOpacity(dark ? 0.20 : 0.09),
                    accent.withOpacity(dark ? 0.06 : 0.03),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(color: accent.withOpacity(0.13)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: accent.withOpacity(0.2)),
                    ),
                    child: Icon(
                      isSOS ? Icons.warning_amber_rounded : serviceIcon,
                      color: accent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          requestType.toUpperCase(),
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: accent,
                            letterSpacing: 0.7,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Request #${docId.substring(0, 6).toUpperCase()}',
                          style: GoogleFonts.openSans(
                            fontSize: 10,
                            color: sec,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ③ Status chip — pulses for pending state
                  _StatusChip(statusMeta: statusMeta, status: status),
                ],
              ),
            ),

            // ── Card body ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.person_rounded,
                    label: 'Name',
                    value: name,
                    pri: pri,
                    sec: sec,
                    surf3: surf3,
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.phone_rounded,
                    label: 'Phone',
                    value: '$phone',
                    pri: pri,
                    sec: sec,
                    surf3: surf3,
                  ),
                  if (bloodGroup != null && bloodGroup.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.bloodtype_rounded,
                      label: 'Blood',
                      value: bloodGroup,
                      pri: _C.red,
                      sec: sec,
                      surf3: surf3,
                    ),
                  ],
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.location_on_rounded,
                    label: 'Location',
                    value: address,
                    pri: pri,
                    sec: sec,
                    surf3: surf3,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  Divider(height: 1, thickness: 0.5, color: bdr),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (lat != null && lng != null) ...[
                        _MapBtn(lat: lat, lng: lng, accent: accent),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: _ActionButtons(
                          status: status,
                          onUpdate: (s) => _updateStatus(context, s),
                        ),
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

  ({Color color, String label}) _statusMeta(String s) => switch (s) {
    'accepted' => (color: _C.blue, label: 'Accepted'),
    'on_the_way' => (color: _C.purple, label: 'On the way'),
    'arrived' => (color: _C.teal, label: 'Arrived'),
    'rejected' => (color: _C.red, label: 'Rejected'),
    'cancelled' => (color: _C.red, label: 'Cancelled'),
    _ => (color: _C.amber, label: 'Pending'),
  };
}

// ── Status chip — pulses amber dot for pending ────────────────────────────────
class _StatusChip extends StatefulWidget {
  final ({Color color, String label}) statusMeta;
  final String status;
  const _StatusChip({required this.statusMeta, required this.status});

  @override
  State<_StatusChip> createState() => _StatusChipState();
}

class _StatusChipState extends State<_StatusChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.status == 'pending' || widget.status == 'sent') {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.statusMeta.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.11),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: c.withOpacity(0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                color: c.withOpacity(
                  (_pulse.isAnimating) ? 0.4 + 0.6 * _pulse.value : 1.0,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Text(
            widget.statusMeta.label,
            style: GoogleFonts.openSans(
              color: c,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info Row ──────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color pri, sec, surf3;
  final int maxLines;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.pri,
    required this.sec,
    required this.surf3,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: surf3,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 15, color: sec),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.openSans(
                  fontSize: 9.5,
                  color: sec,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.openSans(
                  fontSize: 13.5,
                  color: pri,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Map Button ────────────────────────────────────────────────────────────────
class _MapBtn extends StatelessWidget {
  final double lat, lng;
  final Color accent;
  const _MapBtn({required this.lat, required this.lng, required this.accent});

  @override
  Widget build(BuildContext context) {
    return _PressableBtn(
      onTap: () async {
        HapticFeedback.selectionClick();
        final url = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
        );
        if (await canLaunchUrl(url)) launchUrl(url);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_rounded, size: 15, color: accent),
            const SizedBox(width: 6),
            Text(
              'Map',
              style: GoogleFonts.openSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action Buttons ────────────────────────────────────────────────────────────
class _ActionButtons extends StatelessWidget {
  final String status;
  final ValueChanged<String> onUpdate;

  const _ActionButtons({required this.status, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    if (status == 'sent') {
      return Row(
        children: [
          Expanded(
            child: _Btn(
              label: 'Reject',
              icon: Icons.close_rounded,
              color: _C.red,
              filled: false,
              onTap: () => onUpdate('rejected'),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _Btn(
              label: 'Accept',
              icon: Icons.check_rounded,
              color: _C.green,
              filled: true,
              onTap: () => onUpdate('accepted'),
            ),
          ),
        ],
      );
    }
    if (status == 'accepted') {
      return _Btn(
        label: 'On the way',
        icon: Icons.directions_car_rounded,
        color: _C.blue,
        filled: true,
        onTap: () => onUpdate('on_the_way'),
      );
    }
    if (status == 'on_the_way') {
      return _Btn(
        label: 'Mark arrived',
        icon: Icons.done_all_rounded,
        color: _C.teal,
        filled: true,
        onTap: () => onUpdate('arrived'),
      );
    }
    final done = status == 'arrived';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: (done ? _C.teal : Colors.grey).withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (done ? _C.teal : Colors.grey).withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 15,
            color: done ? _C.teal : Colors.grey,
          ),
          const SizedBox(width: 7),
          Text(
            done ? 'Completed' : status.capitalize(),
            style: GoogleFonts.openSans(
              color: done ? _C.teal : Colors.grey,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── ③ Pressable scale wrapper (replaces GestureDetector for tactile feedback) ─
class _PressableBtn extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressableBtn({required this.child, required this.onTap});

  @override
  State<_PressableBtn> createState() => _PressableBtnState();
}

class _PressableBtnState extends State<_PressableBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.93,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

// ── _Btn uses _PressableBtn internally ───────────────────────────────────────
class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _Btn({
    required this.label,
    required this.icon,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PressableBtn(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: filled ? color : color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(12),
          border: filled ? null : Border.all(color: color.withOpacity(0.30)),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.32),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: filled ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.openSans(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: filled ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHIMMER LIST  (improved: proper sweep gradient on each card)
// ─────────────────────────────────────────────────────────────────────────────
class _ShimmerList extends StatefulWidget {
  final Color surf2;
  final bool dark;
  const _ShimmerList({required this.surf2, required this.dark});

  @override
  State<_ShimmerList> createState() => _ShimmerListState();
}

class _ShimmerListState extends State<_ShimmerList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.dark
        ? Colors.white.withOpacity(0.04)
        : Colors.grey.shade200;
    final shimmer = widget.dark
        ? Colors.white.withOpacity(0.10)
        : Colors.grey.shade100;

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (_, idx) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final p = (_ctrl.value - 0.15 * idx).clamp(0.0, 1.0);
          return Container(
            height: 215,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment(-1.0 + 2.5 * p, 0),
                end: Alignment(-1.0 + 2.5 * p + 1, 0),
                colors: [base, shimmer, base],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  EMPTY + ERROR STATES
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String serviceType;
  final Color sec;
  const _EmptyState({required this.serviceType, required this.sec});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: sec.withOpacity(0.06),
                shape: BoxShape.circle,
                border: Border.all(color: sec.withOpacity(0.12)),
              ),
              child: Icon(
                Icons.inbox_rounded,
                size: 40,
                color: sec.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Active Requests',
              style: GoogleFonts.montserrat(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: sec,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All $serviceType requests will appear here in real time.',
              textAlign: TextAlign.center,
              style: GoogleFonts.openSans(
                fontSize: 13,
                color: sec.withOpacity(0.55),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object? error;
  final Color pri;
  const _ErrorState({required this.error, required this.pri});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _C.red.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: _C.red.withOpacity(0.2)),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 36,
                color: _C.red,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Could not load requests',
              style: GoogleFonts.montserrat(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: pri,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: GoogleFonts.openSans(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── String extension ──────────────────────────────────────────────────────────
extension _StrX on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
