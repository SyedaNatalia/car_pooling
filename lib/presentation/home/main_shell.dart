import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/ride_model.dart';
import '../../data/providers/app_providers.dart';
import '../../data/services/ride_service.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final _rideService = RideService();
  bool _hasActiveRide    = false; 
  bool _hasActiveBooking = false; 
  RideModel? _activeBookedRide;  

  GoRouter? _router;
  bool _listenerAttached = false;

  @override
  void initState() {
    super.initState();
    _checkActiveStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_listenerAttached) {
      _router = GoRouter.of(context);
      _router!.routerDelegate.addListener(_onRouteChange);
      _listenerAttached = true;
    }
  }

  void _onRouteChange() {
    _checkActiveStatus();
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChange);
    super.dispose();
  }

  Future<void> _checkActiveStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    try {
      final hasRide    = await _rideService.hasActiveRide(uid);
      final hasBooking = await _rideService.hasActivePendingBooking(uid);
      if (mounted) {
        setState(() {
        _hasActiveRide    = hasRide;
        _hasActiveBooking = hasBooking;
      });
      }

      if (hasBooking) {
        final snap = await FirebaseFirestore.instance
            .collection('bookings')
            .where('passengerId', isEqualTo: uid)
            .where('status', whereIn: ['pending', 'accepted'])
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final rideId = snap.docs.first.data()['rideId'] as String? ?? '';
          if (rideId.isNotEmpty) {
            final ride = await _rideService.getRideById(rideId);
            if (mounted) setState(() => _activeBookedRide = ride);
          }
        }
      } else {
        if (mounted) setState(() => _activeBookedRide = null);
      }
    } catch (_) {}
  }

  void _showNotice(BuildContext context, {required bool isDriver}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ActiveRideNoticeSheet(
        isDriver: isDriver,
        activeBookedRide: isDriver ? null : _activeBookedRide,
      ),
    ).then((_) => _checkActiveStatus()); 
  }

  @override
  Widget build(BuildContext context) {
    final location  = GoRouterState.of(context).matchedLocation;
    final userAsync = ref.watch(currentUserProvider);
    final user      = userAsync.valueOrNull;

    // Driver = car details
    final isDriver = user != null &&
        user.carDetails != null &&
        user.carDetails!.plateNumber.isNotEmpty;

    const routes = ['/home', '/find-ride', '/offer-ride', '/profile'];

    int currentNavIndex = 0;
    for (int i = 0; i < routes.length; i++) {
      if (location.startsWith(routes[i])) { currentNavIndex = i; break; }
    }

    void onTap(int i) {
      // Find Ride block for driver
      if (i == 1 && _hasActiveRide) {
        _showNotice(context, isDriver: true);
        return;
      }
      // Offer Ride block for rider
      if (i == 2 && _hasActiveBooking) {
        _showNotice(context, isDriver: false);
        return;
      }
      context.go(routes[i]);
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentNavIndex,
          onTap: onTap,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),

            const BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search_rounded),
              label: 'Find Ride',
            ),

            const BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              activeIcon: Icon(Icons.add_circle),
              label: 'Offer Ride',
            ),

            BottomNavigationBarItem(
              icon: _NotifBadgeIcon(
                icon: Icons.person_outline,
                activeIcon: Icons.person_rounded,
                isActive: currentNavIndex == 3,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Notice Bottom Sheet ───────────────────────────────────────────────────────

class _ActiveRideNoticeSheet extends StatelessWidget {
  final bool isDriver;
  final RideModel? activeBookedRide;
  const _ActiveRideNoticeSheet({required this.isDriver, this.activeBookedRide});

  @override
  Widget build(BuildContext context) {
    return isDriver
        ? _DriverNoticeSheet(context)
        : _PassengerNoticeSheet(context);
  }

  // ── Driver: has active offered ride → wants to Find Ride ──────────
  Widget _DriverNoticeSheet(BuildContext context) {
    return _BaseSheet(
      icon: Icons.directions_car_rounded,
      iconColor: AppTheme.primary,
      title: 'Active Ride in Progress',
      subtitle: 'You currently have an offered ride that is still active. '
          'Please complete or cancel it before searching for a new ride.',
      steps: null,
      activeBookedRide: null,
      primaryLabel: 'View My Rides',
      onPrimary: () {
        Navigator.pop(context);
        context.push('/my-rides');
      },
      onDismiss: () => Navigator.pop(context),
    );
  }

  // ── Passenger: has active booking → wants to Offer Ride ───────────
  Widget _PassengerNoticeSheet(BuildContext context) {
    return _BaseSheet(
      icon: Icons.event_seat_rounded,
      iconColor: AppTheme.primary,
      title: 'You Have an Active Booking',
      subtitle: 'Cancel your current booking or wait for it to complete before offering a new ride.',
      steps: null,
      activeBookedRide: activeBookedRide,
      primaryLabel: 'My Bookings',
      onPrimary: () {
        Navigator.pop(context);
        context.push('/my-bookings');
      },
      onDismiss: () => Navigator.pop(context),
    );
  }
}

class _BaseSheet extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<_StepItem>? steps;
  final RideModel? activeBookedRide;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onDismiss;

  const _BaseSheet({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.steps,
    required this.activeBookedRide,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: iconColor, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMedium,
                    height: 1.6,
                  ),
                ),

                // Passenger booked ride details card
                if (activeBookedRide != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.bgLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        // Route
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                Container(width: 1.5, height: 22, color: AppTheme.border),
                                Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(
                                    color: AppTheme.success,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activeBookedRide!.startPoint.address.split(',').first,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    activeBookedRide!.endPoint.address.split(',').first,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textMedium,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppTheme.border),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 14, color: AppTheme.textLight),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                activeBookedRide!.driverName,
                                style: const TextStyle(fontSize: 12, color: AppTheme.textMedium),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.access_time, size: 14, color: AppTheme.textLight),
                            const SizedBox(width: 5),
                            Text(
                              DateFormat('MMM d • h:mm a').format(activeBookedRide!.departureTime),
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMedium),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Only for passenger sheet
                if (steps != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HOW TO PROCEED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textLight,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...steps!.map((s) => _buildStep(s, steps!.last == s)),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDismiss,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textMedium,
                          side: const BorderSide(color: AppTheme.border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Dismiss',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onPrimary,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: Text(primaryLabel,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(_StepItem step, bool isLast) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24, height: 24,
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step.number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  step.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMedium,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step data class ───────────────────────────────────────────────────────────

class _StepItem {
  final String number;
  final String title;
  final String description;
  const _StepItem({
    required this.number,
    required this.title,
    required this.description,
  });
}

// ── Notification badge on profile icon ───────────────────────────────────────

class _NotifBadgeIcon extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;

  const _NotifBadgeIcon({
    required this.icon,
    required this.activeIcon,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(isActive ? activeIcon : icon),
            if (count > 0)
              Positioned(
                top: -4, right: -6,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.elasticOut,
                  width: count > 9 ? 18 : 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: AppTheme.error,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}