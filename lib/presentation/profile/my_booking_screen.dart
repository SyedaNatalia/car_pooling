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

  // No orderBy to avoid composite index requirement — sort client-side
  Stream<List<BookingModel>> get _bookingsStream =>
      FirebaseFirestore.instance
          .collection('bookings')
          .where('passengerId', isEqualTo: _uid)
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
      body: StreamBuilder<List<BookingModel>>(
        stream: _bookingsStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary));
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
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                        color: AppTheme.textDark)),
                const SizedBox(height: 6),
                const Text('Your ride bookings will appear here',
                    style: TextStyle(color: AppTheme.textMedium, fontSize: 13)),
                const SizedBox(height: 20),
              ]),
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

  Color get _statusColor {
    switch (widget.booking.status) {
      case 'accepted': return AppTheme.success;
      case 'rejected': return AppTheme.error;
      case 'cancelled': return AppTheme.error;
      default:         return AppTheme.warning;
    }
  }

  String get _statusLabel {
    final s = widget.booking.status;
    return s[0].toUpperCase() + s.substring(1);
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

              // Departure time + driver
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
                Text(
                  _ride!.rideType[0].toUpperCase() + _ride!.rideType.substring(1),
                  style: const TextStyle(fontSize: 11, color: AppTheme.primary,
                      fontWeight: FontWeight.w500),
                ),
              ]),
            ] else
              const Text('Ride details unavailable',
                  style: TextStyle(fontSize: 12, color: AppTheme.textLight)),

            const SizedBox(height: 8),

            // Pickup point
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
          ],
        ),
      ),
    );
  }
}
