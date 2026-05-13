import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/ride_model.dart';
import '../../data/services/ride_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _rideService = RideService();

  List<Map<String, dynamic>> _users = [];
  List<RideModel> _rides = [];
  bool _loadingUsers = true;
  bool _loadingRides = true;
  int _totalUsers = 0, _totalRides = 0, _activeRides = 0, _bookingsToday = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadUsers(), _loadRides(), _loadBookingsToday()]);
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final users = await _rideService.getAllUsers();
      if (mounted) setState(() { _users = users; _totalUsers = users.length; _loadingUsers = false; });
    } catch (_) { if (mounted) setState(() => _loadingUsers = false); }
  }

  Future<void> _loadRides() async {
    setState(() => _loadingRides = true);
    try {
      final rides = await _rideService.getAllRides();
      if (mounted) {
        setState(() {
        _rides = rides;
        _totalRides = rides.length;
        _activeRides = rides.where((r) => r.status == 'active').length;
        _loadingRides = false;
      });
      }
    } catch (_) { if (mounted) setState(() => _loadingRides = false); }
  }

  Future<void> _loadBookingsToday() async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).toIso8601String();
      final snap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .get();
      if (mounted) setState(() => _bookingsToday = snap.docs.length);
    } catch (_) {}
  }

  Future<void> _toggleUser(String uid, bool val) async {
    try {
      await _rideService.toggleUserStatus(uid, val);
      await _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _cancelRide(String rideId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Ride?'),
        content: const Text('Cancel this ride as admin? All passengers will be notified.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _rideService.cancelRide(rideId);
      await _loadRides();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => context.pop()),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadAll)],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textMedium,
          tabs: const [Tab(text: 'Overview'), Tab(text: 'Users'), Tab(text: 'Rides')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _OverviewTab(
            stats: {
              'Total Users': _totalUsers.toString(),
              'Total Rides': _totalRides.toString(),
              'Active Rides': _activeRides.toString(),
              'Bookings Today': _bookingsToday.toString(),
            },
            isLoading: _loadingUsers || _loadingRides,
          ),
          _UsersTab(users: _users, isLoading: _loadingUsers, onToggle: _toggleUser),
          _RidesTab(rides: _rides, isLoading: _loadingRides, onCancel: _cancelRide),
        ],
      ),
    );
  }
}

// ─── Overview ──────────────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final Map<String, String> stats;
  final bool isLoading;
  const _OverviewTab({required this.stats, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final icons  = [Icons.people_outline, Icons.directions_car_outlined, Icons.play_circle_outline, Icons.bookmark_border];
    final colors = [AppTheme.primary, AppTheme.success, AppTheme.warning, AppTheme.secondary];
    final entries = stats.entries.toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text('Live Statistics',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
        ),
        if (isLoading)
          const Center(child: CircularProgressIndicator(color: AppTheme.primary))
        else
          GridView.builder(
            itemCount: entries.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.6),
            itemBuilder: (_, i) => _StatCard(
                label: entries[i].key, value: entries[i].value,
                icon: icons[i], color: colors[i]),
          ),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.bgWhite, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppTheme.border)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMedium))),
            Container(padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 16)),
          ]),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }
}

// ─── Users ─────────────────────────────────────────────────────────────────────
class _UsersTab extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final bool isLoading;
  final void Function(String uid, bool val) onToggle;
  const _UsersTab({required this.users, required this.isLoading, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (users.isEmpty) return const Center(child: Text('No users found'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (_, i) {
        final u = users[i];
        final name  = u['name']  as String? ?? 'Unknown';
        final email = u['email'] as String? ?? '';
        final dept  = u['department'] as String? ?? '';
        final role  = u['role']  as String? ?? '';
        final uid   = u['uid']   as String? ?? '';
        final isActive = u['isActive'] as bool? ?? true;
        return Card(
          color: AppTheme.bgWhite, elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.border)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(radius: 20, backgroundColor: AppTheme.primaryLight,
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textDark)),
                Text(email, style: const TextStyle(fontSize: 11, color: AppTheme.textMedium)),
                Text('$dept · $role', style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
              ])),
              Switch(value: isActive, onChanged: uid.isNotEmpty ? (v) => onToggle(uid, v) : null, activeColor: AppTheme.primary),
            ]),
          ),
        );
      },
    );
  }
}

// ─── Rides ─────────────────────────────────────────────────────────────────────
class _RidesTab extends StatelessWidget {
  final List<RideModel> rides;
  final bool isLoading;
  final void Function(String) onCancel;
  const _RidesTab({required this.rides, required this.isLoading, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (rides.isEmpty) return const Center(child: Text('No rides found'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rides.length,
      itemBuilder: (_, i) {
        final r = rides[i];
        final booked = r.totalSeats - r.availableSeats;
        Color sc; switch (r.status) {
          case 'active':    sc = AppTheme.success; break;
          case 'completed': sc = AppTheme.textLight; break;
          case 'cancelled': sc = AppTheme.error; break;
          default:          sc = AppTheme.warning;
        }
        return Card(
          color: AppTheme.bgWhite, elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.border)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.directions_car, color: AppTheme.primary, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.driverName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textDark)),
                Text(DateFormat('dd/MM/yyyy HH:mm').format(r.departureTime),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMedium)),
                Text('${r.totalSeats} seats · $booked booked',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
              ])),
              Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(r.status[0].toUpperCase() + r.status.substring(1),
                      style: TextStyle(color: sc, fontSize: 11, fontWeight: FontWeight.w600))),
                if (r.status == 'upcoming') ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => onCancel(r.id),
                    child: const Text('Cancel',
                        style: TextStyle(fontSize: 11, color: AppTheme.error, decoration: TextDecoration.underline))),
                ],
              ]),
            ]),
          ),
        );
      },
    );
  }
}