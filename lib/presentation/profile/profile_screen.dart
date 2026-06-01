// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/app_providers.dart';
import '../../data/models/user_model.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('Failed to load profile')),
      ),
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('Failed to load profile')),
          );
        }
        return _ProfileBody(user: user, ref: ref);
      },
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final UserModel user;
  final WidgetRef ref;
  const _ProfileBody({required this.user, required this.ref});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign out?',
            style: TextStyle(fontWeight: FontWeight.w600)),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textMedium)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authServiceProvider).signOut();
      if (context.mounted) context.go('/auth/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: CustomScrollView(
        slivers: [
          // ── Profile header ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.primary,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                left: 20, right: 20, bottom: 28,
              ),
              child: Column(children: [
                // Avatar
                Stack(children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    backgroundImage: user.photoUrl != null
                        ? NetworkImage(user.photoUrl!) : null,
                    child: user.photoUrl == null
                        ? Text(
                            user.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 32,
                                fontWeight: FontWeight.w700))
                        : null,
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: GestureDetector(
                      onTap: () => context.push('/edit-profile'),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppTheme.primary, width: 2),
                        ),
                        child: const Icon(Icons.edit,
                            size: 14, color: AppTheme.primary),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(user.name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(user.email,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(user.department,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12)),
                ),
              ]),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const SizedBox(height: 8),

                _MenuSection(
                  title: 'My Activity',
                  items: [
                    _MenuItem(
                      icon: Icons.history,
                      iconColor: AppTheme.primary,
                      label: 'Ride history',
                      onTap: () => context.push('/ride-history'),
                    ),
                    _MenuItem(
                      icon: Icons.bookmark_border,
                      iconColor: AppTheme.primary,
                      label: 'My bookings',
                      onTap: () => context.push('/my-bookings'),
                    ),
                    if (user.role != 'passenger')
                      _MenuItem(
                        icon: Icons.drive_eta,
                        iconColor: AppTheme.primary,
                        label: 'My rides (as driver)',
                        onTap: () => context.push('/my-rides'),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                _MenuSection(
                  title: 'Account',
                  items: [
                    _MenuItem(
                      icon: Icons.person_outline,
                      iconColor: AppTheme.primary,
                      label: 'Edit profile',
                      onTap: () => context.push('/edit-profile'),
                    ),

                    _MenuItem(
                      icon: Icons.directions_car_outlined,
                      iconColor: AppTheme.primary,
                      label: 'Edit car details',
                      onTap: () => context.push('/edit-car-details'),
                    ),

                    _MenuItem(
                      icon: Icons.notifications_outlined,
                      iconColor: AppTheme.primary,
                      label: 'Notifications',
                      onTap: () => context.push('/notifications'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (user.role == 'admin')
                  _MenuSection(
                    title: 'Admin',
                    items: [
                      _MenuItem(
                        icon: Icons.admin_panel_settings_outlined,
                        iconColor: AppTheme.primary,
                        label: 'Admin Dashboard',
                        onTap: () => context.push('/admin'),
                        color: AppTheme.primary,
                      ),
                    ],
                  ),

                const SizedBox(height: 12),

                _MenuSection(
                  title: 'More',
                  items: [
                    _MenuItem(
                      icon: Icons.help_outline,
                      iconColor: AppTheme.primary,
                      label: 'Help & Support',
                      onTap: () => context.push('/help'),
                    ),
                    _MenuItem(
                      icon: Icons.info_outline,
                      iconColor: AppTheme.primary,
                      label: 'About',
                      onTap: () => context.push('/about'),
                    ),
                    _MenuItem(
                      icon: Icons.logout,
                      iconColor: AppTheme.primary,
                      label: 'Sign out',
                      onTap: () => _logout(context),
                      color: AppTheme.error,
                    ),
                  ],
                ),

                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat item ──────────────────────────────────────────────────────
class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  const _StatItem({required this.value, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, color: const Color(0xFFFBBF24), size: 14),
          const SizedBox(width: 3),
        ],
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
      ]),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(
              color: Colors.white.withOpacity(0.75), fontSize: 11)),
    ]);
  }
}

// ── Section ────────────────────────────────────────────────────────
class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;
  const _MenuSection({required this.title, required this.items});

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
                  const Divider(
                      height: 1, indent: 50, color: AppTheme.border),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Menu item ──────────────────────────────────────────────────────
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final Widget? trailing;
  final Color? iconColor;
  const _MenuItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
    this.trailing,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon,
          color: iconColor, size: 22),
      title: Text(label,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500,
              color: color ?? AppTheme.textDark)),
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right,
                  color: AppTheme.textLight, size: 20)
              : null),
      onTap: onTap,
    );
  }
}