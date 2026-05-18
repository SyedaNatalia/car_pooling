// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snack_helper.dart';
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

  // Live tracking
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  LatLng? _driverLocation;
  StreamSubscription<Map<String, double?>>? _driverLocSub;

  @override
  void initState() {
    super.initState();
    _loadRide();
  }

  Future<void> _loadRide() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
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
      if (ride != null && ride.status == 'active') {
        _startDriverTracking(ride.id);
      }
    }
  }

  void _startDriverTracking(String rideId) {
    _driverLocSub?.cancel();
    _driverLocSub =
        _rideService.getDriverLocationStream(rideId).listen((loc) {
      final lat = loc['lat'];
      final lng = loc['lng'];
      if (lat == null || lng == null) return;
      final pos = LatLng(lat, lng);
      if (!mounted) return;
      setState(() {
        _driverLocation = pos;
        _markers = {
          Marker(
            markerId: const MarkerId('driver'),
            position: pos,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure),
            infoWindow: const InfoWindow(title: 'Driver'),
            zIndex: 2,
          ),
        };
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
    });
  }

  @override
  void dispose() {
    _driverLocSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // Future<void> _cancelRide(RideModel ride) async {
  //   final confirm = await showDialog<bool>(
  Future<void> _cancelRide(RideModel ride) async {
    final minsLeft = ride.departureTime.difference(DateTime.now()).inMinutes;
    if (minsLeft <= 30) {
      showErrorSnack(context, 'Cannot cancel — less than 30 minutes left before departure.');
      return;
    }
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
        showSuccessSnack(context, 'Ride cancelled successfully.');
        context.pop();
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  // Future<void> _cancelMyBooking(RideModel ride) async {
  //   final confirm = await showDialog<bool>(
  Future<void> _cancelMyBooking(RideModel ride) async {
    final minsLeft = ride.departureTime.difference(DateTime.now()).inMinutes;
    if (minsLeft <= 30) {
      showErrorSnack(context, 'Cannot cancel — less than 30 minutes left before departure.');
      return;
    }
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
          showErrorSnack(context, 'No active booking found for this ride.');
        }
        return;
      }
      await _rideService.cancelBooking(snap.docs.first.id);
      if (mounted) {
        showSuccessSnack(context, 'Booking cancelled successfully.');
        context.pop();
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
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
    final bookingAccepted = _myBooking?.status == 'accepted';
    final rideIsLive = ride.status == 'upcoming' || ride.status == 'active';
    final bookingIsActive =
        _myBooking?.status == 'pending' || _myBooking?.status == 'accepted';
    final canContact = isDriver
        ? rideIsLive
        : (isPassenger && rideIsLive && bookingIsActive);

    // ── Full-screen tracking layout for active passenger ─────────────
    final showFullMap =
        ride.status == 'active' && isPassenger && bookingAccepted;

    if (showFullMap) {
      return _PassengerTrackingScreen(
        ride: ride,
        myBooking: _myBooking!,
        markers: _markers,
        driverLocation: _driverLocation,
        canContact: canContact,
        onMapCreated: (c) => setState(() => _mapController = c),
      );
    }

    // ── Normal detail layout ──────────────────────────────────────────
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
                ? Builder(builder: (context) {
                    final minsLeft = ride.departureTime.difference(DateTime.now()).inMinutes;
                    final cancelBlocked = minsLeft <= 30;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (cancelBlocked)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Cancel unavailable — less than 30 min to pickup',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppTheme.error.withOpacity(0.8)),
                            ),
                          ),
                        ElevatedButton.icon(
                          onPressed: cancelBlocked ? null : () => _cancelRide(ride),
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Cancel Ride'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cancelBlocked ? AppTheme.border : AppTheme.error,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    );
                  })
                : const SizedBox.shrink())
            : isPassenger
                ? Builder(builder: (context) {
                    final minsLeft = ride.departureTime.difference(DateTime.now()).inMinutes;
                    final cancelBlocked = ride.status == 'upcoming' && minsLeft <= 30;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (cancelBlocked)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Cancel unavailable — less than 30 min to joining',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppTheme.error.withOpacity(0.8)),
                            ),
                          ),
                        ElevatedButton.icon(
                          onPressed: (ride.status == 'upcoming' && !cancelBlocked)
                              ? () => _cancelMyBooking(ride)
                              : null,
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Cancel My Booking'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cancelBlocked ? AppTheme.border : AppTheme.error,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    );
                  })
                : ElevatedButton(
                    onPressed:
                        ride.availableSeats > 0 && ride.status == 'upcoming'
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
            _DriverCard(ride: ride),
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
            _RouteCard(ride: ride),
            if (ride.notes != null && ride.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _NotesCard(notes: ride.notes!),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

// ── Full-screen passenger tracking screen ────────────────────────────

class _PassengerTrackingScreen extends StatelessWidget {
  final RideModel ride;
  final BookingModel myBooking;
  final Set<Marker> markers;
  final LatLng? driverLocation;
  final bool canContact;
  final void Function(GoogleMapController) onMapCreated;

  const _PassengerTrackingScreen({
    required this.ride,
    required this.myBooking,
    required this.markers,
    required this.driverLocation,
    required this.canContact,
    required this.onMapCreated,
  });

  @override
  Widget build(BuildContext context) {
    final startLL = ride.startPoint.lat != 0
        ? LatLng(ride.startPoint.lat, ride.startPoint.lng)
        : const LatLng(24.8607, 67.0011);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Ride in Progress'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (canContact)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () => context.push('/chat/${ride.id}'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: AppTheme.success,
            child: Row(
              children: [
                const Icon(Icons.radio_button_checked,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    driverLocation != null
                        ? 'Driver is on the way — tracking live'
                        : 'Ride started — waiting for driver location…',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Full map
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: driverLocation ?? startLL,
                    zoom: 15,
                  ),
                  onMapCreated: onMapCreated,
                  markers: markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),

                // Live badge
                Positioned(
                  top: 12,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.success,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 2))
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.gps_fixed, color: Colors.white, size: 13),
                        SizedBox(width: 5),
                        Text('Live',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                // Driver info card overlay at bottom
                Positioned(
                  bottom: 70,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 4))
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
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
                                      fontSize: 16),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(ride.driverName,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textDark)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  // const Icon(Icons.star,
                                  //     size: 13, color: Color(0xFFF59E0B)),
                                  // const SizedBox(width: 3),
                                  // Text(
                                  //   ride.driverRating.toStringAsFixed(1),
                                  //   style: const TextStyle(
                                  //       fontSize: 12,
                                  //       color: AppTheme.textMedium),
                                  // ),
                                  if (ride.carName.isNotEmpty) ...[
                                    const Text(' · ',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textLight)),
                                    Text(ride.carName,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textMedium)),
                                  ],
                                ],
                              ),
                              if (ride.carPlate.isNotEmpty)
                                Text(
                                  ride.carPlate,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primary,
                                      letterSpacing: 1),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                myBooking.offeredPrice > 0
                                    ? 'Rs ${myBooking.offeredPrice.toStringAsFixed(0)}'
                                    : 'Rs ${ride.pricePerSeat.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${myBooking.seatsNeeded} seat${myBooking.seatsNeeded != 1 ? 's' : ''}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textMedium),
                            ),
                          ],
                        ),
                      ],
                    ),
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

// ── Shared sub-widgets ────────────────────────────────────────────────

class _DriverCard extends StatelessWidget {
  final RideModel ride;
  const _DriverCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Container(
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
                        fontSize: 20))
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
                // Row(
                //   children: [
                //     const Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
                //     const SizedBox(width: 4),
                //     Text('${ride.driverRating.toStringAsFixed(1)} rating',
                //         style: const TextStyle(
                //             fontSize: 13, color: AppTheme.textMedium)),
                //   ],
                // ),
                if (ride.carName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.directions_car_outlined,
                          size: 14, color: AppTheme.textLight),
                      const SizedBox(width: 4),
                      Text(ride.carName,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textMedium)),
                      if (ride.carColor.isNotEmpty) ...[
                        const Text(' · ',
                            style: TextStyle(
                                fontSize: 13, color: AppTheme.textLight)),
                        Text(ride.carColor,
                            style: const TextStyle(
                                fontSize: 13, color: AppTheme.textMedium)),
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
                      Text(ride.carPlate,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                              letterSpacing: 1)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${ride.availableSeats}/${ride.totalSeats} seats',
              style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final RideModel ride;
  const _RouteCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              address: ride.startPoint.address),
          if (ride.stops.isNotEmpty)
            ...ride.stops.map((s) =>
                _RouteStop(dot: Colors.orange, label: 'Stop', address: s.address)),
          _RouteStop(
              dot: AppTheme.success,
              label: 'End',
              address: ride.endPoint.address,
              isLast: true),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  final String notes;
  const _NotesCard({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFFD97706)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(notes,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF92400E), height: 1.5)),
          ),
        ],
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
      {required this.icon,
      required this.label,
      required this.value,
      this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            highlight ? AppTheme.success.withOpacity(0.07) : AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: highlight
                ? AppTheme.success.withOpacity(0.5)
                : AppTheme.border),
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
  const _RouteStop(
      {required this.dot,
      required this.label,
      required this.address,
      this.isLast = false});

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