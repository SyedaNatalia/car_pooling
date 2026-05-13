// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/ride_service.dart';
import '../../data/models/ride_model.dart';
import '../../data/models/booking_model.dart';

class RideDetailScreen extends StatefulWidget {
  final String rideId;
  const RideDetailScreen({super.key, required this.rideId});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  final _rideService = RideService();
  RideModel? _ride;
  BookingModel? _myBooking;   
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRide();
  }

  Future<void> _loadRide() async {
    final uid  = FirebaseAuth.instance.currentUser?.uid ?? '';
    final ride = await _rideService.getRideById(widget.rideId);

    BookingModel? myBooking;
    if (uid.isNotEmpty) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('bookings')
            .where('rideId', isEqualTo: widget.rideId)
            .where('passengerId', isEqualTo: uid)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          myBooking = BookingModel.fromMap(
              snap.docs.first.data(), snap.docs.first.id);
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
      _ride = ride;
      _myBooking = myBooking;
      _isLoading = false;
    });
    }
  }

  Future<void> _cancelRide(RideModel ride) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Ride?'),
        content: const Text(
            'Are you sure you want to cancel this ride? All passengers will be notified.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _rideService.cancelRide(ride.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Ride cancelled'),
                backgroundColor: AppTheme.success));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: $e'),
                backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _cancelMyBooking(RideModel ride) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Booking?'),
        content: const Text(
            'Are you sure you want to cancel your booking for this ride?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final snap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('rideId', isEqualTo: ride.id)
          .where('passengerId', isEqualTo: currentUid)
          .where('status', whereIn: ['pending', 'accepted']).get();
      if (snap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No active booking found')));
        }
        return;
      }
      await _rideService.cancelBooking(snap.docs.first.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Booking cancelled'),
                backgroundColor: AppTheme.success));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: $e'),
                backgroundColor: AppTheme.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }
    if (_ride == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ride Details')),
        body: const Center(child: Text('Ride not found')),
      );
    }

    final ride = _ride!;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isDriver = ride.driverId == currentUid;
    final isPassenger = ride.passengerIds.contains(currentUid);
    final rideIsLive = ride.status == 'upcoming' || ride.status == 'active';
    final bookingIsActive = _myBooking?.status == 'pending' ||
        _myBooking?.status == 'accepted';
    final canContact = isDriver
        ? rideIsLive  
        : (isPassenger && rideIsLive && bookingIsActive);
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Ride Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (canContact)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () => context.push('/chat/${ride.id}'),
            ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: isDriver
            ? (ride.status == 'upcoming'
                ? ElevatedButton.icon(
                    onPressed: () => _cancelRide(ride),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancel Ride'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white,
                    ),
                  )
                : const SizedBox.shrink())
            : isPassenger
                ? ElevatedButton.icon(
                    onPressed: ride.status == 'upcoming'
                        ? () => _cancelMyBooking(ride)
                        : null,
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancel My Booking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white,
                    ),
                  )
                : ElevatedButton(
                    onPressed: ride.availableSeats > 0 && ride.status == 'upcoming'
                        ? () => context.push('/ride/${ride.id}/book')
                        : null,
                    child: Text(
                      ride.availableSeats > 0
                          ? 'Book this ride — ${ride.availableSeats} seat${ride.availableSeats != 1 ? 's' : ''} left'
                          : 'No seats available',
                    ),
                  ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Driver card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.bgWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primaryLight,
                    backgroundImage: ride.driverPhoto != null
                        ? NetworkImage(ride.driverPhoto!)
                        : null,
                    child: ride.driverPhoto == null
                        ? Text(
                            ride.driverName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ))
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ride.driverName,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                size: 14, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 4),
                            Text(
                              '${ride.driverRating.toStringAsFixed(1)} rating',
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.textMedium),
                            ),
                          ],
                        ),
                        if (ride.carName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.directions_car_outlined,
                                  size: 14, color: AppTheme.textLight),
                              const SizedBox(width: 4),
                              Text(ride.carName,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textMedium)),
                              if (ride.carColor.isNotEmpty) ...[
                                const Text(' · ',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textLight)),
                                Text(ride.carColor,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textMedium)),
                              ],
                            ],
                          ),
                        ],
                        if (ride.carPlate.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.credit_card_outlined,
                                  size: 14, color: AppTheme.textLight),
                              const SizedBox(width: 4),
                              Text(
                                ride.carPlate,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                    letterSpacing: 1),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${ride.availableSeats}/${ride.totalSeats} seats',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (!isDriver) ...[
              if (_myBooking != null && _myBooking!.status == 'accepted') ...[
                _InfoCard(
                  icon: Icons.monetization_on_outlined,
                  label: 'Your confirmed fare',
                  value: _myBooking!.offeredPrice > 0
                      ? 'Rs ${_myBooking!.offeredPrice.toStringAsFixed(0)}/seat'
                      : 'Rs ${ride.pricePerSeat.toStringAsFixed(0)}/seat',
                  highlight: true,
                ),
                const SizedBox(height: 12),
              ] else if (ride.pricePerSeat > 0) ...[
                _InfoCard(
                  icon: Icons.monetization_on_outlined,
                  label: 'Price per seat',
                  value: 'Rs ${ride.pricePerSeat.toStringAsFixed(0)}',
                ),
                const SizedBox(height: 12),
              ],
            ] else if (ride.pricePerSeat > 0) ...[
              _InfoCard(
                icon: Icons.monetization_on_outlined,
                label: 'Price per seat',
                value: 'Rs ${ride.pricePerSeat.toStringAsFixed(0)}',
              ),
              const SizedBox(height: 12),
            ],

            _InfoCard(
              icon: Icons.access_time_rounded,
              label: 'Departure time',
              value: DateFormat('EEEE, MMMM d • h:mm a')
                  .format(ride.departureTime),
            ),

            const SizedBox(height: 12),

            _InfoCard(
              icon: Icons.airline_seat_recline_normal,
              label: 'Seats',
              value:
                  '${ride.availableSeats} available of ${ride.totalSeats} total',
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.bgWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Route',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textMedium)),
                  const SizedBox(height: 14),
                  _RouteStop(
                    dot: Colors.blue,
                    label: 'Start',
                    address: ride.startPoint.address,
                  ),
                  if (ride.stops.isNotEmpty)
                    ...ride.stops.map((s) => _RouteStop(
                          dot: Colors.orange,
                          label: 'Stop',
                          address: s.address,
                        )),
                  _RouteStop(
                    dot: AppTheme.success,
                    label: 'End',
                    address: ride.endPoint.address,
                    isLast: true,
                  ),
                ],
              ),
            ),

            if (ride.notes != null && ride.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: Color(0xFFD97706)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(ride.notes!,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF92400E),
                              height: 1.5)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;
  const _InfoCard(
      {required this.icon, required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? AppTheme.success.withOpacity(0.07) : AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? AppTheme.success.withOpacity(0.5) : AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMedium)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  final Color dot;
  final String label;
  final String address;
  final bool isLast;
  const _RouteStop({
    required this.dot,
    required this.label,
    required this.address,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            if (!isLast)
              Container(width: 1.5, height: 36, color: AppTheme.border),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textLight)),
                const SizedBox(height: 2),
                Text(address,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textDark)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}