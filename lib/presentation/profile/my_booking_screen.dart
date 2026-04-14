// lib/presentation/profile/my_bookings_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/ride_model.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Stream: all bookings made by this user ─────────────────────
  Stream<List<BookingModel>> get _bookingsStream =>
      FirebaseFirestore.instance
          .collection('bookings')
          .where('passengerId', isEqualTo: _uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs
              .map((d) => BookingModel.fromMap(d.data(), d.id))
              .toList());

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
      body: StreamBuilder<List<BookingModel>>(
        stream: _bookingsStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary));
          }
          if (snap.hasError) {
            return Center(
                child: Text('Error: ${snap.error}',
                    style: const TextStyle(color: AppTheme.textMedium)));
          }
          final bookings = snap.data ?? [];
          if (bookings.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.bgWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Icon(Icons.bookmark_border,
                      color: AppTheme.textLight, size: 36),
                ),
                const SizedBox(height: 16),
                const Text('No bookings yet',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600,
                        color: AppTheme.textDark)),
                const SizedBox(height: 6),
                const Text('Your ride bookings will appear here',
                    style: TextStyle(color: AppTheme.textMedium, fontSize: 13)),
              ]),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _BookingCard(booking: bookings[i]),
          );
        },
      ),
    );
  }
}

// ── Booking card with ride details fetched from Firestore ──────────
class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  const _BookingCard({required this.booking});

  Color get _statusColor {
    switch (booking.status) {
      case 'accepted': return AppTheme.success;
      case 'rejected': return AppTheme.error;
      default:         return AppTheme.warning;
    }
  }

  Future<RideModel?> _fetchRide() async {
    final doc = await FirebaseFirestore.instance
        .collection('rides')
        .doc(booking.rideId)
        .get();
    if (!doc.exists) return null;
    return RideModel.fromMap(doc.data()!, doc.id);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RideModel?>(
      future: _fetchRide(),
      builder: (context, snap) {
        final ride = snap.data;
        return Container(
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
                  DateFormat('d MMM yyyy').format(booking.createdAt),
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textMedium),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    booking.status[0].toUpperCase() +
                        booking.status.substring(1),
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: _statusColor),
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // Ride route (from Firestore) or loading
              if (snap.connectionState == ConnectionState.waiting)
                const Center(
                    child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            color: AppTheme.primary)))
              else if (ride != null) ...[
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Column(children: [
                    const Icon(Icons.radio_button_checked,
                        color: AppTheme.success, size: 16),
                    Container(width: 1, height: 28,
                        color: AppTheme.border.withOpacity(0.6)),
                    const Icon(Icons.location_on,
                        color: AppTheme.error, size: 16),
                  ]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ride.startPoint.address,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500,
                                color: AppTheme.textDark),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 18),
                        Text(ride.endPoint.address,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500,
                                color: AppTheme.textDark),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppTheme.border),
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.access_time,
                      size: 14, color: AppTheme.textLight),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('EEE, d MMM  •  h:mm a')
                        .format(ride.departureTime),
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMedium),
                  ),
                ]),
              ] else
                const Text('Ride details unavailable',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textLight)),

              const SizedBox(height: 8),

              // Pickup point
              Row(children: [
                const Icon(Icons.my_location,
                    size: 14, color: AppTheme.textLight),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('Pickup: ${booking.pickupPoint.address}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMedium),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }
}