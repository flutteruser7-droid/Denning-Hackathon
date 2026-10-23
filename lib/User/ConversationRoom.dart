// ignore_for_file: file_names

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  CONVERSATION ROOM  — User ↔ Emergency Service Chat
//  Features:
//    ✅ Dark / Light mode (SharedPrefs, same palette as LoginPage/ChatPage)
//    ✅ Real-time messages via Firestore StreamBuilder
//    ✅ Send text messages
//    ✅ Send images (Firebase Storage)
//    ✅ Reply-to-message (swipe right)
//    ✅ Emoji reactions (long-press)
//    ✅ Typing indicator
//    ✅ Read receipts (double-tick)
//    ✅ Online / Last-seen status
//    ✅ Copy message on long-press
//    ✅ Delete own message (swipe left)
//    ✅ Date separators between messages
//    ✅ Auto-scroll to bottom on new message
// ═══════════════════════════════════════════════════════════════════════════

class ConversationRoom extends StatefulWidget {
  final String userId; // the OTHER person's uid
  final String userName;
  final String userImage;
  final String receiverType; // <-- NEW: Add this to hold the service type

  const ConversationRoom({
    super.key,
    required this.userId,
    required this.userName,
    required this.userImage,
    required this.receiverType, // <-- NEW: Require it when opening the page
  });

  @override
  State<ConversationRoom> createState() => _ConversationRoomState();
}

class _ConversationRoomState extends State<ConversationRoom>
    with WidgetsBindingObserver {
  // ── Firebase ───────────────────────────────────────────────────────────────
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();
  final String _me = FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Controllers ────────────────────────────────────────────────────────────
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();

  // ── State ──────────────────────────────────────────────────────────────────
  bool _isUploading = false;
  bool _isDarkMode = true;

  // Reply
  Map<String, dynamic>? _replyTo; // {text, sender, msgId}

  // Typing debounce
  bool _isTyping = false;
  DateTime? _lastTypingTime;

  // ══════════════════════════════════════════════════════════════════════════
  //  THEME TOKENS — identical to LoginPage / ChatPage palette
  // ══════════════════════════════════════════════════════════════════════════

  // dark
  static const _dBgPage = Color(0xFF04091A);
  static const _dBgCard = Color(0xFF0D1625);
  static const _dInputBg = Color(0xFF101F35);
  static const _dBorder = Color(0xFF1E3A5A);
  static const _dHdrFrom = Color(0xFF071D3F);
  static const _dHdrTo = Color(0xFF0A2550);
  static const _dTxtPri = Color(0xFFEAF0FB);
  static const _dTxtSec = Color(0xFF5A7FA0);
  static const _dTxtMuted = Color(0xFF3D6080);
  static const _dDivider = Color(0x0DFFFFFF);

  // light
  static const _lBgPage = Color(0xFFE8EEF8);
  static const _lBgCard = Color(0xFFFFFFFF);
  static const _lInputBg = Color(0xFFF5F9FF);
  static const _lBorder = Color(0xFFD4E2F5);
  static const _lTxtPri = Color(0xFF071830);
  static const _lTxtSec = Color(0xFF8FA2B5);
  static const _lTxtMuted = Color(0xFFB0C0D0);
  static const _lDivider = Color(0xFFEFF4FC);

  // accents (mode-independent)
  static const _cNavy1 = Color(0xFF071D3F);
  static const _cNavy2 = Color(0xFF1A3A72);
  static const _cGreen = Color(0xFF10B981);
  static const _cRed = Color(0xFFE53E3E);
  static const _cAmber = Color(0xFFF59E0B);

  // ── Getters ────────────────────────────────────────────────────────────────
  Color get bgPage => _isDarkMode ? _dBgPage : _lBgPage;
  Color get bgCard => _isDarkMode ? _dBgCard : _lBgCard;
  Color get inputBg => _isDarkMode ? _dInputBg : _lInputBg;
  Color get border => _isDarkMode ? _dBorder : _lBorder;
  Color get txtPri => _isDarkMode ? _dTxtPri : _lTxtPri;
  Color get txtSec => _isDarkMode ? _dTxtSec : _lTxtSec;
  Color get txtMuted => _isDarkMode ? _dTxtMuted : _lTxtMuted;
  Color get divClr => _isDarkMode ? _dDivider : _lDivider;

  // My bubble vs their bubble
  Color get _myBubble => _isDarkMode ? _cNavy2 : const Color(0xFF0F2550);
  Color get _theirBubble => _isDarkMode ? _dBgCard : _lBgCard;

  // ══════════════════════════════════════════════════════════════════════════
  //  FIRESTORE PATHS
  // ══════════════════════════════════════════════════════════════════════════

  /// Deterministic room ID: sort UIDs so both sides agree
  String get _roomId => _me.compareTo(widget.userId) <= 0
      ? '${_me}_${widget.userId}'
      : '${widget.userId}_${_me}';

  CollectionReference get _msgs =>
      _firestore.collection('Chats').doc(_roomId).collection('messages');

  DocumentReference get _roomDoc => _firestore.collection('Chats').doc(_roomId);

  DocumentReference get _myUserDoc => _firestore.collection('users').doc(_me);

  DocumentReference get _theirUserDoc =>
      _firestore.collection('users').doc(widget.userId);

  // ══════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTheme();
    _setOnline(true);
    _markRoomSeen();
    _msgCtrl.addListener(_onTextChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _setOnline(false);
    } else if (state == AppLifecycleState.resumed) {
      _setOnline(true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setOnline(false);
    _setTyping(false);
    _msgCtrl.removeListener(_onTextChanged);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  THEME LOADER
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadTheme() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => _isDarkMode = p.getBool('isDarkMode') ?? true);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PRESENCE & TYPING
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _setOnline(bool online) async {
    try {
      await _myUserDoc.set({
        'isOnline': online,
        if (!online) 'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Called whenever the text field changes
  void _onTextChanged() {
    final now = DateTime.now();
    if (!_isTyping) {
      _isTyping = true;
      _setTyping(true);
    }
    _lastTypingTime = now;
    // Stop typing indicator 2 s after last keystroke
    Future.delayed(const Duration(seconds: 2), () {
      if (_lastTypingTime != null && now == _lastTypingTime && _isTyping) {
        _isTyping = false;
        _setTyping(false);
      }
    });
  }

  Future<void> _setTyping(bool typing) async {
    try {
      await _roomDoc.set({'typing_${_me}': typing}, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Mark all their messages as read
  Future<void> _markRoomSeen() async {
    try {
      final unread = await _msgs
          .where('sender', isEqualTo: widget.userId)
          .where('read', isEqualTo: false)
          .get();
      final batch = _firestore.batch();
      for (final d in unread.docs) {
        batch.update(d.reference, {'read': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SEND MESSAGE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _sendText() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    _msgCtrl.clear();
    _isTyping = false;
    _setTyping(false);

    // Assuming you have variables like these available in your state/widget:
    // String receiverName = widget.receiverName;
    // String receiverType = widget.receiverType; // e.g., "Fire Brigade", "Police", "Ambulance"

    final data = <String, dynamic>{
      'type': 'text',
      'text': text,
      'sender': _me,
      'receiverName': widget.userName, // <-- FIXED: Added widget.userName
      'receiverType':
          widget.receiverType, // <-- FIXED: Added widget.receiverType
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'reactions': {},
    };

    if (_replyTo != null) {
      data['replyTo'] = _replyTo;
      setState(() => _replyTo = null);
    }

    await _msgs.add(data);
    _scrollToBottom();
  }

  Future<void> _sendImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final ref = _storage.ref().child(
        'chat_images/$_roomId/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();

      await _msgs.add({
        'type': 'image',
        'imageUrl': url,
        'text': '',
        'sender': _me,
        'receiverName': widget.userName, // <-- FIXED: Added widget.userName
        'receiverType':
            widget.receiverType, // <-- FIXED: Added widget.receiverType
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'reactions': {},
      });
      _scrollToBottom();
    } catch (e) {
      _showSnack('Image upload failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Scroll helper ──────────────────────────────────────────────────────────
  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        if (animated) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  REACTIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _addReaction(String msgId, String emoji) async {
    try {
      await _msgs.doc(msgId).update({'reactions.$_me': emoji});
    } catch (_) {}
  }

  void _showReactionPicker(String msgId) {
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    showModalBottomSheet(
      context: context,
      backgroundColor: bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'React',
              style: TextStyle(
                color: txtPri,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: emojis
                  .map(
                    (e) => GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _addReaction(msgId, e);
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border),
                        ),
                        child: Center(
                          child: Text(e, style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DELETE MESSAGE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _deleteMessage(String msgId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Delete message?',
          style: TextStyle(
            color: txtPri,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This message will be removed for everyone.',
          style: TextStyle(color: txtSec, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: txtSec)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: _cRed, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _msgs.doc(msgId).update({'deleted': true, 'text': ''});
    }
  }

  // ── Snackbar ───────────────────────────────────────────────────────────────
  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? _cRed : _cGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      _isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      color: bgPage,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            _buildAppBar(),
            Expanded(child: _buildMessageList()),
            if (_replyTo != null) _buildReplyPreview(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  APP BAR
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAppBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cNavy1, _cNavy2],
        ),
        border: Border(
          bottom: BorderSide(color: Color(0x12FFFFFF), width: 0.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        8,
        MediaQuery.of(context).padding.top + 10,
        16,
        14,
      ),
      child: Row(
        children: [
          // Back
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 18,
            ),
            onPressed: () => Navigator.pop(context),
          ),

          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _cNavy2,
              border: Border.all(color: Colors.white24, width: 1.5),
            ),
            child: Center(
              child: Text(
                widget.userName.isNotEmpty
                    ? widget.userName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Name + online status
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _theirUserDoc.snapshots(),
              builder: (_, snap) {
                final d = snap.data?.data() as Map<String, dynamic>? ?? {};
                final online = d['isOnline'] as bool? ?? false;
                final lastSeen = d['lastSeen'] as Timestamp?;

                String subtitle;
                if (online) {
                  subtitle = 'Online';
                } else if (lastSeen != null) {
                  subtitle =
                      'Last seen ${DateFormat('hh:mm a').format(lastSeen.toDate())}';
                } else {
                  subtitle = 'Offline';
                }

                // Also check typing
                return StreamBuilder<DocumentSnapshot>(
                  stream: _roomDoc.snapshots(),
                  builder: (_, roomSnap) {
                    final room =
                        roomSnap.data?.data() as Map<String, dynamic>? ?? {};
                    final theirTyping =
                        room['typing_${widget.userId}'] as bool? ?? false;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          theirTyping ? 'Typing...' : subtitle,
                          style: TextStyle(
                            color: theirTyping
                                ? _cGreen
                                : Colors.white.withOpacity(0.5),
                            fontSize: 11,
                            fontStyle: theirTyping
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Dark mode toggle
          _buildToggle(),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return GestureDetector(
      onTap: () async {
        final p = await SharedPreferences.getInstance();
        setState(() => _isDarkMode = !_isDarkMode);
        await p.setBool('isDarkMode', _isDarkMode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 48,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: _isDarkMode ? _cNavy2 : const Color(0xFFE2E8F0),
          border: Border.all(
            color: _isDarkMode ? Colors.white24 : Colors.black12,
          ),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: _isDarkMode ? 24 : 2,
              top: 2,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isDarkMode ? Colors.tealAccent : _cNavy2,
                ),
                child: Icon(
                  _isDarkMode ? Icons.nightlight_round : Icons.wb_sunny,
                  size: 12,
                  color: _isDarkMode ? const Color(0xFF060E1F) : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  MESSAGE LIST
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _msgs.orderBy('timestamp').snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: _cNavy2, strokeWidth: 2.5),
          );
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _buildEmptyChat();
        }

        final docs = snap.data!.docs;

        // Mark incoming as read
        _markRoomSeen();

        // Scroll on new message
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final prev = i > 0
                ? docs[i - 1].data() as Map<String, dynamic>
                : null;

            final showDate = _shouldShowDate(data, prev);

            return Column(
              children: [
                if (showDate)
                  _buildDateSeparator(data['timestamp'] as Timestamp?),
                _buildMessageTile(doc.id, data),
              ],
            );
          },
        );
      },
    );
  }

  bool _shouldShowDate(Map<String, dynamic> cur, Map<String, dynamic>? prev) {
    if (prev == null) return true;
    final curTs = cur['timestamp'] as Timestamp?;
    final prevTs = prev['timestamp'] as Timestamp?;
    if (curTs == null || prevTs == null) return false;
    final curDate = curTs.toDate();
    final prevDate = prevTs.toDate();
    return curDate.day != prevDate.day ||
        curDate.month != prevDate.month ||
        curDate.year != prevDate.year;
  }

  Widget _buildDateSeparator(Timestamp? ts) {
    if (ts == null) return const SizedBox.shrink();
    final date = ts.toDate();
    final now = DateTime.now();
    String label;
    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      label = 'Today';
    } else if (date.day == now.day - 1 && date.month == now.month) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMMM d, yyyy').format(date);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: divClr, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                color: txtMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: divClr, height: 1)),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: inputBg,
              border: Border.all(color: border),
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 32,
              color: txtMuted,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No messages yet',
            style: TextStyle(
              color: txtPri,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Start the conversation',
            style: TextStyle(color: txtMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SINGLE MESSAGE TILE
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMessageTile(String msgId, Map<String, dynamic> data) {
    final deleted = data['deleted'] as bool? ?? false;
    final sender = data['sender'] as String? ?? '';
    final isMe = sender == _me;
    final msgType = data['type'] as String? ?? 'text';
    final text = data['text'] as String? ?? '';
    final imageUrl = data['imageUrl'] as String? ?? '';
    final ts = data['timestamp'] as Timestamp?;
    final read = data['read'] as bool? ?? false;
    final reactions = data['reactions'] as Map<String, dynamic>? ?? {};
    final replyTo = data['replyTo'] as Map<String, dynamic>?;
    final timeStr = ts != null ? DateFormat('hh:mm a').format(ts.toDate()) : '';

    // Swipe: right = reply, left = delete (only own msgs)
    return Dismissible(
      key: ValueKey(msgId),
      direction: isMe
          ? DismissDirection.horizontal
          : DismissDirection.startToEnd,
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          // Reply
          setState(
            () => _replyTo = {
              'msgId': msgId,
              'text': deleted
                  ? '🗑 Deleted'
                  : (msgType == 'image' ? '📷 Image' : text),
              'sender': isMe ? 'You' : widget.userName,
            },
          );
          _focusNode.requestFocus();
          return false;
        } else {
          // Delete (only own)
          if (!isMe) return false;
          await _deleteMessage(msgId);
          return false;
        }
      },
      background: _swipeBg(Icons.reply_rounded, _cNavy2, Alignment.centerLeft),
      secondaryBackground: isMe
          ? _swipeBg(Icons.delete_outline_rounded, _cRed, Alignment.centerRight)
          : const SizedBox.shrink(),
      child: GestureDetector(
        onLongPress: () => _showMsgOptions(msgId, text, isMe, deleted, msgType),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Bubble
                  Container(
                    decoration: BoxDecoration(
                      color: isMe ? _myBubble : _theirBubble,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      border: Border.all(
                        color: isMe ? Colors.white.withOpacity(0.08) : border,
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Reply preview
                        if (replyTo != null) _buildReplyBadge(replyTo),

                        // Content
                        if (deleted)
                          Row(
                            children: [
                              Icon(
                                Icons.not_interested_rounded,
                                size: 14,
                                color: txtMuted,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Message deleted',
                                style: TextStyle(
                                  color: txtMuted,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          )
                        else if (msgType == 'image' && imageUrl.isNotEmpty)
                          _buildImageContent(imageUrl)
                        else
                          Text(
                            text,
                            style: TextStyle(
                              color: isMe ? Colors.white : txtPri,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),

                        // Time + read receipt
                        const SizedBox(height: 5),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timeStr,
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white.withOpacity(0.5)
                                    : txtMuted,
                                fontSize: 10,
                              ),
                            ),
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

                  // Reactions row
                  if (reactions.isNotEmpty) _buildReactions(msgId, reactions),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _swipeBg(IconData icon, Color color, Alignment align) {
    return Container(
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _buildReplyBadge(Map<String, dynamic> reply) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: _cGreen, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply['sender'] as String? ?? '',
            style: TextStyle(
              color: _cGreen,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            reply['text'] as String? ?? '',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: 200,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Container(
                width: 200,
                height: 140,
                color: inputBg,
                child: Center(
                  child: CircularProgressIndicator(
                    color: _cNavy2,
                    strokeWidth: 2,
                  ),
                ),
              ),
        errorBuilder: (_, __, ___) => Container(
          width: 200,
          height: 100,
          color: inputBg,
          child: Icon(Icons.broken_image_outlined, color: txtMuted, size: 32),
        ),
      ),
    );
  }

  Widget _buildReactions(String msgId, Map<String, dynamic> reactions) {
    // Group: emoji → count
    final Map<String, int> grouped = {};
    reactions.forEach((_, v) {
      final e = v as String;
      grouped[e] = (grouped[e] ?? 0) + 1;
    });
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        children: grouped.entries.map((e) {
          return GestureDetector(
            onTap: () => _addReaction(msgId, e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: border, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e.key, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text(
                    '${e.value}',
                    style: TextStyle(
                      color: txtSec,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Message long-press options ─────────────────────────────────────────────
  void _showMsgOptions(
    String msgId,
    String text,
    bool isMe,
    bool deleted,
    String type,
  ) {
    if (deleted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // React
            _OptionTile(
              icon: Icons.emoji_emotions_outlined,
              label: 'React',
              color: _cAmber,
              bgIco: inputBg,
              txtPri: txtPri,
              onTap: () {
                Navigator.pop(context);
                _showReactionPicker(msgId);
              },
            ),

            // Reply
            _OptionTile(
              icon: Icons.reply_rounded,
              label: 'Reply',
              color: _cNavy2,
              bgIco: inputBg,
              txtPri: txtPri,
              onTap: () {
                Navigator.pop(context);
                setState(
                  () => _replyTo = {
                    'msgId': msgId,
                    'text': type == 'image' ? '📷 Image' : text,
                    'sender': isMe ? 'You' : widget.userName,
                  },
                );
                _focusNode.requestFocus();
              },
            ),

            // Copy (text only)
            if (type == 'text' && text.isNotEmpty)
              _OptionTile(
                icon: Icons.copy_rounded,
                label: 'Copy',
                color: _cGreen,
                bgIco: inputBg,
                txtPri: txtPri,
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: text));
                  _showSnack('Copied to clipboard');
                },
              ),

            // Delete (own only)
            if (isMe)
              _OptionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: _cRed,
                bgIco: inputBg,
                txtPri: txtPri,
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(msgId);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  REPLY PREVIEW BANNER
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildReplyPreview() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: inputBg,
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: _cGreen,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${_replyTo!['sender']}',
                  style: TextStyle(
                    color: _cGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyTo!['text'] as String? ?? '',
                  style: TextStyle(color: txtSec, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: txtMuted, size: 18),
            onPressed: () => setState(() => _replyTo = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  INPUT BAR
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildInputBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      color: bgPage,
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Image picker
          // GestureDetector(
          //   onTap: _sendImage,
          //   child: AnimatedContainer(
          //     duration: const Duration(milliseconds: 200),
          //     width: 44,
          //     height: 44,
          //     decoration: BoxDecoration(
          //       color: inputBg,
          //       borderRadius: BorderRadius.circular(14),
          //       border: Border.all(color: border),
          //     ),
          //     child: _isUploading
          //         ? Padding(
          //             padding: const EdgeInsets.all(12),
          //             child: CircularProgressIndicator(
          //               color: _cNavy2,
          //               strokeWidth: 2,
          //             ),
          //           )
          //         // : Icon(Icons.image_outlined, color: txtSec, size: 20),
          //   ),
          // ),
          const SizedBox(width: 8),

          // Text input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border, width: 1),
              ),
              child: TextField(
                controller: _msgCtrl,
                focusNode: _focusNode,
                style: TextStyle(color: txtPri, fontSize: 14),
                maxLines: 5,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: txtMuted, fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendText(),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          GestureDetector(
            onTap: _sendText,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [_cNavy1, _cNavy2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x590F2550),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  OPTION TILE  — used in bottom sheet
// ══════════════════════════════════════════════════════════════════════════════
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bgIco, txtPri;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgIco,
    required this.txtPri,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: txtPri,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
