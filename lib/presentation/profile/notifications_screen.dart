import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // FIX: notifications collection, userId field se filter
  Stream<List<Map<String, dynamic>>> get _notifStream =>
      FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '')
          .snapshots()
          .map((s) {
            final docs = s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
            // Client-side sort (no composite index needed)
            docs.sort((a, b) {
              final ta = a['createdAt'] as String? ?? '';
              final tb = b['createdAt'] as String? ?? '';
              return tb.compareTo(ta); // newest first
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
      ));
    }
  }

  Future<void> _delete(String notifId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notifId)
        .delete();
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
            return Center(child: Text('Error: ${snap.error}',
                style: const TextStyle(color: AppTheme.textMedium)));
          }

          final notifs = snap.data ?? [];

          if (notifs.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                      color: AppTheme.bgWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border)),
                  child: const Icon(Icons.notifications_none,
                      color: AppTheme.textLight, size: 36),
                ),
                const SizedBox(height: 16),
                const Text('No notifications yet',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                        color: AppTheme.textDark)),
                const SizedBox(height: 6),
                const Text("You'll see ride updates here",
                    style: TextStyle(color: AppTheme.textMedium, fontSize: 13)),
              ]),
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
              final rideId = n['rideId'] as String?;
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
                  child: const Icon(Icons.delete_outline,
                      color: Colors.white, size: 24),
                ),
                onDismissed: (_) => _delete(id),
                child: GestureDetector(
                  onTap: () {
                    if (!isRead) _markRead(id);
                    if (rideId != null && rideId.isNotEmpty) {
                      if (type == 'booking_request') {
                        context.push('/ride/$rideId/requests');
                      } else {
                        context.push('/ride/$rideId');
                      }
                    }
                  },
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

  IconData _iconFor(String type) {
    switch (type) {
      case 'ride_status':     return Icons.directions_car;
      case 'ride_cancelled':  return Icons.cancel_outlined;
      case 'booking_request': return Icons.person_add_outlined;
      case 'booking_update':  return Icons.check_circle_outline;
      case 'booking_accepted':return Icons.check_circle_outline;
      case 'booking_rejected':return Icons.cancel_outlined;
      case 'ride_started':    return Icons.play_arrow;
      case 'ride_completed':  return Icons.flag;
      case 'new_message':     return Icons.chat_bubble_outline;
      case 'message':         return Icons.chat_bubble_outline;
      default:                return Icons.notifications_outlined;
    }
  }

  Color _iconBg(String type) {
    switch (type) {
      case 'ride_status':
      case 'ride_started':    return AppTheme.primary.withOpacity(0.1);
      case 'ride_cancelled':
      case 'booking_rejected':return AppTheme.error.withOpacity(0.1);
      case 'booking_request': return AppTheme.warning.withOpacity(0.1);
      case 'booking_update':
      case 'booking_accepted':
      case 'ride_completed':  return AppTheme.success.withOpacity(0.1);
      case 'new_message':
      case 'message':         return AppTheme.primary.withOpacity(0.1);
      default:                return AppTheme.bgLight;
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case 'ride_status':
      case 'ride_started':    return AppTheme.primary;
      case 'ride_cancelled':
      case 'booking_rejected':return AppTheme.error;
      case 'booking_request': return AppTheme.warning;
      case 'booking_update':
      case 'booking_accepted':
      case 'ride_completed':  return AppTheme.success;
      case 'new_message':
      case 'message':         return AppTheme.primary;
      default:                return AppTheme.textMedium;
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