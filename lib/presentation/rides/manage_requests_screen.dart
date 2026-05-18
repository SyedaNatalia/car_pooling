// ignore_for_file: deprecated_member_use

import 'package:car_pooling/core/utils/snack_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/ride_model.dart';
import '../../data/services/ride_service.dart';
import '../../presentation/widgets/animated_empty_state.dart';

class ManageRequestsScreen extends StatefulWidget {
  final String rideId;
  const ManageRequestsScreen({super.key, required this.rideId});

  @override
  State<ManageRequestsScreen> createState() => _ManageRequestsScreenState();
}

class _ManageRequestsScreenState extends State<ManageRequestsScreen> {
  final _rideService = RideService();

  RideModel? _ride;
  bool _loadingRide = true;
  bool _editingNotes = false;
  bool _savingNotes = false;
  late TextEditingController _notesController;
  double? _editPrice;
  bool _editingPrice = false;
  bool _savingPrice = false;
  late TextEditingController _priceController;
  bool _editingSeats = false;
  bool _savingSeats = false;
  int _editSeats = 1;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _priceController = TextEditingController();
    _loadRide();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadRide() async {
    try {
      final ride = await _rideService.getRideById(widget.rideId);
      if (mounted) {
        setState(() {
          _ride = ride;
          _loadingRide = false;
          if (ride != null) {
            _notesController.text = ride.notes ?? '';
            _priceController.text = ride.pricePerSeat > 0 ? ride.pricePerSeat.toStringAsFixed(0) : '';
            _editSeats = ride.totalSeats;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRide = false);
    }
  }

  Future<void> _saveSeats() async {
    if (_ride == null) return;
    final bookedSeats = _ride!.totalSeats - _ride!.availableSeats;
    if (_editSeats < bookedSeats) {
      _showSnack('Cannot set seats lower than already booked ($bookedSeats)', AppTheme.error);
      return;
    }
    setState(() => _savingSeats = true);
    try {
      final newAvailable = _editSeats - bookedSeats;
      await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
        'totalSeats': _editSeats,
        'availableSeats': newAvailable,
      });
      if (mounted) {
        setState(() {
          _editingSeats = false;
          _savingSeats = false;
          _ride = _ride!.copyWith(totalSeats: _editSeats, availableSeats: newAvailable);
        });
      }
      _showSnack('Seats updated ✓', AppTheme.success);
    } catch (e) {
      if (mounted) setState(() => _savingSeats = false);
      showErrorSnack(context, e);  
    }
  }

  Future<void> _saveNotes() async {
    if (_ride == null) return;
    setState(() => _savingNotes = true);
    final newNotes = _notesController.text.trim();
    try {
      await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
        'notes': newNotes,
      });
      if (mounted) {
        setState(() {
          _editingNotes = false;
          _savingNotes  = false;
          _ride = _ride!.copyWith(notes: newNotes);
        });
      }
      _showSnack('Notes updated ✓', AppTheme.success);
    } catch (e) {
      if (mounted) setState(() => _savingNotes = false);
      showErrorSnack(context, e);

    }
  }

  Future<void> _savePrice() async {
    if (_ride == null) return;
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    setState(() => _savingPrice = true);
    try {
      await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
        'pricePerSeat': price,
      });
      if (mounted) {
        setState(() {
          _editingPrice = false;
          _savingPrice  = false;
          _ride = _ride!.copyWith(pricePerSeat: price);
        });
      }
      _showSnack('Price updated ✓', AppTheme.success);
    } catch (e) {
      if (mounted) setState(() => _savingPrice = false);
      showErrorSnack(context, e);
    }
  }

  // ── Accept ─────────────────────────────────────────────────────
  Future<void> _accept(String bookingId) async {
    try {
      await _rideService.updateBookingStatus(bookingId, 'accepted');
      _showSnack('Request accepted ✓', AppTheme.success);
    } catch (e) {
      showErrorSnack(context, e);
    }
  }

  // ── Reject ─────────────────────────────────────────────────────
  Future<void> _reject(String bookingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Request?',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700)),
        content:
            const Text('This passenger\'s request will be declined.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _rideService.updateBookingStatus(bookingId, 'rejected');
      _showSnack('Request rejected', AppTheme.error);
    } catch (e) {
      showErrorSnack(context, e);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Manage Ride'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.directions_car_outlined),
            tooltip: 'Start Ride',
            onPressed: () =>
                context.push('/ride/${widget.rideId}/active'),
          ),
        ],
      ),

      resizeToAvoidBottomInset: true,
body: SingleChildScrollView(
  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
  child: Column(
    children: [
          if (_loadingRide)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(color: AppTheme.primary),
            )
          else if (_ride != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0,2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.route, color: AppTheme.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text('Your Ride', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                    const Spacer(),
                    GestureDetector(
                      onTap: DateTime.now().isAfter(_ride!.departureTime)
                          ? null
                          : () => setState(() {
                              _editingSeats = !_editingSeats;
                              _editSeats = _ride!.totalSeats;
                            }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(
                            '${_ride!.availableSeats}/${_ride!.totalSeats} seats',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_outlined, size: 11, color: AppTheme.primary),
                        ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Column(children: [
                      const Icon(Icons.radio_button_checked, color: AppTheme.success, size: 14),
                      Container(width: 1, height: 22, color: AppTheme.border),
                      const Icon(Icons.location_on_outlined, color: AppTheme.error, size: 14),
                    ]),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_ride!.startPoint.address, style: const TextStyle(fontSize: 12, color: AppTheme.textDark, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 14),
                      Text(_ride!.endPoint.address, style: const TextStyle(fontSize: 12, color: AppTheme.textDark, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ])),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.access_time, size: 13, color: AppTheme.textLight),
                    const SizedBox(width: 4),
                    Text(DateFormat('EEE, d MMM  •  h:mm a').format(_ride!.departureTime),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMedium)),
                    const SizedBox(width: 12),
                    if (_ride!.carName.isNotEmpty) ...[
                      const Icon(Icons.directions_car, size: 13, color: AppTheme.textLight),
                      const SizedBox(width: 4),
                      Text(_ride!.carName, style: const TextStyle(fontSize: 11, color: AppTheme.textMedium)),
                    ],
                  ]),
                  const Divider(height: 20, color: AppTheme.border),
                  if (_editingSeats) ...[ 
                    Row(children: [
                      const Icon(Icons.event_seat_outlined, size: 14, color: AppTheme.textLight),
                      const SizedBox(width: 6),
                      const Text('Total Seats:', style: TextStyle(fontSize: 12, color: AppTheme.textMedium)),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _editSeats > ((_ride!.totalSeats - _ride!.availableSeats).clamp(1, 3)) ? () => setState(() => _editSeats--) : null,
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: _editSeats > ((_ride!.totalSeats - _ride!.availableSeats).clamp(1, 3)) ? AppTheme.primaryLight : AppTheme.border.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.remove, size: 16, color: AppTheme.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('$_editSeats', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _editSeats < 3 ? () => setState(() => _editSeats++) : null,
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: _editSeats < 3 ? AppTheme.primaryLight : AppTheme.border.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.add, size: 16, color: AppTheme.primary),
                        ),
                      ),
                      const Spacer(),
                      _savingSeats
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                          : TextButton(onPressed: _saveSeats, child: const Text('Save', style: TextStyle(color: AppTheme.primary, fontSize: 12))),
                      TextButton(onPressed: () => setState(() => _editingSeats = false), child: const Text('✕', style: TextStyle(color: AppTheme.textLight, fontSize: 12))),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      'Already booked: ${_ride!.totalSeats - _ride!.availableSeats} seat(s)',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textLight),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(children: [
                    const Text("Rs", style: TextStyle(color: AppTheme.textLight, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    if (!_editingPrice) ...[
                      Text(
                        _ride!.pricePerSeat > 0 ? 'Rs ${_ride!.pricePerSeat.toStringAsFixed(0)}/seat' : 'Free ride',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMedium),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: DateTime.now().isAfter(_ride!.departureTime)
                            ? null
                            : () => setState(() {
                                _editingPrice = true;
                                _priceController.text = _ride!.pricePerSeat > 0 ? _ride!.pricePerSeat.toStringAsFixed(0) : '';
                              }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(8)),
                          child: const Text('Edit Price', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ] else ...[
                      Expanded(child: TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
                        decoration: const InputDecoration(
                          hintText: 'Price per seat (Rs)',
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          isDense: true,
                        ),
                      )),
                      const SizedBox(width: 8),
                      _savingPrice
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                          : TextButton(onPressed: _savePrice, child: const Text('Save', style: TextStyle(color: AppTheme.primary, fontSize: 12))),
                      TextButton(onPressed: () => setState(() => _editingPrice = false), child: const Text('✕', style: TextStyle(color: AppTheme.textLight, fontSize: 12))),
                    ],
                  ]),
                  const SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.notes, size: 14, color: AppTheme.textLight),
                    const SizedBox(width: 4),
                    if (!_editingNotes) ...[
                      Expanded(child: Text(
                        _ride!.notes?.isNotEmpty == true ? _ride!.notes! : 'No notes — tap to add',
                        style: TextStyle(fontSize: 12, color: _ride!.notes?.isNotEmpty == true ? AppTheme.textMedium : AppTheme.textLight),
                      )),
                      GestureDetector(
                        onTap: DateTime.now().isAfter(_ride!.departureTime)
                            ? null
                            : () => setState(() { _editingNotes = true; _notesController.text = _ride!.notes ?? ''; }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(8)),
                          child: const Text('Edit Notes', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ] else ...[
                      Expanded(child: TextField(
                        controller: _notesController,
                        maxLines: 2,
                        autofocus: true,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
                        decoration: const InputDecoration(
                          hintText: 'Add notes for riders...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          isDense: true,
                        ),
                      )),
                      const SizedBox(width: 8),
                      Column(children: [
                        _savingNotes
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                            : TextButton(onPressed: _saveNotes, child: const Text('Save', style: TextStyle(color: AppTheme.primary, fontSize: 12))),
                        TextButton(onPressed: () => setState(() => _editingNotes = false), child: const Text('✕', style: TextStyle(color: AppTheme.textLight, fontSize: 12))),
                      ]),
                    ],
                  ]),
                ],
              ),
            ),

          const SizedBox(height: 8),
          // ── Booking Requests list ────────────────────────────────
          StreamBuilder<List<BookingModel>>(
    stream: _rideService.getRideBookings(widget.rideId),
              builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }

          if (snapshot.hasError) {
            return _ErrorView(message: snapshot.error.toString());
          }

          final bookings = snapshot.data ?? [];
          if (bookings.isEmpty) {
            return const AnimatedEmptyState(
              icon: Icons.inbox_outlined,
              title: 'No booking requests yet',
              subtitle: 'Riders who book your ride\nwill appear here.',
            );
          }

          final pending =
              bookings.where((b) => b.status == 'pending').toList();
          final accepted =
              bookings.where((b) => b.status == 'accepted').toList();
          final rejected =
              bookings.where((b) => b.status == 'rejected').toList();

          final seatsFull = (_ride?.availableSeats ?? 1) <= 0;

          return ListView(
  padding: const EdgeInsets.all(16),
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  children: [
              if (pending.isNotEmpty) ...[
                if (seatsFull)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.event_seat, color: AppTheme.error, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'All seats are full. You cannot accept more requests unless you free up a seat or increase total seats.',
                            style: TextStyle(fontSize: 12, color: AppTheme.error, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                _SectionHeader(
                    title: 'Pending Requests',
                    count: pending.length,
                    color: AppTheme.warning),
                const SizedBox(height: 10),
                ...pending.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BookingCard(
                    booking: b,
                    seatsFull: seatsFull,
                    onAccept: () => _accept(b.id),
                    onReject: () => _reject(b.id),
                  ),
                )),
                const SizedBox(height: 8),
              ],
              if (accepted.isNotEmpty) ...[
                _SectionHeader(
                    title: 'Accepted',
                    count: accepted.length,
                    color: AppTheme.success),
                const SizedBox(height: 10),
                ...accepted.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                      child: _BookingCard(
                          booking: b,
                          onAccept: () {},
                          onReject: () {}),
                )),
                const SizedBox(height: 8),
              ],
              if (rejected.isNotEmpty) ...[
                _SectionHeader(
                    title: 'Rejected',
                    count: rejected.length,
                    color: AppTheme.error),
                const SizedBox(height: 10),
                ...rejected.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                      child: _BookingCard(
                          booking: b,
                          onAccept: () {},
                          onReject: () {}),
                )),
              ],
            ],
          );
         },
        ),
       ],
      ),
    ));
  }
}


// ── Error view ─────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.wifi_off_rounded,
                color: AppTheme.error, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('Something went wrong',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.textMedium, fontSize: 13)),
        ]),
      ),
    );
  }
}
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  const _SectionHeader(
      {required this.title, required this.count, required this.color});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(title,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark)),
      const SizedBox(width: 8),
      Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$count',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color)),
      ),
    ]);
  }
}

class _BookingCard extends StatefulWidget {
  final BookingModel booking;
  final bool seatsFull;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const _BookingCard({
    required this.booking,
    this.seatsFull = false,
    required this.onAccept,
    required this.onReject,
  });
  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  bool _isAccepting = false;
  bool _isRejecting = false;

  Color get _statusColor {
    switch (widget.booking.status) {
      case 'accepted': return AppTheme.success;
      case 'rejected': return AppTheme.error;
      default:         return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final isPending = b.status == 'pending';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: [
        Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primaryLight,
            backgroundImage: b.passengerPhoto != null
                ? NetworkImage(b.passengerPhoto!)
                : null,
            child: b.passengerPhoto == null
                ? Text(
                    b.passengerName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.passengerName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.airline_seat_recline_normal,
                      size: 12, color: AppTheme.textLight),
                  const SizedBox(width: 3),
                  Text('${b.seatsNeeded} seat${b.seatsNeeded != 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMedium)),
                  if (b.offeredPrice > 0) ...[
                    const SizedBox(width: 10),
                    const Text("Rs", style: TextStyle(color: AppTheme.textLight, fontSize: 10, fontWeight: FontWeight.w600)),
                    Text('Rs ${b.offeredPrice.toStringAsFixed(0)}/seat',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMedium)),
                  ],
                  if (b.passengerGender != null && b.passengerGender!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: b.passengerGender!.toLowerCase() == 'female'
                            ? const Color(0xFFFCE4EC)
                            : const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            b.passengerGender!.toLowerCase() == 'female'
                                ? Icons.female
                                : Icons.male,
                            size: 11,
                            color: b.passengerGender!.toLowerCase() == 'female'
                                ? const Color(0xFFAD1457)
                                : const Color(0xFF1565C0),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            b.passengerGender!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: b.passengerGender!.toLowerCase() == 'female'
                                  ? const Color(0xFFAD1457)
                                  : const Color(0xFF1565C0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      size: 12, color: AppTheme.textLight),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(b.pickupPoint.address,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMedium),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
                if (b.passengerNotes != null && b.passengerNotes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.note_outlined,
                          size: 12, color: AppTheme.textLight),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          b.passengerNotes!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMedium,
                              fontStyle: FontStyle.italic),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              b.status[0].toUpperCase() + b.status.substring(1),
              style: TextStyle(
                  color: _statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ]),

        if (isPending) ...[
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 12),
          if (widget.seatsFull)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.block, size: 13, color: AppTheme.error.withOpacity(0.7)),
                  const SizedBox(width: 6),
                  Text(
                    'Seats full — cannot accept',
                    style: TextStyle(fontSize: 11, color: AppTheme.error.withOpacity(0.8), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: (_isAccepting || _isRejecting)
                    ? null
                    : () async {
                        setState(() => _isRejecting = true);
                        await Future.microtask(widget.onReject);
                        if (mounted) {
                          setState(() => _isRejecting = false);
                        }
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: const BorderSide(color: AppTheme.error),
                  minimumSize: const Size(0, 42),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _isRejecting
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            color: AppTheme.error, strokeWidth: 2))
                    : const Text('Reject'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: (_isAccepting || _isRejecting || widget.seatsFull)
                    ? null
                    : () async {
                        setState(() => _isAccepting = true);
                        await Future.microtask(widget.onAccept);
                        if (mounted) {
                          setState(() => _isAccepting = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.seatsFull ? AppTheme.border : AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 42),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _isAccepting
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Accept'),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}