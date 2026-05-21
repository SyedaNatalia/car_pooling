import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

enum RideStatus { upcoming, active, completed, cancelled, expired }

enum BookingStatus { pending, accepted, rejected, completed, cancelled, expired }

class StatusBadge extends StatelessWidget {
  final String status;
  final bool small;

  const StatusBadge({super.key, required this.status, this.small = false});

  static _Config _config(String s) {
    switch (s.toLowerCase()) {
      case 'upcoming':
        return const _Config(AppTheme.primary, AppTheme.primaryLight, Icons.schedule_rounded, 'Upcoming');
      case 'active':
        return const _Config(AppTheme.success, Color(0xFFDCFCE7), Icons.directions_car_rounded, 'Active');
      case 'completed':
        return const _Config(AppTheme.textMedium, Color(0xFFF1F5F9), Icons.check_circle_outline, 'Done');
      case 'cancelled':
        return const _Config(AppTheme.error, Color(0xFFFEF2F2), Icons.cancel_outlined, 'Cancelled');
      case 'expired':
        return const _Config(AppTheme.warning, Color(0xFFFFF7ED), Icons.timer_off_outlined, 'Expired');
      case 'pending':
        return const _Config(AppTheme.warning, Color(0xFFFFF7ED), Icons.hourglass_empty_rounded, 'Pending');
      case 'accepted':
        return const _Config(AppTheme.success, Color(0xFFDCFCE7), Icons.check_circle_outline, 'Accepted');
      case 'rejected':
        return const _Config(AppTheme.error, Color(0xFFFEF2F2), Icons.cancel_outlined, 'Rejected');
      default:
        return _Config(AppTheme.textLight, AppTheme.border, Icons.info_outline, s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _config(status);
    final iconSize = small ? 10.0 : 12.0;
    final fontSize = small ? 10.0 : 11.0;
    final hPad = small ? 6.0 : 9.0;
    final vPad = small ? 3.0 : 4.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: c.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(c.icon, size: iconSize, color: c.color),
          SizedBox(width: small ? 3 : 4),
          Text(
            c.label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: c.color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Config {
  final Color color;
  final Color bg;
  final IconData icon;
  final String label;
  const _Config(this.color, this.bg, this.icon, this.label);
}
