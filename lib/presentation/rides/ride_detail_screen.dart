import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/ride_service.dart';
import '../../data/models/ride_model.dart';

class RideDetailScreen extends StatefulWidget {
  final String rideId;
  const RideDetailScreen({super.key, required this.rideId});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  final _rideService = RideService();
  RideModel? _ride;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRide();
  }

  Future<void> _loadRide() async {
  final ride = await _rideService.getRideById(widget.rideId);
    if (mounted) setState(() { _ride = ride; _isLoading = false; });
}

  // FIX: call karne ka function
  Future<void> _callNumber(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone.trim());
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open dialer')),
        );
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
    final isDriver    = ride.driverId == currentUid;
    final isPassenger = ride.passengerIds.contains(currentUid);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Ride Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: [
          // FIX: call button — driver ko passenger call kare, passenger ko driver call kare
          if (!isDriver && ride.driverPhone != null)
            IconButton(
              icon: const Icon(Icons.call_outlined),
              tooltip: 'Call Driver',
              onPressed: () => _callNumber(ride.driverPhone),
            ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.push('/chat/${ride.id}'),
),
        ],
      ),
      bottomNavigationBar: isDriver
          ? null // driver ke liye book button nahi
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: ElevatedButton(
                onPressed: ride.availableSeats > 0
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
                        ? NetworkImage(ride.driverPhoto!) : null,
                    child: ride.driverPhoto == null
                        ? Text(ride.driverName.substring(0, 1).toUpperCase(),
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
                            color: AppTheme.textDark,
                          )),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                            Text('${ride.driverRating.toStringAsFixed(1)} rating',
                              style: const TextStyle(fontSize: 13, color: AppTheme.textMedium)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // FIX: call button directly on driver card (passenger side)
                  if (!isDriver && ride.driverPhone != null) ...[
                    const SizedBox(width: 8),
                  InkWell(
                      onTap: () => _callNumber(ride.driverPhone),
  borderRadius: BorderRadius.circular(24),
  child: Container(
    padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryLight,
                          shape: BoxShape.circle,
                        ),
    child: const Icon(Icons.call, color: AppTheme.primary, size: 20),
  ),
), 
                  ] else ...[
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
                          fontWeight: FontWeight.w500,
                        ),
                    ),
                  ),
                ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Time & Date
            _InfoCard(
              icon: Icons.access_time_rounded,
              label: 'Departure time',
              value: DateFormat('EEEE, MMMM d • h:mm a').format(ride.departureTime),
            ),

            const SizedBox(height: 12),

            // Route card — FIX: exact addresses dikhao
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
                      color: AppTheme.textMedium,
                    )),
                  const SizedBox(height: 14),
                  _RouteStop(
                      dot: Colors.blue,
                      label: 'Start',
                    address: ride.startPoint.address,
                  ),
                  if (ride.stops.isNotEmpty) ...[
                    ...ride.stops.map((s) => _RouteStop(
                        dot: Colors.orange,
                        label: 'Stop',
                      address: s.address,
                    )),
                  ],
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
                    const Icon(Icons.info_outline, size: 18, color: Color(0xFFD97706)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(ride.notes!,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF92400E), height: 1.5)),
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
  const _InfoCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
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
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMedium)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    color: AppTheme.textDark,
                  )),
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
              width: 10, height: 10,
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
                  style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
                const SizedBox(height: 2),
                Text(address,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                    color: AppTheme.textDark,
                  )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}