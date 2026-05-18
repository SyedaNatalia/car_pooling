// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/shimmer_widget.dart';
import '../widgets/animated_empty_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<List<Map<String, dynamic>>> get _notifStream =>
      FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '')
          .snapshots()
          .map((s) {
            final docs = s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
            docs.sort((a, b) {
              final ta = a['createdAt'] as String? ?? '';
              final tb = b['createdAt'] as String? ?? '';
              return tb.compareTo(ta);
            });
            return docs;
          });

  Future<void> _markRead(String notifId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notifId)
        .update({'isRead': true});
  }

  Future<void> _markAllRead(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final snap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('All notifications marked as read'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, 8),
      ));
    }
  }

  // 5-second UNDO
  Future<void> _deleteWithUndo(BuildContext context, Map<String, dynamic> notif, String id) async {
    final notifData = Map<String, dynamic>.from(notif)..remove('id');

    await FirebaseFirestore.instance.collection('notifications').doc(id).delete();

    if (!context.mounted) return;

    final snackBarController = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          Icon(Icons.delete_outline, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Text('Notification deleted'),
        ]),
        backgroundColor: AppTheme.textDark,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: AppTheme.primary,
          onPressed: () async {
            // Restore the notification
            try {
              await FirebaseFirestore.instance.collection('notifications').add(notifData);
            } catch (_) {}
          },
        ),
      ),
    );
    await snackBarController.closed;
  }

  Future<void> _handleTap(
    BuildContext context,
    Map<String, dynamic> n,
    String id,
    bool isRead,
  ) async {
    if (!isRead) await _markRead(id);

    final type   = n['type'] as String? ?? '';
    final rideId = n['rideId'] as String?;

    if (rideId == null || rideId.isEmpty) return;

    if (type == 'ride_cancelled' ||
        type == 'ride_cancelled_self' ||
        type == 'booking_cancelled' ||
        type == 'booking_cancelled_self' ||
        type == 'booking_rejected') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.info_outline, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('This ride or booking has been cancelled.'),
          ]),
          backgroundColor: AppTheme.textMedium,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (type == 'booking_request') {
      context.push('/ride/$rideId/requests');
    } else if (type == 'booking_accepted') {
      context.push('/ride/$rideId');
    } else {
      context.push('/ride/$rideId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => _markAllRead(context),
            child: const Text('Mark all read',
                style: TextStyle(color: AppTheme.primary, fontSize: 12)),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _notifStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary));
          }
          if (snap.hasError) {
            return _buildErrorState(snap.error.toString());
          }

          final notifs = snap.data ?? [];

          if (notifs.isEmpty) {
            return const AnimatedEmptyState(
              icon: Icons.notifications_none_outlined,
              title: 'No notifications yet',
              subtitle: "You'll see ride updates, booking\nconfirmations and alerts here.",
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final n      = notifs[i];
              final id     = n['id'] as String;
              final isRead = n['isRead'] == true;
              final type   = n['type'] as String? ?? '';
              DateTime? createdAt;
              try {
                if (n['createdAt'] != null) {
                  createdAt = DateTime.parse(n['createdAt'] as String);
                }
              } catch (_) {}

              return Dismissible(
                key: Key(id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.error,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
                ),
                onDismissed: (_) => _deleteWithUndo(context, n, id),
                child: GestureDetector(
                  onTap: () => _handleTap(context, n, id, isRead),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isRead
                          ? AppTheme.bgWhite
                          : AppTheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isRead
                            ? AppTheme.border
                            : AppTheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: _iconBg(type),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_iconFor(type),
                              color: _iconColor(type), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: Text(
                                    n['title'] as String? ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isRead
                                          ? FontWeight.w500
                                          : FontWeight.w700,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    width: 8, height: 8,
                                    decoration: const BoxDecoration(
                                        color: AppTheme.primary,
                                        shape: BoxShape.circle),
                                  ),
                              ]),
                              const SizedBox(height: 3),
                              Text(
                                n['body'] as String? ?? '',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textMedium,
                                    height: 1.4),
                              ),
                              if (createdAt != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _timeAgo(createdAt),
                                  style: const TextStyle(
                                      fontSize: 11, color: AppTheme.textLight),
                                ),
                              ],
                              if (type == 'booking_request') ...[
                                const SizedBox(height: 4),
                                const Text('Tap to manage this booking request',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w500)),
                              ],
                              if (type == 'booking_accepted') ...[
                                const SizedBox(height: 4),
                                const Text('Tap to view ride details',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.success,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Internet error state
  Widget _buildErrorState(String raw) {
    final isNetwork = raw.contains('network') ||
        raw.contains('unavailable') ||
        raw.contains('SocketException') ||
        raw.contains('connection');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.wifi_off_rounded, color: Colors.orange.shade600, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('Connection Problem',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
          const SizedBox(height: 8),
          Text(
            isNetwork
                ? 'No internet connection. Please check your Wi-Fi or mobile data.'
                : 'Could not load notifications. Please try again later.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textMedium, height: 1.5),
          ),
        ]),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'ride_status':      return Icons.directions_car;
      case 'ride_cancelled':   return Icons.cancel_outlined;
      case 'booking_request':  return Icons.person_add_outlined;
      case 'booking_update':   return Icons.check_circle_outline;
      case 'booking_accepted': return Icons.check_circle_outline;
      case 'booking_accepted_driver': return Icons.check_circle_outline;
      case 'booking_rejected': return Icons.cancel_outlined;
      case 'ride_started':     return Icons.play_arrow;
      case 'ride_completed':   return Icons.flag;
      case 'new_message':      return Icons.chat_bubble_outline;
      case 'message':          return Icons.chat_bubble_outline;
      default:                 return Icons.notifications_outlined;
    }
  }

  Color _iconBg(String type) {
    switch (type) {
      case 'ride_status':
      case 'ride_started':     return AppTheme.primary.withOpacity(0.1);
      case 'ride_cancelled':
      case 'booking_rejected': return AppTheme.error.withOpacity(0.1);
      case 'booking_request':  return AppTheme.warning.withOpacity(0.1);
      case 'booking_update':
      case 'booking_accepted':
      case 'booking_accepted_driver':
      case 'ride_completed':   return AppTheme.success.withOpacity(0.1);
      case 'new_message':
      case 'message':          return AppTheme.primary.withOpacity(0.1);
      default:                 return AppTheme.bgLight;
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case 'ride_status':
      case 'ride_started':     return AppTheme.primary;
      case 'ride_cancelled':
      case 'booking_rejected': return AppTheme.error;
      case 'booking_request':  return AppTheme.warning;
      case 'booking_update':
      case 'booking_accepted':
      case 'booking_accepted_driver':
      case 'ride_completed':   return AppTheme.success;
      case 'new_message':
      case 'message':          return AppTheme.primary;
      default:                 return AppTheme.textMedium;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    < 7)  return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(dt);
  }
}