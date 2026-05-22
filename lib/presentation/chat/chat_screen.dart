import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/chat_service.dart';
import '../../data/services/ride_service.dart';
import '../../data/models/ride_model.dart';

class ChatScreen extends StatefulWidget {
  final String rideId;
  const ChatScreen({super.key, required this.rideId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller      = TextEditingController();
  final _scrollController = ScrollController();
  final _chatService     = ChatService();
  final _rideService     = RideService();

  RideModel? _ride;
  String? _passengerPhone;
  String? _driverPhone;
  bool _sending = false;

  String get _myUid   => FirebaseAuth.instance.currentUser?.uid   ?? '';
  String get _myName  => FirebaseAuth.instance.currentUser?.displayName ?? 'Me';
  String get _myPhoto => FirebaseAuth.instance.currentUser?.photoURL    ?? '';

  @override
  void initState() {
    super.initState();
    _loadRide();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRide() async {
    final ride = await _rideService.getRideById(widget.rideId);
    if (!mounted) return;
    // Access control — only driver or accepted passengers can open chat
    if (ride != null) {
      final isDriver    = ride.driverId == _myUid;
      final isPassenger = ride.passengerIds.contains(_myUid);
      if (!isDriver && !isPassenger) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('You are not part of this ride.'),
              backgroundColor: Colors.red,
            ));
            Navigator.of(context).pop();
          }
        });
        return;
      }
    }
    setState(() => _ride = ride);

    if (ride != null) {
      if (ride.driverId == _myUid && ride.passengerIds.isNotEmpty) {
        // Driver: fetch first passenger's phone
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(ride.passengerIds.first)
              .get();
          if (mounted && doc.exists) {
            setState(() => _passengerPhone = doc.data()?['phone'] as String?);
          }
        } catch (_) {}
      } else if (ride.driverId != _myUid) {
        // Passenger: fetch driver's phone from users collection
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(ride.driverId)
              .get();
          if (mounted && doc.exists) {
            setState(() => _driverPhone = doc.data()?['phone'] as String?);
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      await _chatService.sendMessage(
        rideId:      widget.rideId,
        senderId:    _myUid,
        senderName:  _myName,
        senderPhoto: _myPhoto.isNotEmpty ? _myPhoto : null,
        text:        text,
      );
      _rideService.notifyMessage(
        rideId:     widget.rideId,
        senderId:   _myUid,
        senderName: _myName,
        message:    text,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _callContact() async {
    final phone = _isDriver ? _passengerPhone : (_driverPhone ?? _ride?.driverPhone);
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isDriver
              ? 'Passenger phone number not available'
              : 'Driver phone number not available'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    // Strip everything except digits and leading +
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open dialer. Please dial manually.'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  bool get _isDriver => _ride?.driverId == _myUid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ride Chat', style: TextStyle(fontSize: 16)),
            Text(
              _ride != null
                  ? '${_ride!.startPoint.address.split(',').first} → ${_ride!.endPoint.address.split(',').first}'
                  : 'All passengers & driver',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMedium),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Passenger calls driver, driver calls passenger
          if (_ride != null)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone, color: AppTheme.success, size: 20),
              ),
              onPressed: _callContact,
              tooltip: _isDriver ? 'Call passenger' : 'Call driver',
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── Message list ─────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.streamMessages(widget.rideId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  );
                }
                final messages = snap.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: AppTheme.bgWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Icon(Icons.chat_bubble_outline,
                            color: AppTheme.textLight, size: 28),
                      ),
                      const SizedBox(height: 12),
                      const Text('No messages yet',
                          style: TextStyle(color: AppTheme.textMedium, fontSize: 14)),
                      const SizedBox(height: 4),
                      const Text('Start the conversation!',
                          style: TextStyle(color: AppTheme.textLight, fontSize: 12)),
                    ]),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg  = messages[i];
                    final isMe = msg.senderId == _myUid;

                    // Date divider
                    bool showDate = false;
                    if (i == 0) {
                      showDate = true;
                    } else {
                      final prev = messages[i - 1];
                      showDate = !_sameDay(prev.sentAt, msg.sentAt);
                    }

                    return Column(
                      children: [
                        if (showDate) _DateDivider(date: msg.sentAt),
                        _MessageBubble(msg: msg, isMe: isMe),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // ── Input bar ─────────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              left: 16, right: 8,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: const TextStyle(color: AppTheme.textLight),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppTheme.primary),
                      ),
                      filled: true,
                      fillColor: AppTheme.bgLight,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.primary),
                          ),
                        )
                      : GestureDetector(
                          onTap: _send,
                          child: Container(
                            width: 44, height: 44,
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.send_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Date divider ────────────────────────────────────────────────────
class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  String get _label {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const Expanded(child: Divider(color: AppTheme.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(_label,
              style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
        ),
        const Expanded(child: Divider(color: AppTheme.border)),
      ]),
    );
  }
}

// ── Message bubble ──────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isMe;
  const _MessageBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryLight,
              backgroundImage: msg.senderPhoto != null
                  ? NetworkImage(msg.senderPhoto!) : null,
              child: msg.senderPhoto == null
                  ? Text(
                      msg.senderName.isNotEmpty
                          ? msg.senderName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.primary,
                          fontWeight: FontWeight.w600),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      msg.senderName,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textLight,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppTheme.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(18),
                      topRight:    const Radius.circular(18),
                      bottomLeft:  Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    border: isMe ? null : Border.all(color: AppTheme.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4, offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe ? Colors.white : AppTheme.textDark,
                      height: 1.4,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Text(
                    DateFormat('h:mm a').format(msg.sentAt),
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textLight),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}