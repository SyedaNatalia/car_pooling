// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ride_model.dart';
import 'status_badge.dart';

/// A rich, scannable ride card used on the results screen and home screen.
class RideListCard extends StatelessWidget {
  final RideModel ride;
  final bool isFull;
  final bool showStatus;

  const RideListCard({
    super.key,
    required this.ride,
    this.isFull = false,
    this.showStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    final from = ride.startPoint.address.split(',').first.trim();
    final to = ride.endPoint.address.split(',').first.trim();
    final timeStr = DateFormat('h:mm a').format(ride.departureTime);
    final dateStr = DateFormat('EEE, MMM d').format(ride.departureTime);
    final hasAC = ride.acAvailable;
    final driverInitial =
        ride.driverName.isNotEmpty ? ride.driverName[0].toUpperCase() : 'D';

    return GestureDetector(
      onTap: isFull ? null : () => context.push('/ride/${ride.id}'),
      child: AnimatedOpacity(
        opacity: isFull ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.bgWhite,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isFull ? AppTheme.border : AppTheme.border,
              width: isFull ? 1 : 1,
            ),
            boxShadow: isFull ? null : AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top strip: driver + price + status ───────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Row(
                  children: [
                    // Driver avatar
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3A1FA5), Color(0xFF270d7d)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: AppTheme.primaryLight, width: 2),
                      ),
                      child: ride.driverPhoto != null && ride.driverPhoto!.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                ride.driverPhoto!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(driverInitial,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16)),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(driverInitial,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                            ),
                    ),
                    const SizedBox(width: 10),

                    // Driver info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ride.driverName,
                            style: AppTextStyles.bodyBold,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (ride.driverRating > 0) ...[
                                Icon(Icons.star_rounded,
                                    size: 12,
                                    color: const Color(0xFFF59E0B)),
                                const SizedBox(width: 2),
                                Text(
                                  ride.driverRating.toStringAsFixed(1),
                                  style: AppTextStyles.caption.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textDark),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (ride.carName.isNotEmpty)
                                Expanded(
                                  child: Text(
                                    ride.carName,
                                    style: AppTextStyles.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Price + status
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (ride.pricePerSeat > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              'Rs ${ride.pricePerSeat.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                            child: const Text(
                              'Free',
                              style: TextStyle(
                                  color: AppTheme.success,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        const SizedBox(height: 4),
                        if (showStatus)
                          StatusBadge(status: ride.status, small: true)
                        else if (isFull)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              'Full',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.error.withValues(alpha: 0.8)),
                            ),
                          )
                        else
                          _SeatsBadge(seats: ride.availableSeats),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Divider ──────────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Divider(height: 1, color: AppTheme.border),
              ),

              // ── Route ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Timeline dots
                      Column(
                        children: [
                          Container(
                            width: 9, height: 9,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppTheme.primaryLight, width: 2),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppTheme.primary, AppTheme.success],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                          Container(
                            width: 9, height: 9,
                            decoration: BoxDecoration(
                              color: AppTheme.success,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),

                      // Route text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              from,
                              style: AppTextStyles.bodyBold,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              to,
                              style: AppTextStyles.body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Time
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            timeStr,
                            style: AppTextStyles.bodyBold.copyWith(
                                color: AppTheme.primary, fontSize: 13),
                          ),
                          Text(dateStr, style: AppTextStyles.caption),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Bottom tags row ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Row(
                  children: [
                    if (hasAC) ...[
                      _Tag(
                        icon: Icons.ac_unit_rounded,
                        label: 'AC',
                        color: AppTheme.secondary,
                        bg: const Color(0xFFE0F2FE),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (ride.carPlate.isNotEmpty) ...[
                      _Tag(
                        icon: Icons.credit_card_rounded,
                        label: ride.carPlate,
                        color: AppTheme.textMedium,
                        bg: const Color(0xFFF1F5F9),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (ride.stops.isNotEmpty) ...[
                      _Tag(
                        icon: Icons.alt_route_rounded,
                        label: '${ride.stops.length} stop${ride.stops.length > 1 ? 's' : ''}',
                        color: AppTheme.warning,
                        bg: const Color(0xFFFFF7ED),
                      ),
                    ],
                    const Spacer(),
                    if (!isFull)
                      Row(
                        children: [
                          Text('View',
                              style: AppTextStyles.caption.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 2),
                          const Icon(Icons.chevron_right_rounded,
                              size: 16, color: AppTheme.primary),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeatsBadge extends StatelessWidget {
  final int seats;
  const _SeatsBadge({required this.seats});

  @override
  Widget build(BuildContext context) {
    final color = seats <= 1 ? AppTheme.warning : AppTheme.success;
    final bg = seats <= 1 ? const Color(0xFFFFF7ED) : const Color(0xFFDCFCE7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_seat_rounded, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            '$seats seat${seats != 1 ? 's' : ''}',
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  const _Tag(
      {required this.icon,
      required this.label,
      required this.color,
      required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
