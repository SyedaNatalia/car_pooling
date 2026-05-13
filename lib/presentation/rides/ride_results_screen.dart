// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../presentation/widgets/animated_empty_state.dart';
import '../../data/services/ride_service.dart';
import '../../data/models/ride_model.dart';

class RideResultsScreen extends StatefulWidget {
  final DateTime date;
  final String? fromCity;
  final String? toCity;
  const RideResultsScreen({super.key, required this.date, this.fromCity, this.toCity});

  @override
  State<RideResultsScreen> createState() => _RideResultsScreenState();
}

class _RideResultsScreenState extends State<RideResultsScreen> with WidgetsBindingObserver {
  final _rideService = RideService();
  List<RideModel> _rides = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  DateTime? _lastUpdated;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRides();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !_isRefreshing) _silentRefresh();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _silentRefresh();
  }

  Future<void> _loadRides() async {
    if (mounted) setState(() { _isLoading = true; _errorMessage = null; });
    await _fetch(silent: false);
  }

  Future<void> _refreshRides() async {
    if (mounted) setState(() { _isRefreshing = true; _errorMessage = null; });
    await _fetch(silent: false);
  }

  Future<void> _silentRefresh() => _fetch(silent: true);

  Future<void> _fetch({required bool silent}) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final upcoming = await _rideService.searchRidesByStatus(
        status: 'upcoming',
        date: widget.date,
        excludeDriverId: uid,
        fromCity: widget.fromCity,
        toCity: widget.toCity,
      );
      final active = await _rideService.searchRidesByStatus(
        status: 'active',
        date: widget.date,
        excludeDriverId: uid,
        fromCity: widget.fromCity,
        toCity: widget.toCity,
      );
      final seen = <String>{};
      final merged = [...upcoming, ...active]
          .where((r) => seen.add(r.id))
          .toList()
        ..sort((a, b) => a.departureTime.compareTo(b.departureTime));
      if (mounted) {
        setState(() {
          _rides = merged;
          _lastUpdated = DateTime.now();
          _isLoading = false;
          _isRefreshing = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          if (!silent) _errorMessage = 'Could not load rides. Please check your connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fromCity = widget.fromCity ?? '';
    final toCity = widget.toCity ?? '';
    final hasRouteFilter = fromCity.isNotEmpty || toCity.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Available Rides', style: TextStyle(fontSize: 16)),
            Text(
              DateFormat('EEE, MMM d').format(widget.date),
              style: const TextStyle(fontSize: 12, color: AppTheme.textMedium),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: _refreshRides,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _errorMessage != null
              ? _ErrorView(message: _errorMessage!, onRetry: _loadRides)
              : RefreshIndicator(
                  onRefresh: _refreshRides,
                  color: AppTheme.primary,
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: AppTheme.primaryLight.withOpacity(0.6),
                        child: Row(
                          children: [
                            Container(
                              width: 7, height: 7,
                              decoration: const BoxDecoration(
                                  color: AppTheme.success, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_rides.length} ride${_rides.length != 1 ? "s" : ""} • auto-refreshes every 10s',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMedium),
                            ),
                            const Spacer(),
                            if (_lastUpdated != null)
                              Text(
                                'Updated ${DateFormat("h:mm:ss a").format(_lastUpdated!)}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _rides.isEmpty
                            ? _EmptyResults(
                                date: widget.date,
                                hasRouteFilter: hasRouteFilter,
                                fromCity: fromCity,
                                toCity: toCity,
                                onRefresh: _refreshRides,
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _rides.length,
                                itemBuilder: (ctx, i) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _RideResultCard(ride: _rides[i]),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _RideResultCard extends StatelessWidget {
  final RideModel ride;
  const _RideResultCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    final hasCarInfo = ride.carName.isNotEmpty ||
        ride.carColor.isNotEmpty ||
        ride.carPlate.isNotEmpty;

    return GestureDetector(
      onTap: () => context.push('/ride/${ride.id}'),
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
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primaryLight,
                  backgroundImage: ride.driverPhoto != null
                      ? NetworkImage(ride.driverPhoto!)
                      : null,
                  child: ride.driverPhoto == null
                      ? Text(
                          ride.driverName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ride.driverName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 13, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 3),
                          Text(
                            ride.driverRating.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMedium),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('h:mm a').format(ride.departureTime),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                        fontSize: 16,
                      ),
                    ),
                    if (ride.pricePerSeat > 0)
                      Text(
                        'Rs ${ride.pricePerSeat.toStringAsFixed(0)}/seat',
                        style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.success),
                      ),
                    Text(
                      '${ride.availableSeats} seat${ride.availableSeats != 1 ? 's' : ''} left',
                      style: TextStyle(
                        fontSize: 12,
                        color: ride.availableSeats <= 1
                            ? AppTheme.error
                            : AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 12),

            if (hasCarInfo) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_car, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        [
                          if (ride.carName.isNotEmpty) ride.carName,
                          if (ride.carColor.isNotEmpty) ride.carColor,
                          if (ride.carPlate.isNotEmpty) '• ${ride.carPlate}',
                        ].join(' '),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            Row(
              children: [
                Column(
                  children: [
                    Container(width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(width: 1.5, height: 24, color: AppTheme.border),
                    Container(width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.success,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ride.startPoint.address,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textDark,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        ride.endPoint.address,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textMedium),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: ride.availableSeats > 0
                    ? () => context.push('/ride/${ride.id}/book')
                    : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  ride.availableSeats > 0 ? 'Book this ride' : 'Full',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Icon(Icons.wifi_off_rounded, color: Colors.orange.shade600, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Connection Problem',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMedium, height: 1.5, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(180, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state — route not match ─────────────────────────
class _EmptyResults extends StatelessWidget {
  final DateTime date;
  final bool hasRouteFilter;
  final String fromCity;
  final String toCity;
  final VoidCallback? onRefresh;
  const _EmptyResults({
    required this.date,
    required this.hasRouteFilter,
    required this.fromCity,
    required this.toCity,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = hasRouteFilter
        ? 'No rides found on this route.\nTry a different date or pull down to refresh.'
        : 'No rides available on\n${DateFormat("EEEE, MMMM d").format(date)}';
    return AnimatedEmptyState(
      icon: Icons.search_off_rounded,
      title: 'No Rides Found',
      subtitle: subtitle,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Search Again'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(140, 44)),
          ),
          if (onRefresh != null) ...[ 
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(110, 44),
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}