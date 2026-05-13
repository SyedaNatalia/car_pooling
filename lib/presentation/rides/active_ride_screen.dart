import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/ride_service.dart';
import '../../data/models/ride_model.dart';

class ActiveRideScreen extends StatefulWidget {
  final String rideId;
  const ActiveRideScreen({super.key, required this.rideId});

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  final _rideService = RideService();
  RideModel? _ride;
  bool _isLoading = true;
  bool _rideStarted = false;

  final List<Map<String, dynamic>> _mockPassengers = [
  {'name': 'Ali Hassan'},
  {'name': 'Sara Khan'},
];

  @override
  void initState() {
    super.initState();
    _loadRide();
  }

  Future<void> _loadRide() async {
    final ride = await _rideService.getRideById(widget.rideId);
    if (mounted) setState(() { _ride = ride; _isLoading = false; });
  }

  Future<void> _startRide() async {
    await _rideService.updateRideStatus(widget.rideId, 'active');
    setState(() => _rideStarted = true);
  }

  Future<void> _endRide() async {
    await _rideService.updateRideStatus(widget.rideId, 'completed');
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Ride Completed!',
            style: TextStyle(fontWeight: FontWeight.w700)),
          content: const Text('Great job! The ride has been marked as completed.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/home');
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    }

    final ride = _ride;
    if (ride == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Active Ride')),
        body: const Center(child: Text('Ride not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(_rideStarted ? 'Ride in Progress' : 'Start Ride'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.push('/chat/${ride.id}'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status banner
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: _rideStarted ? AppTheme.success : AppTheme.warning,
            child: Row(
              children: [
                Icon(
                  _rideStarted ? Icons.radio_button_checked : Icons.pending_outlined,
                  color: Colors.white, size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _rideStarted
                        ? 'Ride is live — passengers have been notified'
                        : 'Ready to start? Press the button below',
                    style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Map placeholder
          Expanded(
            child: Stack(
              children: [
                Container(
                  color: const Color(0xFFE8EFF4),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.map_outlined, size: 64, color: AppTheme.textLight),
                        const SizedBox(height: 12),
                        const Text('Map View',
                          style: TextStyle(color: AppTheme.textMedium, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                          '${ride.startPoint.address.split(',').first} → ${ride.endPoint.address.split(',').first}',
                          style: const TextStyle(color: AppTheme.textLight, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                // Passengers overlay
                if (_rideStarted)
                  Positioned(
                    bottom: 16, left: 16, right: 16,
                    child: _PassengersOverlay(passengers: _mockPassengers),
                  ),
              ],
            ),
          ),

          // Bottom action
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: _rideStarted
                ? ElevatedButton(
                    onPressed: _endRide,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                    child: const Text('End Ride'),
                  )
                : ElevatedButton(
                    onPressed: _startRide,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                    child: const Text('Start Ride'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PassengersOverlay extends StatelessWidget {
  final List<Map<String, dynamic>> passengers;
  const _PassengersOverlay({required this.passengers});

  @override
  Widget build(BuildContext context) {
    if (passengers.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${passengers.length} passenger${passengers.length != 1 ? 's' : ''} on board',
            style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: passengers.map((p) => _PassengerChip(
              name: p['name'] as String,
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _PassengerChip extends StatelessWidget {
  final String name;
  const _PassengerChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppTheme.primaryLight,
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          Text(name.split(' ').first,
            style: const TextStyle(fontSize: 12, color: AppTheme.textDark)),
        ],
      ),
    );
  }
}