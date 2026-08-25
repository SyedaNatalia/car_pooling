// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/shimmer_widget.dart';
import '../../data/models/ride_model.dart';
import '../../data/services/ride_service.dart';
import '../widgets/animated_empty_state.dart';

class MyRidesScreen extends StatelessWidget {
  const MyRidesScreen({super.key});

  Stream<List<RideModel>> _ridesStream(String uid) =>
      FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: uid)
          .snapshots()
          .map((s) {
            final list = s.docs.map((d) => RideModel.fromMap(d.data(), d.id)).toList();
            list.sort((a, b) => b.departureTime.compareTo(a.departureTime));
            return list;
          });

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
      ),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnap) {
          if (authSnap.connectionState == ConnectionState.waiting ||
              authSnap.data == null) {
            return const ShimmerRideList(count: 4);
          }
          final uid = authSnap.data!.uid;
          return StreamBuilder<List<RideModel>>(
            stream: _ridesStream(uid),
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
                  Text('Could not load rides.\n${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textMedium, fontSize: 13)),
                ]),
              ),
            );
          }

          final rides = snap.data ?? [];

          if (rides.isEmpty) {
            return const AnimatedEmptyState(
              icon: Icons.drive_eta_outlined,
              title: 'No rides offered yet',
              subtitle: 'Your published rides will appear here.\nOffer a ride to get started!',
            );
          }

          final active    = rides.where((r) => r.status == 'active').toList();
          final upcoming  = rides.where((r) => r.status == 'upcoming').toList();
          final completed = rides.where((r) => r.status == 'completed').toList();
          final cancelled = rides.where((r) => r.status == 'cancelled' || r.status == 'expired').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (active.isNotEmpty) ...[
                const _SectionLabel(title: 'Active', color: AppTheme.primary),
                const SizedBox(height: 8),
                ...active.map((r) => Padding(padding: const EdgeInsets.only(bottom: 10),
                    child: _DriverRideCard(ride: r))),
                const SizedBox(height: 8),
              ],
              if (upcoming.isNotEmpty) ...[
                const _SectionLabel(title: 'Upcoming', color: AppTheme.warning),
                const SizedBox(height: 8),
                ...upcoming.map((r) => Padding(padding: const EdgeInsets.only(bottom: 10),
                    child: _DriverRideCard(ride: r))),
                const SizedBox(height: 8),
              ],
              if (completed.isNotEmpty) ...[
                const _SectionLabel(title: 'Completed', color: AppTheme.success),
                const SizedBox(height: 8),
                ...completed.map((r) => Padding(padding: const EdgeInsets.only(bottom: 10),
                    child: _DriverRideCard(ride: r))),
                const SizedBox(height: 8),
              ],
              if (cancelled.isNotEmpty) ...[
               const _SectionLabel(title: 'Cancelled / Expired', color: AppTheme.error),
                const SizedBox(height: 8),
                ...cancelled.map((r) => Padding(padding: const EdgeInsets.only(bottom: 10),
                    child: _DriverRideCard(ride: r))),
              ],
            ],
          );
        },
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
      Container(width: 3, height: 14, color: color, margin: const EdgeInsets.only(right: 8)),
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
    ]);
  }
}

class _DriverRideCard extends StatelessWidget {
  final RideModel ride;
  const _DriverRideCard({required this.ride});

  Color get _statusColor {
    switch (ride.status) {
      case 'completed': return AppTheme.success;
      case 'cancelled':
      case 'expired':   return AppTheme.error;
      case 'active':    return AppTheme.primary;
      default:          return AppTheme.warning;
    }
  }

  String _statusLabel() {
    switch (ride.status) {
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      case 'expired':   return 'Expired';
      case 'active':    return 'Active';
      default:          return 'Upcoming';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookedSeats = ride.totalSeats - ride.availableSeats;
    final isFinished = ride.status == 'completed' ||
        ride.status == 'cancelled' ||
        ride.status == 'expired';

    return GestureDetector(
      onTap: isFinished
          ? null
          : () {
              if (ride.status == 'active') {
                context.push('/ride/${ride.id}/active');
              } else {
                context.push('/ride/${ride.id}/requests');
              }
            },
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
            Row(children: [
              Text(
                DateFormat('EEE, d MMM  •  h:mm a').format(ride.departureTime),
                style: const TextStyle(fontSize: 12, color: AppTheme.textMedium),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(_statusLabel(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor)),
              ),
            ]),
            const SizedBox(height: 12),

            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                const Icon(Icons.radio_button_checked, color: AppTheme.success, size: 16),
                Container(width: 1, height: 28, color: AppTheme.border.withOpacity(0.6)),
                const Icon(Icons.location_on, color: AppTheme.error, size: 16),
              ]),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ride.startPoint.address,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                        color: AppTheme.textDark),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 18),
                Text(ride.endPoint.address,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                        color: AppTheme.textDark),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
            ]),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 10),

            Row(children: [
              const Icon(Icons.directions_car_outlined, size: 16, color: AppTheme.textLight),
              const SizedBox(width: 6),
              if (ride.carName.isNotEmpty) ...[
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(8)),
                    child: Text(ride.carName,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppTheme.primary,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (ride.pricePerSeat > 0)
                Text('Rs ${ride.pricePerSeat.toStringAsFixed(0)}/seat',
                    style: const TextStyle(fontSize: 11, color: AppTheme.success,
                        fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              const Icon(Icons.people_outline, size: 14, color: AppTheme.textLight),
              const SizedBox(width: 3),
              Text('$bookedSeats/${ride.totalSeats}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMedium)),
            ]),
            if (ride.status == 'upcoming') ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => context.push('/ride/${ride.id}/requests'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary, padding: EdgeInsets.zero,
                      minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Manage', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Row(
                            children: [
                              Icon(Icons.directions_car_outlined, color: AppTheme.error, size: 22),
                              SizedBox(width: 8),
                              Text('Cancel Ride?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          content: const Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Are you sure you want to cancel this ride?',
                                  style: TextStyle(fontSize: 14, color: AppTheme.textDark)),
                              SizedBox(height: 8),
                              Text('• All passengers will be notified',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textMedium)),
                              Text('• All bookings will be cancelled',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textMedium)),
                              Text('• This action cannot be undone',
                                  style: TextStyle(fontSize: 12, color: AppTheme.error)),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('No, Keep It', style: TextStyle(color: AppTheme.textMedium)),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.error,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Yes, Cancel'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        // 5-minute cancel window for driver
                        final minutesSinceCreated = DateTime.now().difference(ride.createdAt).inMinutes;
                        if (minutesSinceCreated > 5) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(children: [
                                Icon(Icons.timer_off, color: Colors.white, size: 18),
                                SizedBox(width: 10),
                                Expanded(child: Text('Cancel window expired. Rides can only be cancelled within 5 minutes of publishing.')),
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
                        try {
                          await RideService().cancelRide(ride.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ride cancelled. All passengers have been notified.'),
                              backgroundColor: AppTheme.success,
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: AppTheme.error,
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ));
                          }
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(fontSize: 12, color: AppTheme.error, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.textLight),
              ),
            ],
          ],
        ),
      ),
    );
  }
}