// ignore_for_file: deprecated_member_use

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
import '../widgets/animated_empty_state.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  UserModel? _user;
  // Active booking info
  String? _activeBookingRideId;
  RideModel? _activeBookedRide;
  bool _loadingBookedRide = false;

  // Role-based restrictions
  bool _isDriver = false;            

  // Driver/Rider role restrictions
  bool _hasActiveRide = false;       
  bool _hasActiveBooking = false;    

  final _authService = AuthService();
  final _rideService = RideService();

  @override
  void initState() {
    super.initState();
    _loadUser();
    _rideService.autoExpireRides(); 
    _loadActiveBookedRide();
    _checkRoleRestrictions();
  }

  void _showActiveRideNotice(BuildContext context, {required bool isDriver}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActiveRideNoticeSheet(isDriver: isDriver),
    ).then((_) => _checkRoleRestrictions()); 
  }

  void _showPassengerBookingSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PassengerActiveBookingSheet(
        activeBookedRide: _activeBookedRide,
        onDismiss: () {
          Navigator.pop(context);
          _checkRoleRestrictions();
          _loadActiveBookedRide();
        },
        onGoToBookings: () {
          Navigator.pop(context);
          context.push('/my-bookings');
        },
      ),
    ).then((_) {
      _checkRoleRestrictions();
      _loadActiveBookedRide();
    });
  }

  Future<void> _loadUser() async {
    final user = await _authService.getCurrentUserProfile();
    if (mounted) {
      setState(() {
      _user = user;
      _isDriver = user?.carDetails != null &&
          user!.carDetails!.plateNumber.isNotEmpty;
    });
    }
  }

  // Driver active then Find Ride disable
  // Rider active booking then Offer Ride disable
  Future<void> _checkRoleRestrictions() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    try {
      final hasRide = await _rideService.hasActiveRide(uid);
      final hasBooking = await _rideService.hasActivePendingBooking(uid);
      if (mounted) {
        setState(() {
        _hasActiveRide = hasRide;
        _hasActiveBooking = hasBooking;
      });
      }
    } catch (_) {}
  }


  // Load the ride that the current rider has actively booked
  Future<void> _loadActiveBookedRide() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    setState(() => _loadingBookedRide = true);
    try {
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
          if (mounted) setState(() { _activeBookingRideId = rideId; _activeBookedRide = ride; });
        }
      } else {
        if (mounted) setState(() { _activeBookingRideId = null; _activeBookedRide = null; });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingBookedRide = false);
  }

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
        onRefresh: () async {
          await _loadUser();
          await _loadActiveBookedRide();
          await _checkRoleRestrictions();
        },
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
    CircleAvatar(
      radius: 30,
      backgroundColor: Colors.white,
      child: ClipOval(
        child: Image.asset('assets/icons/icon.jpeg',
            width: 50, height: 50, fit: BoxFit.cover),
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_greeting()},',
              style: const TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 2),
          Text(
            _user?.name.split(' ').first ?? 'Welcome',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
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
                  isEqualTo:
                      FirebaseAuth.instance.currentUser?.uid ?? '')
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
                    color: Colors.white, fontWeight: FontWeight.w600))
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
                            subtitle: _hasActiveRide
                                ? 'Complete your ride first'
                                : 'Book your seat',
                            onTap: () {
                              if (_hasActiveRide) {
                                _showActiveRideNotice(context, isDriver: true);
                              } else {
                                context.go('/find-ride');
                              }
                            },
                            disabled: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.drive_eta,
                            title: 'Offer a ride',
                            subtitle: _hasActiveBooking
                                ? 'Cancel booking first'
                                : 'Share your car',
                            onTap: () {
                              if (_hasActiveBooking) {
                                _showPassengerBookingSheet(context);
                              } else {
                                context.go('/offer-ride');
                              }
                            },
                            disabled: false,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Active Booked Ride Banner ──────────────────────────────
            if (_activeBookedRide != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: GestureDetector(
                    onTap: () => context.push('/ride/${_activeBookedRide!.id}'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.75)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.3),
                            blurRadius: 10, offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.directions_car, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              const Text('Your Booked Ride',
                                  style: TextStyle(color: Colors.white, fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('Active',
                                    style: TextStyle(color: Colors.white, fontSize: 11)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${_activeBookedRide!.startPoint.address.split(',').first} → ${_activeBookedRide!.endPoint.address.split(',').first}',
                            style: const TextStyle(color: Colors.white, fontSize: 15,
                                fontWeight: FontWeight.w700),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.person_outline, size: 13, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(_activeBookedRide!.driverName,
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(width: 8),
                            const Icon(Icons.access_time, size: 13, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('EEE, MMM d • h:mm a').format(_activeBookedRide!.departureTime),
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          const Text('Tap to view details →',
                              style: TextStyle(color: Colors.white60, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── No booked ride empty state ──────────────────────────
            if (_activeBookedRide == null && !_loadingBookedRide)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: _HomeEmptyCard(
                    isDriver: _isDriver,
                    hasActiveRide: _hasActiveRide,
                    hasActiveBooking: _hasActiveBooking,
                    onFindRideBlocked: () => _showActiveRideNotice(context, isDriver: true),
                    onOfferRideBlocked: () => _showPassengerBookingSheet(context),
                  ),
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
  final VoidCallback? onTap;
  final bool disabled;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = disabled ? 0.45 : 1.0;
    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(disabled ? 0.08 : 0.15),
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
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
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
              child: const Icon(Icons.directions_car,
                  color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${ride.startPoint.address.split(',').first} → ${ride.endPoint.address.split(',').first}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                        fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.person_outline,
                        size: 13, color: AppTheme.textLight),
                    const SizedBox(width: 4),
                    Text(ride.driverName,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textMedium)),
                    if (ride.carName.isNotEmpty) ...[
                      const Text(' · ',
                          style: TextStyle(
                              color: AppTheme.textLight, fontSize: 12)),
                      Text(ride.carName,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMedium)),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.access_time,
                        size: 13, color: AppTheme.textLight),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('EEE, MMM d • h:mm a')
                          .format(ride.departureTime),
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMedium),
                    ),
                  ]),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (ride.pricePerSeat > 0)
                  Text(
                    'Rs ${ride.pricePerSeat.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${ride.availableSeats} seats',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Animated home empty card ─────────────────────────────────────────────────
class _HomeEmptyCard extends StatefulWidget {
  final bool isDriver;
  final bool hasActiveRide;
  final bool hasActiveBooking;
  final VoidCallback? onFindRideBlocked;
  final VoidCallback? onOfferRideBlocked;
  const _HomeEmptyCard({
    this.isDriver = false,
    this.hasActiveRide = false,
    this.hasActiveBooking = false,
    this.onFindRideBlocked,
    this.onOfferRideBlocked,
  });
  @override
  State<_HomeEmptyCard> createState() => _HomeEmptyCardState();
}

class _HomeEmptyCardState extends State<_HomeEmptyCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  late Animation<double> _iconBounce;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)
        .drive(Tween(begin: 0.0, end: 1.0));
    _slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _iconBounce = Tween<double>(begin: 0, end: 6).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.forward(); // sirf ek baar
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: AppTheme.bgWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04),
                  blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, -_iconBounce.value * 0.5),
                child: child,
              ),
              child: Container(
                width: 88, height: 88,
                decoration: const BoxDecoration(
                    color: AppTheme.primaryLight, shape: BoxShape.circle),
                child: const Icon(Icons.directions_car_rounded,
                    color: AppTheme.primary, size: 44),
              ),
            ),
            const SizedBox(height: 18),
            const Text('No Active Ride',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                    color: AppTheme.textDark)),
            const SizedBox(height: 8),
            const Text('Search for a ride or offer your own\nto get started',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textMedium,
                    height: 1.5)),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () {
                  if (widget.hasActiveRide) {
                    widget.onFindRideBlocked?.call();
                  } else {
                    context.go('/find-ride');
                  }
                },
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Find Ride'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                onPressed: () {
                  if (widget.hasActiveBooking) {
                    widget.onOfferRideBlocked?.call();
                  } else {
                    context.go('/offer-ride');
                  }
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Offer Ride'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              )),
            ]),
          ]),
        ),
      ),
    );
  }
}
// ── Active Ride Notice Bottom Sheet ──────────────────────────────────────────

class _ActiveRideNoticeSheet extends StatelessWidget {
  final bool isDriver;
  const _ActiveRideNoticeSheet({required this.isDriver});

  @override
  Widget build(BuildContext context) {
    final title = isDriver
        ? 'You Have an Active Ride'
        : 'You Have an Active Booking';

    final message = isDriver
        ? 'You currently have an offered ride in progress. Please complete or cancel your active ride before searching for a new one.'
        : 'You currently have an active booking. Please complete your trip or cancel your booking before offering a new ride.';

    final actionLabel = isDriver ? 'My Rides' : 'My Bookings';
    final actionRoute = isDriver ? '/my-rides' : '/my-bookings';
    final iconData    = isDriver ? Icons.directions_car_rounded : Icons.event_seat_rounded;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, color: AppTheme.primary, size: 30),
                ),
                const SizedBox(height: 16),
                Text(title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                        color: AppTheme.textDark),
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(message,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textMedium, height: 1.6),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textMedium,
                        side: const BorderSide(color: AppTheme.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Dismiss',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.push(actionRoute);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text(actionLabel,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// ── Passenger Active Booking Bottom Sheet ────────────────────────────────────
class _PassengerActiveBookingSheet extends StatelessWidget {
  final RideModel? activeBookedRide;
  final VoidCallback onDismiss;
  final VoidCallback onGoToBookings;

  const _PassengerActiveBookingSheet({
    required this.activeBookedRide,
    required this.onDismiss,
    required this.onGoToBookings,
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
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
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
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.event_seat_rounded,
                        color: AppTheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Active Booking',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'In Progress',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                if (activeBookedRide != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.bgLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        // Route row
                        Row(
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                Container(
                                    width: 1.5, height: 22, color: AppTheme.border),
                                Container(
                                  width: 8,
                                  height: 8,
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
                                    activeBookedRide!.startPoint.address
                                        .split(',')
                                        .first,
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
                                    activeBookedRide!.endPoint.address
                                        .split(',')
                                        .first,
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
                        const SizedBox(height: 12),
                        // Driver + time row
                        Row(
                          children: [
                            const Icon(Icons.person_outline,
                                size: 14, color: AppTheme.textLight),
                            const SizedBox(width: 5),
                            Text(
                              activeBookedRide!.driverName,
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textMedium),
                            ),
                            const SizedBox(width: 14),
                            const Icon(Icons.access_time,
                                size: 14, color: AppTheme.textLight),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                DateFormat('EEE, MMM d • h:mm a')
                                    .format(activeBookedRide!.departureTime),
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textMedium),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFE0A3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Color(0xFFF59E0B)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cancel your current booking or wait for it to complete before offering a new ride.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF92400E),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons
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
                        onPressed: onGoToBookings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('My Bookings',
                            style: TextStyle(fontWeight: FontWeight.w600)),
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
}