import 'package:car_pooling/core/utils/snack_helper.dart';
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
  double _pickupLat = 0;
  double _pickupLng = 0;
  int _seatsNeeded = 1;
  double _offeredPrice = 0;
  String? _passengerGender;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ride = await _rideService.getRideById(widget.rideId);
    final user = await _authService.getCurrentUserProfile();
    if (mounted) {
      setState(() {
        _ride = ride;
        _currentUser = user;
        _pickupAddress = ride?.startPoint.address ?? '';
        _pickupLat = ride?.startPoint.lat ?? 0;
        _pickupLng = ride?.startPoint.lng ?? 0;
        _offeredPrice = ride?.pricePerSeat ?? 0;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmBooking() async {
    if (_ride == null || _currentUser == null) return;
    if (_seatsNeeded > _ride!.availableSeats) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Only ${_ride!.availableSeats} seats available'),
            backgroundColor: AppTheme.error),
      );
      return;
    }
    setState(() => _isBooking = true);
    try {
      final booking = BookingModel(
        id: '',
        rideId: widget.rideId,
        passengerId: _currentUser!.uid,
        passengerName: _currentUser!.name,
        passengerPhoto: _currentUser!.photoUrl,
        passengerGender: _passengerGender,
        pickupPoint: LocationPoint(
          address: _pickupAddress,
          lat: _pickupLat,
          lng: _pickupLng,
        ),
        seatsNeeded: _seatsNeeded,
        offeredPrice: _offeredPrice,
        status: 'pending',
        passengerNotes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: DateTime.now(),
      );
      await _rideService.createBooking(booking);
      if (mounted) setState(() => _bookingDone = true);
    } catch (e) {
  if (mounted) {
    showErrorSnack(context, e);
  }
}
    finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Widget _buildStopChip({
    required String label,
    required String address,
    required double lat,
    required double lng,
  }) {
    final isSelected = _pickupAddress == address && _pickupLat == lat;
    return GestureDetector(
      onTap: () => setState(() {
        _pickupAddress = address;
        _pickupLat = lat;
        _pickupLng = lng;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.bgWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on,
                size: 13,
                color: isSelected ? Colors.white : AppTheme.textLight),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : AppTheme.textDark),
            ),
          ],
        ),
      ),
    );
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
              : const Text('Send Booking Request'),
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
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                  const SizedBox(height: 16),
                  _SummaryRow(icon: Icons.person_outline,    label: 'Driver',     value: ride.driverName),
                  const SizedBox(height: 12),
                  if (ride.carName.isNotEmpty)
                    ...[_SummaryRow(icon: Icons.directions_car_outlined, label: 'Car', value: ride.carName),
                    const SizedBox(height: 12)],
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
                  if (ride.pricePerSeat > 0) ...[
                    const SizedBox(height: 12),
                    _SummaryRow(
                      icon: Icons.monetization_on_outlined,
                      label: 'Driver\'s price',
                      value: 'Rs ${ride.pricePerSeat.toStringAsFixed(0)} / seat',
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Seats needed selector
            const Text('Seats needed',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.bgWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.airline_seat_recline_normal, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Number of seats',
                        style: TextStyle(fontSize: 13, color: AppTheme.textMedium)),
                  ),
                  _StepButton(
                    icon: Icons.remove,
                    onTap: _seatsNeeded > 1
                        ? () => setState(() => _seatsNeeded--)
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('$_seatsNeeded',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary)),
                  ),
                  _StepButton(
                    icon: Icons.add,
                    onTap: _seatsNeeded < ride.availableSeats
                        ? () => setState(() => _seatsNeeded++)
                        : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Pickup address
            const Text('Your pickup point',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
            const SizedBox(height: 4),
            const Text('Select a stop or type your own address',
                style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
            const SizedBox(height: 8),

            // ── Stop selector chips (startPoint + any stops) ──────────
            if (ride.stops.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildStopChip(
                    label: 'Start point',
                    address: ride.startPoint.address,
                    lat: ride.startPoint.lat,
                    lng: ride.startPoint.lng,
                  ),
                  ...ride.stops.asMap().entries.map((e) => _buildStopChip(
                        label: 'Stop ${e.key + 1}',
                        address: e.value.address,
                        lat: e.value.lat,
                        lng: e.value.lng,
                      )),
                ],
              ),
              const SizedBox(height: 10),
            ],

            TextFormField(
              key: ValueKey(_pickupAddress),
              initialValue: _pickupAddress,
              onChanged: (v) => setState(() {
                _pickupAddress = v;
                // When user types manually, reset coordinates to 0
                // so driver knows it's a custom address without a pin
                _pickupLat = 0;
                _pickupLng = 0;
              }),
              decoration: const InputDecoration(
                hintText: 'Enter your pickup location',
                prefixIcon: Icon(Icons.my_location, color: AppTheme.primary),
              ),
            ),

            const SizedBox(height: 20),

            // Gender selector
            const Text('Your Gender',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
            const SizedBox(height: 4),
            const Text('Helps the driver know who is joining',
                style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
            const SizedBox(height: 10),
            Row(
              children: [
                _GenderChip(label: 'Male',   icon: Icons.male,   selected: _passengerGender == 'male',   onTap: () => setState(() => _passengerGender = 'male')),
                const SizedBox(width: 10),
                _GenderChip(label: 'Female', icon: Icons.female, selected: _passengerGender == 'female', onTap: () => setState(() => _passengerGender = 'female')),
                const SizedBox(width: 10),
                _GenderChip(label: 'Other',  icon: Icons.person_outline, selected: _passengerGender == 'other', onTap: () => setState(() => _passengerGender = 'other')),
              ],
            ),

            const SizedBox(height: 20),

            // Notes field
            const Text('Notes (optional)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
            const SizedBox(height: 4),
            const Text('Any special request or info for the driver',
                style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Write Your Note',
                alignLabelWithHint: true,
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

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: onTap != null ? AppTheme.primary : AppTheme.border,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
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
              Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMedium)),
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
                child: const Icon(Icons.check_circle_outline, color: AppTheme.primary, size: 52),
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
            ],
          ),
        ),
      ),
    );
  }
}
class _GenderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : AppTheme.bgWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: selected ? Colors.white : AppTheme.textMedium),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppTheme.textMedium,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
