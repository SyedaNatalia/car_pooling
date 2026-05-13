import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/ride_model.dart';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});
  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<List<RideModel>> get _driverRides => FirebaseFirestore.instance
      .collection('rides')
      .where('driverId', isEqualTo: _uid)
      .snapshots()
      .map((s) {
        final list = s.docs
            .map((d) => RideModel.fromMap(d.data(), d.id))
            .toList();
        list.sort((a, b) => b.departureTime.compareTo(a.departureTime));
        return list;
      });

  Stream<List<RideModel>> get _passengerRides => FirebaseFirestore.instance
      .collection('rides')
      .where('passengerIds', arrayContains: _uid)
      .snapshots()
      .map((s) {
        final list = s.docs
            .map((d) => RideModel.fromMap(d.data(), d.id))
            .toList();
        list.sort((a, b) => b.departureTime.compareTo(a.departureTime));
        return list;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Ride History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textMedium,
          indicatorColor: AppTheme.primary,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(text: 'As Passenger'),
            Tab(text: 'As Driver'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RideList(stream: _passengerRides, emptyMsg: 'No rides taken yet'),
          _RideList(stream: _driverRides,    emptyMsg: 'No rides offered yet'),
        ],
      ),
    );
  }
}

class _RideList extends StatelessWidget {
  final Stream<List<RideModel>> stream;
  final String emptyMsg;
  const _RideList({required this.stream, required this.emptyMsg});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RideModel>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
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
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.bgWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Icon(Icons.directions_car_outlined,
                    color: AppTheme.textLight, size: 36),
              ),
              const SizedBox(height: 16),
              Text(emptyMsg,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                      color: AppTheme.textDark)),
            ]),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rides.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _RideCard(ride: rides[i]),
        );
      },
    );
  }
}

class _RideCard extends StatelessWidget {
  final RideModel ride;
  const _RideCard({required this.ride});

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
            Row(children: [
              Text(
                DateFormat('EEE, d MMM yyyy  •  h:mm a').format(ride.departureTime),
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
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: _statusColor),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // Route with real addresses
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                const Icon(Icons.radio_button_checked, color: AppTheme.success, size: 16),
                Container(width: 1, height: 28, color: AppTheme.border.withOpacity(0.6)),
                const Icon(Icons.location_on, color: AppTheme.error, size: 16),
              ]),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ride.startPoint.address,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                          color: AppTheme.textDark),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 18),
                  Text(ride.endPoint.address,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ride.carName.isNotEmpty ? ride.carName : ride.driverName,
                  style: const TextStyle(fontSize: 11, color: AppTheme.primary,
                      fontWeight: FontWeight.w500),
                ),
              ),
              const Spacer(),
              const Icon(Icons.people_outline, size: 15, color: AppTheme.textLight),
              const SizedBox(width: 4),
              Text('${ride.totalSeats} seats',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMedium)),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.textLight),
            ]),
          ],
        ),
      );
  }
}