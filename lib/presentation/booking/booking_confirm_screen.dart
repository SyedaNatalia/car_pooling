import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/ride_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/models/ride_model.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/user_model.dart';

class BookingConfirmScreen extends StatefulWidget {
  final String rideId;
  const BookingConfirmScreen({super.key, required this.rideId});

  @override
  State<BookingConfirmScreen> createState() => _BookingConfirmScreenState();
}

class _BookingConfirmScreenState extends State<BookingConfirmScreen> {
  final _rideService = RideService();
  final _authService = AuthService();
  RideModel? _ride;
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isBooking = false;
  bool _bookingDone = false;
  String _pickupAddress = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ride = await _rideService.getRideById(widget.rideId);
    final user = await _authService.getCurrentUserProfile();
    if (mounted) {
      setState(() {
        _ride = ride;
        _currentUser = user;
        _pickupAddress = ride?.startPoint.address ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmBooking() async {
    if (_ride == null || _currentUser == null) return;
    setState(() => _isBooking = true);

    try {
      final booking = BookingModel(
        id: '',
        rideId: widget.rideId,
        passengerId: _currentUser!.uid,
        passengerName: _currentUser!.name,
        passengerPhoto: _currentUser!.photoUrl,
        pickupPoint: LocationPoint(
          address: _pickupAddress,
          lat: _ride!.startPoint.lat,
          lng: _ride!.startPoint.lng,
        ),
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await _rideService.createBooking(booking);
      if (mounted) setState(() => _bookingDone = true);
    } catch (e) {
  if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already booked this ride.'),
      backgroundColor: AppTheme.error,
          ),
        );
  }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    }

    if (_bookingDone) return _BookingSuccessView(ride: _ride!);

    final ride = _ride!;
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Confirm Booking'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: ElevatedButton(
          onPressed: _isBooking ? null : _confirmBooking,
          child: _isBooking
              ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Text('Confirm Booking'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary card
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
                  const Text('Booking Summary',
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                  const SizedBox(height: 16),
                  _SummaryRow(icon: Icons.person_outline, label: 'Driver', value: ride.driverName),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    icon: Icons.access_time_rounded,
                    label: 'Departure',
                    value: DateFormat('EEE, MMM d • h:mm a').format(ride.departureTime),
                  ),
                  const SizedBox(height: 12),
                  _SummaryRow(icon: Icons.location_on_outlined, label: 'To', value: ride.endPoint.address),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    icon: Icons.airline_seat_recline_normal,
                    label: 'Seats available',
                    value: '${ride.availableSeats} of ${ride.totalSeats}',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            const Text('Your pickup point',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _pickupAddress,
              onChanged: (v) => _pickupAddress = v,
              decoration: const InputDecoration(
                hintText: 'Enter your pickup location',
                prefixIcon: Icon(Icons.my_location, color: AppTheme.primary),
              ),
            ),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.primary, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your request will be sent to the driver. You\'ll be notified once accepted.',
                      style: TextStyle(fontSize: 12, color: AppTheme.primary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SummaryRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppTheme.textLight),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                style: const TextStyle(fontSize: 13, color: AppTheme.textMedium)),
              Flexible(
                child: Text(value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookingSuccessView extends StatelessWidget {
  final RideModel ride;
  const _BookingSuccessView({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 52),
              ),
              const SizedBox(height: 24),
              const Text('Request sent!',
                style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
              const SizedBox(height: 10),
              Text(
                'Your booking request has been sent to ${ride.driverName}.\nYou\'ll get notified when they accept.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMedium, fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Back to Home'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.push('/chat/${ride.id}'),
                child: const Text('Contact',
                  style: TextStyle(color: AppTheme.primary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}