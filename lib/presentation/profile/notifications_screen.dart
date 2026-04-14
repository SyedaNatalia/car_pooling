// lib/presentation/profile/notifications_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  // Toggle states
  bool _pushEnabled    = true;
  bool _rideRequests   = true;
  bool _rideAccepted   = true;
  bool _rideReminders  = true;
  bool _rideUpdates    = false;
  bool _promotions     = false;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  // ── Load saved preferences from Firestore ─────────────────────
  Future<void> _loadPrefs() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
      final prefs = doc.data()?['notificationPrefs'] as Map<String, dynamic>?;
      if (prefs != null && mounted) {
        setState(() {
          _pushEnabled   = prefs['pushEnabled']   ?? true;
          _rideRequests  = prefs['rideRequests']  ?? true;
          _rideAccepted  = prefs['rideAccepted']  ?? true;
          _rideReminders = prefs['rideReminders'] ?? true;
          _rideUpdates   = prefs['rideUpdates']   ?? false;
          _promotions    = prefs['promotions']    ?? false;
        });
      }
    } catch (_) {}
  }

  // ── Save prefs + FCM token to Firestore ───────────────────────
  Future<void> _savePrefs() async {
    setState(() => _isSaving = true);
    try {
      // Request permission & get FCM token
      String? fcmToken;
      if (_pushEnabled) {
        final settings = await FirebaseMessaging.instance.requestPermission();
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          fcmToken = await FirebaseMessaging.instance.getToken();
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .update({
        'notificationPrefs': {
          'pushEnabled':   _pushEnabled,
          'rideRequests':  _rideRequests,
          'rideAccepted':  _rideAccepted,
          'rideReminders': _rideReminders,
          'rideUpdates':   _rideUpdates,
          'promotions':    _promotions,
        },
        // Save/clear FCM token
        if (fcmToken != null)  'fcmToken': fcmToken,
        if (!_pushEnabled)     'fcmToken': FieldValue.delete(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
            onPressed: _isSaving ? null : _savePrefs,
            child: _isSaving
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primary))
                : const Text('Save',
                    style: TextStyle(
                        color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Master toggle
          _NotifSection(
            title: 'Push Notifications',
            items: [
              _NotifTile(
                icon: Icons.notifications_active_outlined,
                title: 'Enable push notifications',
                subtitle: 'Receive all app notifications',
                value: _pushEnabled,
                onChanged: (v) => setState(() {
                  _pushEnabled = v;
                  if (!v) {
                    _rideRequests = _rideAccepted =
                        _rideReminders = _rideUpdates = _promotions = false;
                  }
                }),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Ride notifications
          _NotifSection(
            title: 'Ride Alerts',
            items: [
              _NotifTile(
                icon: Icons.person_add_outlined,
                title: 'Booking requests',
                subtitle: 'When someone requests your ride',
                value: _rideRequests && _pushEnabled,
                enabled: _pushEnabled,
                onChanged: (v) => setState(() => _rideRequests = v),
              ),
              _NotifTile(
                icon: Icons.check_circle_outline,
                title: 'Booking accepted',
                subtitle: 'When your request is accepted',
                value: _rideAccepted && _pushEnabled,
                enabled: _pushEnabled,
                onChanged: (v) => setState(() => _rideAccepted = v),
              ),
              _NotifTile(
                icon: Icons.alarm_outlined,
                title: 'Ride reminders',
                subtitle: '30 min before departure',
                value: _rideReminders && _pushEnabled,
                enabled: _pushEnabled,
                onChanged: (v) => setState(() => _rideReminders = v),
              ),
              _NotifTile(
                icon: Icons.update_outlined,
                title: 'Ride updates',
                subtitle: 'Status changes & driver updates',
                value: _rideUpdates && _pushEnabled,
                enabled: _pushEnabled,
                onChanged: (v) => setState(() => _rideUpdates = v),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Other
          _NotifSection(
            title: 'Other',
            items: [
              _NotifTile(
                icon: Icons.local_offer_outlined,
                title: 'Promotions',
                subtitle: 'App news and offers',
                value: _promotions && _pushEnabled,
                enabled: _pushEnabled,
                onChanged: (v) => setState(() => _promotions = v),
              ),
            ],
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ── Section wrapper ────────────────────────────────────────────────
class _NotifSection extends StatelessWidget {
  final String title;
  final List<_NotifTile> items;
  const _NotifSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppTheme.textMedium, letterSpacing: 0.5)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.bgWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              return Column(children: [
                e.value,
                if (!isLast)
                  const Divider(height: 1, indent: 56, color: AppTheme.border),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Individual toggle tile ─────────────────────────────────────────
class _NotifTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _NotifTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: value
                ? AppTheme.primary.withOpacity(0.1)
                : AppTheme.bgLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              size: 20,
              color: value ? AppTheme.primary : AppTheme.textLight),
        ),
        title: Text(title,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500,
                color: AppTheme.textDark)),
        subtitle: Text(subtitle,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textMedium)),
        trailing: Switch(
          value: value,
          onChanged: enabled ? onChanged : null,
          activeColor: AppTheme.primary,
        ),
      ),
    );
  }
}