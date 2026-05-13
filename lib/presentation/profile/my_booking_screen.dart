// 
// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/shimmer_widget.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/ride_model.dart';
import '../../data/services/ride_service.dart';
import '../widgets/animated_empty_state.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  Stream<List<BookingModel>> _bookingsStream(String uid) =>
      FirebaseFirestore.instance
          .collection('bookings')
          .where('passengerId', isEqualTo: uid)
          .snapshots()
          .map((s) {
            final list = s.docs
                .map((d) => BookingModel.fromMap(d.data(), d.id))
                .toList();
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return list;
          });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('My Bookings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnap) {
          if (authSnap.connectionState == ConnectionState.waiting ||
              authSnap.data == null) {
            return const ShimmerRideList(count: 4);
          }
          final uid = authSnap.data!.uid;
          return StreamBuilder<List<BookingModel>>(
            stream: _bookingsStream(uid),
            builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const ShimmerRideList(count: 4);
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, color: AppTheme.error, size: 40),
                  const SizedBox(height: 12),
                  Text('Could not load bookings.\n${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textMedium, fontSize: 13)),
                ]),
              ),
            );
          }
          final bookings = snap.data ?? [];
          if (bookings.isEmpty) {
            return const AnimatedEmptyState(
              icon: Icons.bookmark_border,
              title: 'No bookings yet',
              subtitle: 'Your ride bookings will appear here.\nSearch for rides to get started!',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {},
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _BookingCard(booking: bookings[i]),
            ),
          );
        },
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatefulWidget {
  final BookingModel booking;
  const _BookingCard({required this.booking});
  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  RideModel? _ride;
  bool _loading = true;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _fetchRide();
  }

  Future<void> _fetchRide() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.booking.rideId)
          .get();
      if (mounted) {
        setState(() {
          _ride = doc.exists ? RideModel.fromMap(doc.data()!, doc.id) : null;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Agar ride ka departure time guzar gaya aur passenger ride join nahi hua
  // toh chahe status kuch bhi ho — "Expired" dikhao
  bool get _isExpiredByTime {
    if (_ride == null) return false;
    final isPastDeparture = DateTime.now().isAfter(_ride!.departureTime);
    final notJoined = widget.booking.status == 'pending' ||
        widget.booking.status == 'cancelled';
    return isPastDeparture && notJoined;
  }

  Color get _statusColor {
    if (_isExpiredByTime) return const Color(0xFFF59E0B);
    switch (widget.booking.status) {
      case 'accepted':  return AppTheme.success;
      case 'rejected':  return AppTheme.error;
      case 'cancelled': return AppTheme.error;
      case 'expired':   return const Color(0xFFF59E0B);
      case 'completed': return AppTheme.success;
      default:          return AppTheme.warning;
    }
  }

  String get _statusLabel {
    if (_isExpiredByTime) return 'Expired';
    switch (widget.booking.status) {
      case 'pending':   return 'Pending';
      case 'accepted':  return 'Accepted';
      case 'rejected':  return 'Rejected';
      case 'cancelled': return 'Cancelled';
      case 'expired':   return 'Expired';
      case 'completed': return 'Completed';
      default:          return widget.booking.status[0].toUpperCase() + widget.booking.status.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/ride/${widget.booking.rideId}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status + date
            Row(children: [
              Text(
                DateFormat('d MMM yyyy').format(widget.booking.createdAt),
                style: const TextStyle(fontSize: 12, color: AppTheme.textMedium),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_statusLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: _statusColor)),
              ),
            ]),
            const SizedBox(height: 12),

            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primary),
                  ),
                ),
              )
            else if (_ride != null) ...[
              // Route with real addresses
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Column(children: [
                  const Icon(Icons.radio_button_checked,
                      color: AppTheme.success, size: 16),
                  Container(width: 1, height: 28,
                      color: AppTheme.border.withOpacity(0.6)),
                  const Icon(Icons.location_on_outlined,
                      color: AppTheme.error, size: 16),
                ]),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_ride!.startPoint.address,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                            color: AppTheme.textDark),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 18),
                    Text(_ride!.endPoint.address,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                            color: AppTheme.textDark),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppTheme.border),
              const SizedBox(height: 10),

              Row(children: [
                const Icon(Icons.access_time, size: 14, color: AppTheme.textLight),
                const SizedBox(width: 4),
                Text(
                  DateFormat('EEE, d MMM  •  h:mm a').format(_ride!.departureTime),
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMedium),
                ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.person_outline, size: 14, color: AppTheme.textLight),
                const SizedBox(width: 4),
                Text('Driver: ${_ride!.driverName}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMedium)),
                const Spacer(),
                if (_ride!.carName.isNotEmpty)
                  Text(
                    _ride!.carName,
                    style: const TextStyle(fontSize: 11, color: AppTheme.primary,
                        fontWeight: FontWeight.w500),
                  ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.airline_seat_recline_normal, size: 14, color: AppTheme.textLight),
                const SizedBox(width: 4),
                Text('${widget.booking.seatsNeeded} seat${widget.booking.seatsNeeded != 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMedium)),
                if (widget.booking.offeredPrice > 0) ...[
                  const SizedBox(width: 10),
                  Text('Rs ${widget.booking.offeredPrice.toStringAsFixed(0)}/seat',
                      style: const TextStyle(fontSize: 12, color: AppTheme.success,
                          fontWeight: FontWeight.w500)),
                ],
              ]),
            ] else
              const Text('Ride details unavailable',
                  style: TextStyle(fontSize: 12, color: AppTheme.textLight)),

            const SizedBox(height: 8),

            Row(children: [
              const Icon(Icons.my_location, size: 14, color: AppTheme.textLight),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Pickup: ${widget.booking.pickupPoint.address}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMedium),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),

            if (widget.booking.status == 'pending' || widget.booking.status == 'accepted') ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppTheme.border),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: _isCancelling
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.error.withOpacity(0.2)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: AppTheme.error,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Cancelling...',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GestureDetector(
                        onTap: () async {
                          if (_isCancelling) return;

                          final minutesSinceBooked = DateTime.now().difference(widget.booking.createdAt).inMinutes;
                          if (minutesSinceBooked > 5) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(children: [
                                  Icon(Icons.timer_off, color: Colors.white, size: 18),
                                  SizedBox(width: 10),
                                  Expanded(child: Text('Cancel expired. Bookings can only be cancelled within 5 minutes of booking.')),
                                ]),
                                backgroundColor: AppTheme.warning,
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                            return;
                          }

                          final confirm = await showDialog<bool>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: const Row(
                                children: [
                                  Icon(Icons.cancel_outlined,
                                      color: AppTheme.error, size: 22),
                                  SizedBox(width: 8),
                                  Text('Cancel Booking?',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                              content: const Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Are you sure you want to cancel this booking?',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: AppTheme.textDark)),
                                  SizedBox(height: 8),
                                  Text('• The driver will be notified',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textMedium)),
                                  Text('• Your seat will be released',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textMedium)),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('No, Keep It',
                                      style: TextStyle(
                                          color: AppTheme.textMedium)),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.error,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Yes, Cancel'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && context.mounted) {
                            setState(() => _isCancelling = true);
                            try {
                              await RideService()
                                  .cancelBooking(widget.booking.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                        'Booking cancelled. The driver has been notified.'),
                                    backgroundColor: AppTheme.success,
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) setState(() => _isCancelling = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: AppTheme.error,
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Cancel Booking',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.error,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}