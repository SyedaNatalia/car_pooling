// lib/presentation/rides/manage_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/ride_model.dart';

// Mock booking requests
final _mockBookings = [
  BookingModel(
    id: 'bk_001',
    rideId: 'ride_001',
    passengerId: 'user_003',
    passengerName: 'Usman Tariq',
    pickupPoint: LocationPoint(address: 'DHA Phase 6, Lahore', lat: 31.4900, lng: 74.4050),
    status: 'pending',
    createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
  ),
  BookingModel(
    id: 'bk_002',
    rideId: 'ride_001',
    passengerId: 'user_004',
    passengerName: 'Fatima Malik',
    pickupPoint: LocationPoint(address: 'DHA Phase 4, Lahore', lat: 31.4750, lng: 74.3920),
    status: 'accepted',
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  BookingModel(
    id: 'bk_003',
    rideId: 'ride_001',
    passengerId: 'user_005',
    passengerName: 'Bilal Ahmed',
    pickupPoint: LocationPoint(address: 'DHA Phase 5, Lahore', lat: 31.4816, lng: 74.3985),
    status: 'pending',
    createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
  ),
];

class ManageRequestsScreen extends StatefulWidget {
  final String rideId;
  const ManageRequestsScreen({super.key, required this.rideId});

  @override
  State<ManageRequestsScreen> createState() => _ManageRequestsScreenState();
}

class _ManageRequestsScreenState extends State<ManageRequestsScreen> {
  late List<BookingModel> _bookings;

  @override
  void initState() {
    super.initState();
    // Clone mock data so we can update state locally
    _bookings = _mockBookings
        .where((b) => b.rideId == widget.rideId || true) // show all for demo
        .map((b) => BookingModel(
              id: b.id,
              rideId: b.rideId,
              passengerId: b.passengerId,
              passengerName: b.passengerName,
              passengerPhoto: b.passengerPhoto,
              pickupPoint: b.pickupPoint,
              status: b.status,
              createdAt: b.createdAt,
            ))
        .toList();
  }

  void _accept(String bookingId) {
    setState(() {
      final idx = _bookings.indexWhere((b) => b.id == bookingId);
      if (idx != -1) {
        final b = _bookings[idx];
        _bookings[idx] = BookingModel(
          id: b.id, rideId: b.rideId,
          passengerId: b.passengerId, passengerName: b.passengerName,
          passengerPhoto: b.passengerPhoto, pickupPoint: b.pickupPoint,
          status: 'accepted', createdAt: b.createdAt,
        );
      }
    });
  }

  void _reject(String bookingId) {
    setState(() {
      final idx = _bookings.indexWhere((b) => b.id == bookingId);
      if (idx != -1) {
        final b = _bookings[idx];
        _bookings[idx] = BookingModel(
          id: b.id, rideId: b.rideId,
          passengerId: b.passengerId, passengerName: b.passengerName,
          passengerPhoto: b.passengerPhoto, pickupPoint: b.pickupPoint,
          status: 'rejected', createdAt: b.createdAt,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pending = _bookings.where((b) => b.status == 'pending').toList();
    final accepted = _bookings.where((b) => b.status == 'accepted').toList();
    final rejected = _bookings.where((b) => b.status == 'rejected').toList();

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Booking Requests'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.directions_car_outlined),
            tooltip: 'Start Ride',
            onPressed: () => context.push('/ride/${widget.rideId}/active'),
          ),
        ],
      ),
      body: _bookings.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.bgWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Icon(Icons.inbox_outlined, color: AppTheme.textLight, size: 36),
                  ),
                  const SizedBox(height: 16),
                  const Text('No requests yet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                  const SizedBox(height: 6),
                  const Text('Booking requests will appear here',
                    style: TextStyle(color: AppTheme.textMedium, fontSize: 13)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (pending.isNotEmpty) ...[
                  _SectionHeader(title: 'Pending Requests', count: pending.length, color: AppTheme.warning),
                  const SizedBox(height: 10),
                  ...pending.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BookingCard(booking: b, onAccept: () => _accept(b.id), onReject: () => _reject(b.id)),
                  )),
                  const SizedBox(height: 8),
                ],
                if (accepted.isNotEmpty) ...[
                  _SectionHeader(title: 'Accepted', count: accepted.length, color: AppTheme.success),
                  const SizedBox(height: 10),
                  ...accepted.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BookingCard(booking: b, onAccept: () {}, onReject: () {}),
                  )),
                  const SizedBox(height: 8),
                ],
                if (rejected.isNotEmpty) ...[
                  _SectionHeader(title: 'Rejected', count: rejected.length, color: AppTheme.error),
                  const SizedBox(height: 10),
                  ...rejected.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BookingCard(booking: b, onAccept: () {}, onReject: () {}),
                  )),
                ],
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  const _SectionHeader({required this.title, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text('$count',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ),
      ],
    );
  }
}

class _BookingCard extends StatefulWidget {
  final BookingModel booking;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _BookingCard({
    required this.booking,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  bool _isProcessing = false;

  Future<void> _handle(VoidCallback action) async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 500));
    action();
    if (mounted) setState(() => _isProcessing = false);
  }

  Color get _statusColor {
    switch (widget.booking.status) {
      case 'accepted': return AppTheme.success;
      case 'rejected': return AppTheme.error;
      default: return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primaryLight,
                child: Text(
                  b.passengerName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.passengerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600, color: AppTheme.textDark, fontSize: 14)),
                    Text(b.pickupPoint.address,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMedium),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  b.status[0].toUpperCase() + b.status.substring(1),
                  style: TextStyle(color: _statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),

          if (b.status == 'pending') ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : () => _handle(widget.onReject),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                      minimumSize: const Size(0, 40),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : () => _handle(widget.onAccept),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
                    child: _isProcessing
                        ? const SizedBox(height: 16, width: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}