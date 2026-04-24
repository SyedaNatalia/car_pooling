import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/booking_model.dart';
import '../../data/services/ride_service.dart';

class ManageRequestsScreen extends StatefulWidget {
  final String rideId;
  const ManageRequestsScreen({super.key, required this.rideId});

  @override
  State<ManageRequestsScreen> createState() => _ManageRequestsScreenState();
}

class _ManageRequestsScreenState extends State<ManageRequestsScreen> {
  // RideService use karo — direct Firestore nahi
  final _rideService = RideService();

  // ── Accept ─────────────────────────────────────────────────────
  // updateBookingStatus: booking status + availableSeats + passengerIds
  Future<void> _accept(String bookingId) async {
    try {
      await _rideService.updateBookingStatus(bookingId, 'accepted');
      _showSnack('Request accepted ✓', AppTheme.success);
    } catch (e) {
      _showSnack('Error: $e', AppTheme.error);
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
            const Text('Is passenger ki request reject ho jayegi.'),
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
      _showSnack('Error: $e', AppTheme.error);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: () =>
                context.push('/ride/${widget.rideId}/active'),
          ),
        ],
      ),

      // getRideBookings: no orderBy — no composite index needed
      body: StreamBuilder<List<BookingModel>>(
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
          if (bookings.isEmpty) return const _EmptyView();

          final pending =
              bookings.where((b) => b.status == 'pending').toList();
          final accepted =
              bookings.where((b) => b.status == 'accepted').toList();
          final rejected =
              bookings.where((b) => b.status == 'rejected').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (pending.isNotEmpty) ...[
                _SectionHeader(
                    title: 'Pending Requests',
                    count: pending.length,
                    color: AppTheme.warning),
                const SizedBox(height: 10),
                ...pending.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BookingCard(
                    booking: b,
                    rideId: widget.rideId,
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
                          rideId: widget.rideId,
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
                          rideId: widget.rideId,
                          onAccept: () {},
                          onReject: () {}),
                )),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── Empty view ─────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: AppTheme.bgWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Icon(Icons.inbox_outlined,
              color: AppTheme.textLight, size: 36),
        ),
        const SizedBox(height: 16),
        const Text('No requests yet',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark)),
        const SizedBox(height: 6),
        const Text('Booking requests will appear here',
            style: TextStyle(color: AppTheme.textMedium, fontSize: 13)),
      ]),
    );
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

// ── Section header ─────────────────────────────────────────────────
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

// ── Booking card ───────────────────────────────────────────────────
class _BookingCard extends StatefulWidget {
  final BookingModel booking;
  final String rideId;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const _BookingCard({
    required this.booking,
    required this.rideId,
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

  Future<void> _openChat() async {
    context.push('/chat/${widget.rideId}');
  }

  Future<void> _makeCall() async {
    final phone = widget.booking.passengerPhone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Phone number not available'),
        backgroundColor: AppTheme.warning,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final isPending  = b.status == 'pending';
    final isAccepted = b.status == 'accepted';

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

        // ── Accepted: show msg + call icons ──────────────────────
        if (isAccepted) ...[
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.check_circle_outline,
                color: AppTheme.success, size: 15),
            const SizedBox(width: 6),
            const Expanded(
              child: Text('Passenger accepted',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.success,
                      fontWeight: FontWeight.w500)),
            ),
            // Message button
            GestureDetector(
              onTap: _openChat,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.chat_bubble_outline,
                    color: AppTheme.primary, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            // Call button
            GestureDetector(
              onTap: _makeCall,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.call_outlined,
                    color: AppTheme.success, size: 18),
              ),
            ),
          ]),
        ],

        // ── Pending: show accept/reject buttons ──────────────────
        if (isPending) ...[
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 12),
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
                onPressed: (_isAccepting || _isRejecting)
                    ? null
                    : () async {
                        setState(() => _isAccepting = true);
                        await Future.microtask(widget.onAccept);
                        if (mounted) {
                          setState(() => _isAccepting = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
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