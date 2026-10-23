// ============================================================
//  User/emergency_contacts.dart
//  Beautiful Emergency Contacts page.
//  — Role-based colour branding (Ambulance=Green, Police=Blue,
//    Fire=Red)
//  — Reacts instantly to global dark-mode toggle
//  — No Firebase Storage, no image picking
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:emergency_app/theme/darkmode.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyContactsPage extends StatelessWidget {
  const EmergencyContactsPage({super.key});

  // ── static contact data ─────────────────────────────────────
  static const _contacts = [
    _ContactGroup(
      service:     'Ambulance',
      subtitle:    'Medical Emergency Services',
      icon:        Icons.local_hospital_rounded,
      roleKey:     'ambulance',
      numbers: [
        _Contact('1122',    'Rescue Emergency',     true),
        _Contact('115',     'Edhi Foundation',      false),
        _Contact('021-111', 'Chippa Ambulance',     false),
      ],
      tips: [
        'Stay calm and speak clearly',
        'Give your exact location',
        'Do not move an injured person',
        'Keep the line open until help arrives',
      ],
    ),
    _ContactGroup(
      service:     'Police',
      subtitle:    'Law Enforcement & Security',
      icon:        Icons.shield_rounded,
      roleKey:     'police',
      numbers: [
        _Contact('15',      'Emergency Helpline',   true),
        _Contact('021-9221322', 'Karachi Police HQ',false),
        _Contact('1746',    'Women Safety Helpline', false),
      ],
      tips: [
        'Note any suspect description',
        'Do not confront the suspect',
        'Secure yourself before calling',
        'File an FIR for documentation',
      ],
    ),
    _ContactGroup(
      service:     'Fire Brigade',
      subtitle:    'Fire & Rescue Services',
      icon:        Icons.local_fire_department_rounded,
      roleKey:     'fire',
      numbers: [
        _Contact('1122',    'Fire & Rescue',        true),
        _Contact('16',      'Fire Brigade Hotline', false),
        _Contact('021-32262626', 'Karachi Fire Dept', false),
      ],
      tips: [
        'Evacuate immediately — do not use lifts',
        'Crawl low under smoke',
        'Close doors to slow fire spread',
        'Do not re-enter a burning building',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final ec     = context.ec;

    SystemChrome.setSystemUIOverlayStyle(
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      color: ec.bodyBg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(context, isDark),
        body: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: _contacts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (ctx, i) =>
              _ContactCard(group: _contacts[i], isDark: isDark, ec: ec),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF071D3F), const Color(0xFF0A2550)]
                : [const Color(0xFF1565C0), const Color(0xFF1976D2)],
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Emergency Contacts',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      actions: [
        // dark-mode toggle in app bar
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => context.themeNotifier.toggle(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 50, height: 26,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: isDark
                    ? const Color(0xFF1A3A72)
                    : Colors.white.withOpacity(0.25),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Stack(children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  left: isDark ? 26 : 2, top: 2,
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.tealAccent : Colors.white,
                    ),
                    child: Icon(
                      isDark ? Icons.nightlight_round : Icons.wb_sunny,
                      size: 12,
                      color: isDark ? const Color(0xFF060E1F) : const Color(0xFF1565C0),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Single contact group card ────────────────────────────────
class _ContactCard extends StatefulWidget {
  final _ContactGroup group;
  final bool isDark;
  final EmergencyColors ec;
  const _ContactCard({required this.group, required this.isDark, required this.ec});

  @override
  State<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<_ContactCard> {
  bool _tipsExpanded = false;

  Color get primary {
    switch (widget.group.roleKey) {
      case 'ambulance': return widget.ec.ambulancePrimary;
      case 'police':    return widget.ec.policePrimary;
      default:          return widget.ec.firePrimary;
    }
  }

  Color get cardBg {
    switch (widget.group.roleKey) {
      case 'ambulance': return widget.ec.ambulanceBg;
      case 'police':    return widget.ec.policeBg;
      default:          return widget.ec.fireBg;
    }
  }

  Color get border {
    switch (widget.group.roleKey) {
      case 'ambulance': return widget.ec.ambulanceBdr;
      case 'police':    return widget.ec.policeBdr;
      default:          return widget.ec.fireBdr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        color: widget.ec.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.ec.cardBdr, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(widget.isDark ? 0.08 : 0.06),
            blurRadius: 20, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header strip ──────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary.withOpacity(0.15), primary.withOpacity(0.05)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              border: Border(bottom: BorderSide(color: border, width: 0.5)),
            ),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: border, width: 1),
                ),
                child: Icon(widget.group.icon, color: primary, size: 24),
              ),
              const SizedBox(width: 13),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.group.service,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                    color: primary)),
                const SizedBox(height: 2),
                Text(widget.group.subtitle,
                  style: TextStyle(fontSize: 11,
                    color: widget.isDark
                        ? Colors.white.withOpacity(0.45)
                        : const Color(0xFF8FA2B5))),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: primary.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Container(width: 6, height: 6,
                    decoration: BoxDecoration(color: primary, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text('24/7', style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w700, color: primary)),
                ]),
              ),
            ]),
          ),

          // ── Phone numbers ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text('CONTACT NUMBERS',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: widget.isDark
                    ? Colors.white.withOpacity(0.35)
                    : const Color(0xFF8FA2B5))),
          ),
          ...widget.group.numbers.map((c) => _NumberRow(
              contact: c, primary: primary, isDark: widget.isDark, ec: widget.ec)),

          // ── Safety tips toggle ────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _tipsExpanded = !_tipsExpanded),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border, width: 0.5),
              ),
              child: Row(children: [
                Icon(Icons.lightbulb_outline, size: 15, color: primary),
                const SizedBox(width: 8),
                Text('Safety Tips',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: primary)),
                const Spacer(),
                AnimatedRotation(
                  turns: _tipsExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(Icons.keyboard_arrow_down, size: 18, color: primary),
                ),
              ]),
            ),
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: _tipsExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.group.tips.map((t) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                            width: 6, height: 6,
                            decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(t,
                            style: TextStyle(fontSize: 12.5, height: 1.45,
                              color: widget.isDark
                                  ? Colors.white.withOpacity(0.65)
                                  : const Color(0xFF4A5568)))),
                        ]),
                      )).toList(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 14),
        ]),
      ),
    );
  }
}

// ── Number row with tap-to-call copy ────────────────────────
class _NumberRow extends StatelessWidget {
  final _Contact contact;
  final Color primary;
  final bool isDark;
  final EmergencyColors ec;

  const _NumberRow({
    required this.contact, required this.primary,
    required this.isDark, required this.ec,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse('tel:${contact.number}');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          Clipboard.setData(ClipboardData(text: contact.number));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${contact.number} copied to clipboard'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ));
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: contact.isPrimary ? primary.withOpacity(0.4) : ec.cardBdr,
            width: contact.isPrimary ? 1 : 0.5,
          ),
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.phone_rounded, size: 15, color: primary),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(contact.label,
              style: TextStyle(fontSize: 11,
                color: isDark
                    ? Colors.white.withOpacity(0.45)
                    : const Color(0xFF8FA2B5))),
            const SizedBox(height: 1),
            Text(contact.number,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF071830),
                letterSpacing: 0.3)),
          ])),
          if (contact.isPrimary)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('PRIMARY', style: TextStyle(fontSize: 8,
                fontWeight: FontWeight.w800, color: primary, letterSpacing: 0.5)),
            ),
          const SizedBox(width: 8),
          Icon(Icons.copy_rounded, size: 14,
            color: isDark
                ? Colors.white.withOpacity(0.25)
                : const Color(0xFFAABDCE)),
        ]),
      ),
    );
  }
}

// ── Data models ──────────────────────────────────────────────
class _ContactGroup {
  final String service, subtitle, roleKey;
  final IconData icon;
  final List<_Contact> numbers;
  final List<String> tips;
  const _ContactGroup({
    required this.service, required this.subtitle, required this.icon,
    required this.roleKey, required this.numbers, required this.tips,
  });
}

class _Contact {
  final String number, label;
  final bool isPrimary;
  const _Contact(this.number, this.label, this.isPrimary);
}
class EmergencyColors {
  final bool isDark;
  EmergencyColors(this.isDark);

  Color get bodyBg => isDark ? const Color(0xFF071830) : const Color(0xFFE9EEF5);
  Color get cardBg => isDark ? Colors.white.withOpacity(0.04) : Colors.white;
  Color get cardBdr => isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFD6E0EC);

  Color get ambulancePrimary => const Color(0xFF10B981);
  Color get policePrimary    => const Color(0xFF3B82F6);
  Color get firePrimary      => const Color(0xFFEF4444);

  Color get ambulanceBg => isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
  Color get policeBg    => isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);
  Color get fireBg      => isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);

  Color get ambulanceBdr => isDark ? const Color(0xFF059669) : const Color(0xFF6EE7B7);
  Color get policeBdr    => isDark ? const Color(0xFF2563EB) : const Color(0xFF93C5FD);
  Color get fireBdr      => isDark ? const Color(0xFFDC2626) : const Color(0xFFFCA5A5);
}

extension EmergencyContextExt on BuildContext {
  EmergencyColors get ec => EmergencyColors(isDarkMode);
}
