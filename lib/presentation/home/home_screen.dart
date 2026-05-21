// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/ride_model.dart';
import '../../data/providers/app_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _expireTimer;

  @override
  void initState() {
    super.initState();
    // Expire stale rides on app open — fire-and-forget, result not awaited.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rideServiceProvider).autoExpireRides();
    });
    // Re-check every minute so expired rides are removed from the home screen
    // without requiring a logout or app restart.
    _expireTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      // Only hit Firestore if the user currently has an active booking.
      final hasBooking = ref.read(activeBookingProvider).valueOrNull != null;
      if (hasBooking) ref.read(rideServiceProvider).autoExpireRides();
    });
  }

  @override
  void dispose() {
    _expireTimer?.cancel();
    super.dispose();
  }

  void _showActiveRideNotice(BuildContext context, {required bool isDriver}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActiveRideNoticeSheet(isDriver: isDriver),
    );
  }

  void _showPassengerBookingSheet(BuildContext context) {
    // Read snapshot value — modal content does not need to be reactive.
    final activeBookedRide = ref.read(activeBookedRideProvider).valueOrNull;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PassengerActiveBookingSheet(
        activeBookedRide: activeBookedRide,
        onDismiss: () => Navigator.pop(context),
        onGoToBookings: () {
          Navigator.pop(context);
          context.push('/my-bookings');
        },
      ),
    );
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
    // All data comes from reactive Riverpod providers — no manual Firestore calls.
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isDriver = user?.carDetails != null &&
        user!.carDetails!.plateNumber.isNotEmpty;

    final activeBookedRide = ref.watch(activeBookedRideProvider).valueOrNull;
    final isLoadingBookedRide = ref.watch(activeBookedRideProvider).isLoading;

    final hasActiveRide = ref.watch(hasActiveRideProvider);
    final hasActiveBooking = ref.watch(hasActiveBookingProvider);

    // Single shared stream — no duplicate Firestore listeners.
    final unreadCount = ref.watch(unreadNotifCountProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: RefreshIndicator(
        // Providers are live streams — refreshing is a UX hint only.
        onRefresh: () => Future.delayed(const Duration(milliseconds: 400)),
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
            user?.name.split(' ').first ?? 'Welcome',
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
        if (unreadCount > 0)
          Positioned(
            right: 6, top: 6,
            child: Container(
              width: 16, height: 16,
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
      ],
    ),
    const SizedBox(width: 4),
    GestureDetector(
      onTap: () => context.go('/profile'),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: Colors.white.withOpacity(0.2),
        backgroundImage: user?.photoUrl != null
            ? NetworkImage(user!.photoUrl!)
            : null,
        child: user?.photoUrl == null
            ? Text(
                user?.name.substring(0, 1).toUpperCase() ?? 'U',
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
                            subtitle: hasActiveRide
                                ? 'Complete your ride first'
                                : 'Book your seat',
                            onTap: () {
                              if (hasActiveRide) {
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
                            subtitle: hasActiveBooking
                                ? 'Cancel booking first'
                                : 'Share your car',
                            onTap: () {
                              if (hasActiveBooking) {
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
            if (activeBookedRide != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: GestureDetector(
                    onTap: () => context.push('/ride/${activeBookedRide.id}'),
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
                            '${activeBookedRide.startPoint.address.split(',').first} → ${activeBookedRide.endPoint.address.split(',').first}',
                            style: const TextStyle(color: Colors.white, fontSize: 15,
                                fontWeight: FontWeight.w700),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.person_outline, size: 13, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(activeBookedRide.driverName,
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(width: 8),
                            const Icon(Icons.access_time, size: 13, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('EEE, MMM d • h:mm a').format(activeBookedRide.departureTime),
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
            if (activeBookedRide == null && !isLoadingBookedRide)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: _HomeEmptyCard(
                    isDriver: isDriver,
                    hasActiveRide: hasActiveRide,
                    hasActiveBooking: hasActiveBooking,
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
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedOpacity(
        opacity: disabled ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: disabled ? 0.08 : 0.18),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
                color: Colors.white.withValues(alpha: disabled ? 0.15 : 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(
                disabled
                    ? Icons.lock_outline_rounded
                    : Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.6),
                size: 18,
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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)
        .drive(Tween(begin: 0.0, end: 1.0));
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
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
            Container(
              width: 88, height: 88,
              decoration: const BoxDecoration(
                  color: AppTheme.primaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.directions_car_rounded,
                  color: AppTheme.primary, size: 44),
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