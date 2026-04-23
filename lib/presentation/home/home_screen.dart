import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/ride_service.dart';
import '../../data/models/ride_model.dart';
import '../../data/models/user_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  UserModel? _user;
  List<RideModel> _upcomingRides = [];
  bool _loadingRides = true;
  final _authService = AuthService();
  final _rideService = RideService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loadingRides = true);
    final user = await _authService.getCurrentUserProfile();

    // FIX: current user ki apni rides exclude karo
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final rides = await _rideService.searchRides(
      date: DateTime.now(),
      excludeDriverId: currentUid,
    );

    if (mounted) {
      setState(() {
        _user = user;
        // FIX: duplicates remove karo ID se, phir sirf 3 lo
        final seen = <String>{};
        _upcomingRides = rides
            .where((r) => seen.add(r.id))
            .take(3)
            .toList();
        _loadingRides = false;
      });
    }
  }

  // FIX: waqt ke hisab se greeting
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Container(
                color: AppTheme.primary,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 20, right: 20, bottom: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_greeting()},',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _user?.name.split(' ').first ?? 'Welcome',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // FIX: Notification bell with unread count badge
                        Stack(
                          children: [
                            IconButton(
                              onPressed: () => context.push('/notifications'),
                              icon: const Icon(Icons.notifications_outlined,
                                  color: Colors.white, size: 24),
                            ),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('notifications')
                                  .where('userId',
                                      isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '')
                                  .where('isRead', isEqualTo: false)
                                  .snapshots(),
                              builder: (_, snap) {
                                final count = snap.data?.docs.length ?? 0;
                                if (count == 0) return const SizedBox.shrink();
                                return Positioned(
                                  right: 6, top: 6,
                                  child: Container(
                                    width: 16, height: 16,
                                    decoration: const BoxDecoration(
                                        color: Colors.red, shape: BoxShape.circle),
                                    child: Center(
                                      child: Text(
                                        count > 9 ? '9+' : '$count',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => context.go('/profile'),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            backgroundImage: _user?.photoUrl != null
                                ? NetworkImage(_user!.photoUrl!)
                                : null,
                            child: _user?.photoUrl == null
                                ? Text(
                                    _user?.name.substring(0, 1).toUpperCase() ?? 'U',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Quick action cards
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.search,
                            title: 'Find a ride',
                            subtitle: 'Book your seat',
                            onTap: () => context.go('/find-ride'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.drive_eta,
                            title: 'Offer a ride',
                            subtitle: 'Share your car',
                            onTap: () => context.go('/offer-ride'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Upcoming rides section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Available rides today',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/find-ride'),
                      child: const Text('See all', style: TextStyle(color: AppTheme.primary)),
                    ),
                  ],
                ),
              ),
            ),

            if (_loadingRides)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
                ),
              )
            else if (_upcomingRides.isEmpty)
              SliverToBoxAdapter(child: _EmptyRidesCard(onFind: () => context.go('/find-ride')))
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: _RideCard(ride: _upcomingRides[i]),
                  ),
                  childCount: _upcomingRides.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(subtitle,
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final RideModel ride;
  const _RideCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/ride/${ride.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.directions_car, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // FIX: exact location dikhao — "X se Y ja rahe hain" wala format
                  Text(
                    '${ride.startPoint.address.split(',').first} → ${ride.endPoint.address.split(',').first}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppTheme.textDark, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 13, color: AppTheme.textLight),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('EEE, MMM d • h:mm a').format(ride.departureTime),
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMedium),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${ride.availableSeats} seats',
                style: const TextStyle(
                  color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRidesCard extends StatelessWidget {
  final VoidCallback onFind;
  const _EmptyRidesCard({required this.onFind});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.bgWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.directions_car_outlined, color: AppTheme.primary, size: 32),
            ),
            const SizedBox(height: 14),
            const Text('No upcoming rides',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
            const SizedBox(height: 6),
            const Text('Find a ride to office or offer\nyour car to colleagues',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textMedium, height: 1.5)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onFind,
              style: OutlinedButton.styleFrom(minimumSize: const Size(160, 44)),
              child: const Text('Find a Ride'),
            ),
          ],
        ),
      ),
    );
  }
}