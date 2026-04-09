// lib/presentation/rides/offer_ride_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/ride_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/models/ride_model.dart';

class OfferRideScreen extends StatefulWidget {
  const OfferRideScreen({super.key});

  @override
  State<OfferRideScreen> createState() => _OfferRideScreenState();
}

class _OfferRideScreenState extends State<OfferRideScreen> {
  final _formKey = GlobalKey<FormState>();
  int _step = 0;
  bool _isLoading = false;

  // Step 1 fields
  final _startController = TextEditingController();
  final _endController = TextEditingController(text: 'Company Office, Main Campus');
  final List<TextEditingController> _stopControllers = [];

  // Step 2 fields
  DateTime _departureTime = DateTime.now().add(const Duration(hours: 1));
  int _totalSeats = 3;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _notesController.dispose();
    for (final c in _stopControllers) c.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _departureTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 14)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_departureTime),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary)),
        child: child!,
      ),
    );
    if (time == null) return;

    setState(() {
      _departureTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _publishRide() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthService().getCurrentUserProfile();
      if (user == null) throw Exception('User not found');

      final stops = _stopControllers
          .where((c) => c.text.trim().isNotEmpty)
          .map((c) => LocationPoint(address: c.text.trim(), lat: 0, lng: 0))
          .toList();

      final ride = RideModel(
        id: '',
        driverId: user.uid,
        driverName: user.name,
        driverPhoto: user.photoUrl,
        driverRating: user.rating,
        startPoint: LocationPoint(address: _startController.text.trim(), lat: 0, lng: 0),
        endPoint: LocationPoint(address: _endController.text.trim(), lat: 0, lng: 0),
        stops: stops,
        departureTime: _departureTime,
        totalSeats: _totalSeats,
        availableSeats: _totalSeats,
        status: 'upcoming',
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: DateTime.now(),
      );

      final rideId = await RideService().createRide(ride);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride published successfully!'),
            backgroundColor: AppTheme.success),
        );
        context.push('/ride/$rideId/requests');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Start Location',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _startController,
          decoration: const InputDecoration(
            hintText: 'Your starting point',
            prefixIcon: Icon(Icons.my_location, color: AppTheme.primary),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Start location required' : null,
        ),
        const SizedBox(height: 16),

        // Intermediate stops
        if (_stopControllers.isNotEmpty) ...[
          const Text('Stops (optional)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
          const SizedBox(height: 8),
          ..._stopControllers.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: e.value,
                    decoration: InputDecoration(
                      hintText: 'Stop ${e.key + 1}',
                      prefixIcon: const Icon(Icons.add_location_alt_outlined,
                        color: AppTheme.textLight),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() {
                    e.value.dispose();
                    _stopControllers.removeAt(e.key);
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close, color: AppTheme.error, size: 18),
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 4),
        ],

        TextButton.icon(
          onPressed: _stopControllers.length < 3
              ? () => setState(() => _stopControllers.add(TextEditingController()))
              : null,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add a stop'),
          style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
        ),

        const SizedBox(height: 8),
        const Text('End Location',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _endController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.location_on, color: AppTheme.success),
          ),
          validator: (v) => v == null || v.isEmpty ? 'End location required' : null,
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Departure Time',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDateTime,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded, color: AppTheme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat('EEE, MMM d • h:mm a').format(_departureTime),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                const Icon(Icons.edit_outlined, color: AppTheme.textLight, size: 18),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),
        const Text('Available Seats',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SeatButton(
              icon: Icons.remove,
              onTap: _totalSeats > 1
                  ? () => setState(() => _totalSeats--)
                  : null,
            ),
            const SizedBox(width: 24),
            Column(
              children: [
                Text(
                  '$_totalSeats',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
                const Text('seats',
                  style: TextStyle(color: AppTheme.textMedium, fontSize: 13)),
              ],
            ),
            const SizedBox(width: 24),
            _SeatButton(
              icon: Icons.add,
              onTap: _totalSeats < 6
                  ? () => setState(() => _totalSeats++)
                  : null,
            ),
          ],
        ),

        const SizedBox(height: 20),
        const Text('Notes (optional)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'e.g. I can pick up from nearby streets, no pets please...',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Widget _buildReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Review your ride',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
        const SizedBox(height: 16),
        _ReviewRow(label: 'From', value: _startController.text),
        if (_stopControllers.any((c) => c.text.isNotEmpty))
          _ReviewRow(
            label: 'Stops',
            value: _stopControllers
                .where((c) => c.text.isNotEmpty)
                .map((c) => c.text)
                .join(', '),
          ),
        _ReviewRow(label: 'To', value: _endController.text),
        _ReviewRow(
          label: 'Departure',
          value: DateFormat('EEE, MMM d • h:mm a').format(_departureTime),
        ),
        _ReviewRow(label: 'Seats', value: '$_totalSeats seats available'),
        if (_notesController.text.isNotEmpty)
          _ReviewRow(label: 'Notes', value: _notesController.text),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: const [
              Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Once published, colleagues can find and book your ride. You can manage requests from the ride page.',
                  style: TextStyle(fontSize: 12, color: AppTheme.primary, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final stepLabels = ['Set Route', 'Ride Details', 'Review & Publish'];

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(stepLabels[_step]),
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => setState(() => _step--),
              )
            : null,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Step progress
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: List.generate(3, (i) => Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= _step ? AppTheme.primary : AppTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _step == 0
                    ? _buildStep1()
                    : _step == 1
                        ? _buildStep2()
                        : _buildReview(),
              ),
            ),

            // Bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: ElevatedButton(
                onPressed: _isLoading ? null : () {
                  if (_step < 2) {
                    if (_formKey.currentState!.validate()) {
                      setState(() => _step++);
                    }
                  } else {
                    _publishRide();
                  }
                },
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text(_step < 2 ? 'Continue' : 'Publish Ride'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _SeatButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: onTap != null ? AppTheme.primaryLight : AppTheme.bgLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: onTap != null ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Icon(icon,
          color: onTap != null ? AppTheme.primary : AppTheme.textLight,
          size: 22),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(label,
                style: const TextStyle(fontSize: 13, color: AppTheme.textMedium)),
            ),
            Expanded(
              child: Text(value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textDark,
                )),
            ),
          ],
        ),
      ),
    );
  }
}
