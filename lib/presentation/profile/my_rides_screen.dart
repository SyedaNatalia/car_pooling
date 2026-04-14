// lib/presentation/profile/my_rides_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/ride_model.dart';

class MyRidesScreen extends StatelessWidget {
  const MyRidesScreen({super.key});

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<List<RideModel>> get _ridesStream => FirebaseFirestore.instance
      .collection('rides')
      .where('driverId', isEqualTo: _uid)
      .orderBy('departureTime', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => RideModel.fromMap(d.data(), d.id))
          .toList());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('My Rides'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Offer new ride shortcut
          TextButton.icon(
            onPressed: () => context.push('/offer-ride'),
            icon: const Icon(Icons.add, size: 18, color: AppTheme.primary),
            label: const Text('Offer',
                style: TextStyle(color: AppTheme.primary, fontSize: 13)),
          ),
        ],
      ),
      body: StreamBuilder<List<RideModel>>(
        stream: _ridesStream,
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

          final rides = snap.data ?? [];

          if (rides.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.bgWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Icon(Icons.drive_eta,
                      color: AppTheme.textLight, size: 36),
                ),
                const SizedBox(height: 16),
                const Text("You haven't offered any rides",
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600,
                        color: AppTheme.textDark)),
                const SizedBox(height: 6),
                const Text('Tap "Offer" to create your first ride',
                    style: TextStyle(color: AppTheme.textMedium, fontSize: 13)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => context.push('/offer-ride'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Offer a ride'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ]),
            );
          }

          // Group by status
          final upcoming  = rides.where((r) => r.status == 'upcoming').toList();
          final active    = rides.where((r) => r.status == 'active').toList();
          final completed = rides.where((r) => r.status == 'completed').toList();
          final cancelled = rides.where((r) => r.status == 'cancelled').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (active.isNotEmpty) ...[
                _SectionLabel(title: 'Active', color: AppTheme.primary),
                const SizedBox(height: 8),
                ...active.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DriverRideCard(ride: r),
                    )),
                const SizedBox(height: 8),
              ],
              if (upcoming.isNotEmpty) ...[
                _SectionLabel(title: 'Upcoming', color: AppTheme.warning),
                const SizedBox(height: 8),
                ...upcoming.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DriverRideCard(ride: r),
                    )),
                const SizedBox(height: 8),
              ],
              if (completed.isNotEmpty) ...[
                _SectionLabel(title: 'Completed', color: AppTheme.success),
                const SizedBox(height: 8),
                ...completed.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DriverRideCard(ride: r),
                    )),
                const SizedBox(height: 8),
              ],
              if (cancelled.isNotEmpty) ...[
                _SectionLabel(title: 'Cancelled', color: AppTheme.error),
                const SizedBox(height: 8),
                ...cancelled.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DriverRideCard(ride: r),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionLabel({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 3, height: 14, color: color,
          margin: const EdgeInsets.only(right: 8)),
      Text(title,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: AppTheme.textDark)),
    ]);
  }
}

class _DriverRideCard extends StatelessWidget {
  final RideModel ride;
  const _DriverRideCard({required this.ride});

  Color get _statusColor {
    switch (ride.status) {
      case 'completed': return AppTheme.success;
      case 'cancelled': return AppTheme.error;
      case 'active':    return AppTheme.primary;
      default:          return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookedSeats = ride.totalSeats - ride.availableSeats;
    return GestureDetector(
      onTap: () => context.push('/ride/${ride.id}/requests'),
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
            // Date + Status
            Row(children: [
              Text(
                DateFormat('EEE, d MMM  •  h:mm a').format(ride.departureTime),
                style: const TextStyle(fontSize: 12, color: AppTheme.textMedium),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ride.status[0].toUpperCase() + ride.status.substring(1),
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: _statusColor),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // Route
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

            // Footer
            Row(children: [
              const Icon(Icons.people_outline,
                  size: 15, color: AppTheme.textLight),
              const SizedBox(width: 4),
              Text('$bookedSeats/${ride.totalSeats} booked',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textMedium)),
              const Spacer(),
              if (ride.status == 'upcoming')
                TextButton(
                  onPressed: () =>
                      context.push('/ride/${ride.id}/requests'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Manage requests',
                      style: TextStyle(fontSize: 12)),
                )
              else
                const Icon(Icons.arrow_forward_ios,
                    size: 12, color: AppTheme.textLight),
            ]),
          ],
        ),
      ),
    );
  }
}