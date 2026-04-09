// lib/presentation/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/ride_service.dart';
import '../../data/models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;
  bool _isLoading = true;
  int _totalRides = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = await AuthService().getCurrentUserProfile();
    if (mounted) setState(() { _user = user; _isLoading = false; });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign out?', style: TextStyle(fontWeight: FontWeight.w600)),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMedium)),
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
      await AuthService().signOut();
      if (mounted) context.go('/auth/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    }

    final user = _user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Failed to load profile')));
    }

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: CustomScrollView(
        slivers: [
          // Profile header
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.primary,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                left: 20, right: 20, bottom: 28,
              ),
              child: Column(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        backgroundImage: user.photoUrl != null
                            ? NetworkImage(user.photoUrl!) : null,
                        child: user.photoUrl == null
                            ? Text(
                                user.name.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
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
                            child: const Icon(Icons.edit, size: 14, color: AppTheme.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(user.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    )),
                  const SizedBox(height: 4),
                  Text(user.email,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 13)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(user.department,
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  const SizedBox(height: 20),

                  // Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatItem(value: user.totalRides.toString(), label: 'Total rides'),
                      Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
                      _StatItem(
                        value: user.rating > 0
                            ? user.rating.toStringAsFixed(1) : 'New',
                        label: 'Rating',
                        icon: user.rating > 0 ? Icons.star : null,
                      ),
                      Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
                      _StatItem(
                        value: user.role == 'both' ? 'Driver & Rider'
                            : user.role == 'driver' ? 'Driver' : 'Rider',
                        label: 'Role',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Menu items
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  _MenuSection(
                    title: 'My Activity',
                    items: [
                      _MenuItem(
                        icon: Icons.history,
                        label: 'Ride history',
                        onTap: () {},
                      ),
                      _MenuItem(
                        icon: Icons.bookmark_border,
                        label: 'My bookings',
                        onTap: () {},
                      ),
                      if (user.role != 'passenger')
                        _MenuItem(
                          icon: Icons.drive_eta,
                          label: 'My rides (as driver)',
                          onTap: () {},
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _MenuSection(
                    title: 'Account',
                    items: [
                      _MenuItem(
                        icon: Icons.person_outline,
                        label: 'Edit profile',
                        onTap: () => context.push('/edit-profile'),
                      ),
                      if (user.role != 'passenger')
                        _MenuItem(
                          icon: Icons.directions_car_outlined,
                          label: 'Car details',
                          onTap: () => context.push('/edit-profile'),
                        ),
                      _MenuItem(
                        icon: Icons.notifications_outlined,
                        label: 'Notifications',
                        trailing: Switch(
                          value: true,
                          onChanged: (_) {},
                          activeColor: AppTheme.primary,
                        ),
                        onTap: null,
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
                        label: 'Help & Support',
                        onTap: () {},
                      ),
                      _MenuItem(
                        icon: Icons.info_outline,
                        label: 'About',
                        onTap: () {},
                      ),
                      _MenuItem(
                        icon: Icons.logout,
                        label: 'Sign out',
                        onTap: _logout,
                        color: AppTheme.error,
                      ),
                    ],
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  const _StatItem({required this.value, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: const Color(0xFFFBBF24), size: 14),
              const SizedBox(width: 3),
            ],
            Text(value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              )),
          ],
        ),
        const SizedBox(height: 2),
        Text(label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: 11,
          )),
      ],
    );
  }
}

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
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMedium,
              letterSpacing: 0.5,
            )),
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
              return Column(
                children: [
                  e.value,
                  if (!isLast)
                    const Divider(height: 1, indent: 50, color: AppTheme.border),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final Widget? trailing;
  const _MenuItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: color ?? AppTheme.textMedium, size: 22),
      title: Text(label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: color ?? AppTheme.textDark,
        )),
      trailing: trailing ?? (onTap != null
          ? const Icon(Icons.chevron_right, color: AppTheme.textLight, size: 20)
          : null),
      onTap: onTap,
    );
  }
}
