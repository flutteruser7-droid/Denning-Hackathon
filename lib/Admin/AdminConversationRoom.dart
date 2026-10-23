// ============================================================================
//  admin_conversation_room.dart
//
//  Admin ↔ User Conversation Room
//
//  Features:
//  ✅ Text-only messaging (NO Firebase Storage, NO image picker)
//  ✅ Real-time StreamBuilder messages
//  ✅ isRead auto-updated when admin opens the room (clears unread badge)
//  ✅ Typing indicator (Firestore-based)
//  ✅ Online / Last-seen status
//  ✅ Message bubbles: sender (accent) / receiver (card bg)
//  ✅ Date separators
//  ✅ Auto-scroll to bottom on new message
//  ✅ Copy message on long-press
//  ✅ Delete own message on long-press
//  ✅ Full dark/light theme via appThemeNotifier — zero hardcoded colors
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emergency_app/Admin/AdminChatPage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// ── Import shared theme from your package:
// import 'package:emergency_app/shared/emergency_chat.dart';
// For self-containment, AppColors + appThemeNotifier are assumed available
// via admin_chat_page.dart or emergency_chat.dart in your project.
// If this file is compiled standalone, uncomment the block below:
//
// final ValueNotifier<ThemeMode> appThemeNotifier = ValueNotifier(ThemeMode.dark);
// (and paste in AppColors + roleAccent + roleIcon from admin_chat_page.dart)

// ─────────────────────────────────────────────────────────────────────────────
//  CONVERSATION SERVICE  — all Firestore logic here, zero in the UI
// ─────────────────────────────────────────────────────────────────────────────
class ConversationService {
  final _db = FirebaseFirestore.instance;
  final String myUid = FirebaseAuth.instance.currentUser!.uid;

  /// Deterministic room id
  String roomId(String otherUid) => myUid.compareTo(otherUid) <= 0
      ? '${myUid}_$otherUid'
      : '${otherUid}_$myUid';

  CollectionReference _msgs(String otherUid) => _db
      .collection('Chats')
      .doc(roomId(otherUid))
      .collection('messages');

  DocumentReference _room(String otherUid) =>
      _db.collection('Chats').doc(roomId(otherUid));

  DocumentReference _theirDoc(String otherUid) =>
      _db.collection('Users').doc(otherUid);

  DocumentReference _myDoc() =>
      _db.collection('Users').doc(myUid);

  // ── Real-time messages stream ────────────────────────────────────────────
  Stream<QuerySnapshot> messagesStream(String otherUid) => _msgs(otherUid)
      .orderBy('timestamp', descending: false)
      .snapshots();

  // ── Online / last-seen stream for the other user ─────────────────────────
  Stream<DocumentSnapshot> theirPresenceStream(String otherUid) =>
      _theirDoc(otherUid).snapshots();

  // ── Typing indicator stream ───────────────────────────────────────────────
  Stream<DocumentSnapshot> typingStream(String otherUid) =>
      _room(otherUid).snapshots();

  // ── Mark all messages FROM the user as read (clears unread badge) ────────
  Future<void> markAllRead(String otherUid) async {
    try {
      final unread = await _msgs(otherUid)
          .where('sender', isEqualTo: otherUid)
          .where('read', isEqualTo: false)
          .get();
      if (unread.docs.isEmpty) return;
      final batch = _db.batch();
      for (final d in unread.docs) {
        batch.update(d.reference, {'read': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  // ── Send a text message ───────────────────────────────────────────────────
  Future<void> sendMessage({
    required String otherUid,
    required String text,
    required String receiverName,
    required String receiverType,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _msgs(otherUid).add({
      'text'        : trimmed,
      'sender'      : myUid,
      'timestamp'   : FieldValue.serverTimestamp(),
      'type'        : 'text',
      'read'        : false,
      'reactions'   : {},
      'receiverName': receiverName,
      'receiverType': receiverType,
    });
  }

  // ── Delete own message ────────────────────────────────────────────────────
  Future<void> deleteMessage(String otherUid, String msgId) async {
    await _msgs(otherUid).doc(msgId).update({
      'deleted': true,
      'text'   : '',
    });
  }

  // ── Presence helpers ──────────────────────────────────────────────────────
  Future<void> setOnline(bool online) async {
    try {
      await _myDoc().set({
        'isOnline': online,
        if (!online) 'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> setTyping(String otherUid, bool typing) async {
    try {
      await _room(otherUid).set(
        {'typing_$myUid': typing},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ADMIN CONVERSATION ROOM
// ─────────────────────────────────────────────────────────────────────────────
class AdminConversationRoom extends StatefulWidget {
  final String userId;
  final String userName;
  final String role; // responder's role: 'Police' | 'Ambulance' | 'Fire Brigade'

  const AdminConversationRoom({
    super.key,
    required this.userId,
    required this.userName,
    required this.role,
  });

  @override
  State<AdminConversationRoom> createState() =>
      _AdminConversationRoomState();
}

class _AdminConversationRoomState extends State<AdminConversationRoom>
    with WidgetsBindingObserver {
  final _svc        = ConversationService();
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode  = FocusNode();

  bool      _isSending   = false;
  bool      _isTyping    = false;
  DateTime? _lastTyped;

  // ── Theme helpers ──────────────────────────────────────────────────────────
  bool get _dark => appThemeNotifier.value == ThemeMode.dark;

  Color get _accent    => roleAccent(widget.role);
  Color get _bgPage    => _dark ? AppColors.dBgPage    : AppColors.lBgPage;
  Color get _bgBody    => _dark ? AppColors.dBgBody    : AppColors.lBgBody;
  Color get _bgCard    => _dark ? AppColors.dBgCard    : AppColors.lBgCard;
  Color get _bgInput   => _dark ? AppColors.dBgInput   : AppColors.lBgInput;
  Color get _cardBdr   => _dark ? AppColors.dCardBdr   : AppColors.lCardBdr;
  Color get _txtPri    => _dark ? AppColors.dTxtPrimary: AppColors.lTxtPrimary;
  Color get _txtSec    => _dark ? AppColors.dTxtSec    : AppColors.lTxtSec;
  Color get _txtMuted  => _dark ? AppColors.dTxtMuted  : AppColors.lTxtMuted;
  Color get _divider   => _dark ? AppColors.dDivider   : AppColors.lDivider;

  // My bubble = accent, their bubble = card bg
  Color get _myBubble    => _accent;
  Color get _theirBubble => _dark
      ? const Color(0xFF1A2C4E)
      : AppColors.lBgCard;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _svc.setOnline(true);
    // Mark all incoming messages read immediately on open
    _svc.markAllRead(widget.userId);
    _msgCtrl.addListener(_onType);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused ||
        s == AppLifecycleState.detached) {
      _svc.setOnline(false);
    } else if (s == AppLifecycleState.resumed) {
      _svc.setOnline(true);
      _svc.markAllRead(widget.userId);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _svc.setOnline(false);
    _svc.setTyping(widget.userId, false);
    _msgCtrl.removeListener(_onType);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Typing debounce ────────────────────────────────────────────────────────
  void _onType() {
    final now = DateTime.now();
    if (!_isTyping) {
      _isTyping = true;
      _svc.setTyping(widget.userId, true);
    }
    _lastTyped = now;
    Future.delayed(const Duration(seconds: 2), () {
      if (_lastTyped == now && _isTyping && mounted) {
        _isTyping = false;
        _svc.setTyping(widget.userId, false);
      }
    });
  }

  // ── Send ───────────────────────────────────────────────────────────────────
  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _msgCtrl.clear();
    _isTyping = false;
    _svc.setTyping(widget.userId, false);

    try {
      await _svc.sendMessage(
        otherUid    : widget.userId,
        text        : text,
        receiverName: widget.userName,
        receiverType: widget.role,
      );
      _scrollToBottom();
    } catch (e) {
      _showSnack('Failed to send: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Auto scroll ────────────────────────────────────────────────────────────
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Snack ──────────────────────────────────────────────────────────────────
  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.errorRed : AppColors.ambulanceGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Long-press message options ─────────────────────────────────────────────
  void _onLongPress(String msgId, String text, bool isMe, bool deleted) {
    if (deleted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: _bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(
            width: 36, height: 4, margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
                color: _cardBdr,
                borderRadius: BorderRadius.circular(2)),
          ),
          // Copy
          _OptionRow(
            icon: Icons.copy_rounded,
            label: 'Copy message',
            color: _accent,
            txtPri: _txtPri,
            bgCard: _bgCard,
            onTap: () {
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: text));
              _showSnack('Copied to clipboard');
            },
          ),
          // Delete (own only)
          if (isMe) ...[
            const SizedBox(height: 6),
            _OptionRow(
              icon: Icons.delete_outline_rounded,
              label: 'Delete message',
              color: AppColors.errorRed,
              txtPri: _txtPri,
              bgCard: _bgCard,
              onTap: () async {
                Navigator.pop(context);
                await _svc.deleteMessage(widget.userId, msgId);
              },
            ),
          ],
        ]),
      ),
    );
  }

  // ── Toggle theme ───────────────────────────────────────────────────────────
  void _toggleTheme() {
    appThemeNotifier.value =
        _dark ? ThemeMode.light : ThemeMode.dark;
    setState(() {});
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
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
          resizeToAvoidBottomInset: true,
          body: Column(children: [
            _buildAppBar(),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: _bgBody,
                child: _buildMessageList(),
              ),
            ),
            _buildInputBar(),
          ]),
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end  : Alignment.bottomRight,
          colors: [AppColors.hdrFrom, AppColors.hdrTo],
        ),
        border: Border(
          bottom: BorderSide(color: Color(0x12FFFFFF), width: 0.5)),
      ),
      padding: EdgeInsets.fromLTRB(
          6, MediaQuery.of(context).padding.top + 10, 16, 14),
      child: Row(children: [
        // Back
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.maybePop(context),
        ),

        // Avatar
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end  : Alignment.bottomRight,
              colors: [
                _accent.withOpacity(0.85),
                _accent.withOpacity(0.50),
              ],
            ),
            border: Border.all(color: _accent.withOpacity(0.4), width: 1.5),
          ),
          child: Center(
            child: Text(
              widget.userName.isNotEmpty
                  ? widget.userName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Name + online / typing
        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: _svc.theirPresenceStream(widget.userId),
            builder: (_, snap) {
              final d = snap.data?.data() as Map<String, dynamic>? ?? {};
              final online   = d['isOnline']  as bool?      ?? false;
              final lastSeen = d['lastSeen']  as Timestamp?;

              return StreamBuilder<DocumentSnapshot>(
                stream: _svc.typingStream(widget.userId),
                builder: (_, rSnap) {
                  final room = rSnap.data?.data()
                      as Map<String, dynamic>? ?? {};
                  final theyTyping =
                      room['typing_${widget.userId}'] as bool? ?? false;

                  String sub;
                  Color subColor;
                  if (theyTyping) {
                    sub = 'Typing…';
                    subColor = AppColors.ambulanceGreen;
                  } else if (online) {
                    sub = 'Online';
                    subColor = AppColors.ambulanceGreen;
                  } else if (lastSeen != null) {
                    sub = 'Last seen ${DateFormat('hh:mm a').format(lastSeen.toDate())}';
                    subColor = Colors.white.withOpacity(0.45);
                  } else {
                    sub = 'Offline';
                    subColor = Colors.white.withOpacity(0.35);
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.userName,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 15,
                          fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                      const SizedBox(height: 2),
                      Text(sub,
                        style: TextStyle(
                          color: subColor, fontSize: 11,
                          fontStyle: theyTyping
                              ? FontStyle.italic
                              : FontStyle.normal,
                          fontWeight: FontWeight.w500,
                        )),
                    ],
                  );
                },
              );
            },
          ),
        ),

        // Theme toggle
        GestureDetector(
          onTap: _toggleTheme,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.09),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: Colors.white.withOpacity(0.13), width: 0.5),
            ),
            child: Icon(
              _dark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              color: _dark
                  ? const Color(0xFFFBBF24)
                  : Colors.white.withOpacity(0.8),
              size: 18,
            ),
          ),
        ),
      ]),
    );
  }

  // ── Message List ───────────────────────────────────────────────────────────
  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _svc.messagesStream(widget.userId),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
                color: _accent, strokeWidth: 2.5));
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _buildEmptyChat();
        }

        final docs = snap.data!.docs;

        // Mark incoming read every time new messages arrive
        _svc.markAllRead(widget.userId);
        _scrollToBottom();

        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc  = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final prev = i > 0
                ? docs[i - 1].data() as Map<String, dynamic>
                : null;

            return Column(children: [
              if (_showDateSep(data, prev))
                _buildDateSep(data['timestamp'] as Timestamp?),
              _buildBubble(doc.id, data),
            ]);
          },
        );
      },
    );
  }

  // ── Date separator logic ───────────────────────────────────────────────────
  bool _showDateSep(Map cur, Map? prev) {
    if (prev == null) return true;
    final a = (cur['timestamp']  as Timestamp?)?.toDate();
    final b = (prev['timestamp'] as Timestamp?)?.toDate();
    if (a == null || b == null) return false;
    return a.day != b.day || a.month != b.month || a.year != b.year;
  }

  Widget _buildDateSep(Timestamp? ts) {
    if (ts == null) return const SizedBox.shrink();
    final dt  = ts.toDate();
    final now = DateTime.now();
    String lbl;
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      lbl = 'Today';
    } else if (dt.day == now.day - 1 && dt.month == now.month) {
      lbl = 'Yesterday';
    } else {
      lbl = DateFormat('MMMM d, yyyy').format(dt);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        Expanded(child: Divider(color: _divider, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(lbl,
            style: TextStyle(
              color: _txtMuted, fontSize: 10.5,
              fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        ),
        Expanded(child: Divider(color: _divider, height: 1)),
      ]),
    );
  }

  // ── Single message bubble ──────────────────────────────────────────────────
  Widget _buildBubble(String msgId, Map<String, dynamic> data) {
    final deleted = data['deleted'] as bool?   ?? false;
    final sender  = data['sender']  as String? ?? '';
    final text    = data['text']    as String? ?? '';
    final ts      = data['timestamp'] as Timestamp?;
    final read    = data['read']    as bool?   ?? false;
    final isMe    = sender == _svc.myUid;
    final timeStr = ts != null
        ? DateFormat('hh:mm a').format(ts.toDate())
        : '';

    return GestureDetector(
      onLongPress: () => _onLongPress(msgId, text, isMe, deleted),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.74),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? _myBubble : _theirBubble,
                borderRadius: BorderRadius.only(
                  topLeft    : const Radius.circular(18),
                  topRight   : const Radius.circular(18),
                  bottomLeft : Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4  : 18),
                ),
                border: Border.all(
                  color: isMe
                      ? Colors.white.withOpacity(0.08)
                      : _cardBdr,
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Message text
                  if (deleted)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.not_interested_rounded,
                          size: 13,
                          color: isMe
                              ? Colors.white.withOpacity(0.5)
                              : _txtMuted),
                      const SizedBox(width: 5),
                      Text('Message deleted',
                        style: TextStyle(
                          color: isMe
                              ? Colors.white.withOpacity(0.5)
                              : _txtMuted,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        )),
                    ])
                  else
                    Text(text,
                      style: TextStyle(
                        color: isMe ? Colors.white : _txtPri,
                        fontSize: 14,
                        height: 1.45,
                        letterSpacing: 0.1,
                      )),

                  const SizedBox(height: 5),

                  // Time + read receipt
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(timeStr,
                        style: TextStyle(
                          color: isMe
                              ? Colors.white.withOpacity(0.55)
                              : _txtMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        )),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          read
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 14,
                          color: read
                              ? Colors.tealAccent
                              : Colors.white.withOpacity(0.4),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Empty chat placeholder ─────────────────────────────────────────────────
  Widget _buildEmptyChat() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 68, height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _accent.withOpacity(0.09),
            border: Border.all(color: _accent.withOpacity(0.2)),
          ),
          child: Icon(Icons.chat_bubble_outline_rounded,
              size: 28, color: _accent),
        ),
        const SizedBox(height: 14),
        Text('No messages yet',
          style: TextStyle(
            color: _txtPri, fontSize: 15,
            fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Start the conversation below',
          style: TextStyle(color: _txtSec, fontSize: 12)),
      ]),
    );
  }

  // ── Input bar (text-only — NO attachment button) ───────────────────────────
  Widget _buildInputBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: _bgCard,
        border: Border(top: BorderSide(color: _cardBdr, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        14, 10, 14,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Text field ─────────────────────────────────────────────────
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _bgInput,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _cardBdr, width: 0.5),
              ),
              child: TextField(
                controller: _msgCtrl,
                focusNode : _focusNode,
                maxLines  : 5,
                minLines  : 1,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  color: _txtPri, fontSize: 14,
                  fontWeight: FontWeight.w400),
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  hintStyle: TextStyle(color: _txtMuted, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 11),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // ── Send button ────────────────────────────────────────────────
          GestureDetector(
            onTap: _isSending ? null : _send,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46, height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end  : Alignment.bottomRight,
                  colors: [
                    _accent,
                    Color.lerp(_accent, Colors.black, 0.22)!,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withOpacity(0.40),
                    blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.2))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 19),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  OPTION ROW  — used in long-press bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _OptionRow extends StatelessWidget {
  final IconData   icon;
  final String     label;
  final Color      color, txtPri, bgCard;
  final VoidCallback onTap;

  const _OptionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.txtPri,
    required this.bgCard,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: color.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 4, vertical: 10),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Text(label,
              style: TextStyle(
                color: txtPri, fontSize: 14,
                fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}