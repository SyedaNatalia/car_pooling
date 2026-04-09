// lib/presentation/admin/admin_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

// Mock data for admin
final _mockStats = {
  'Total Users': '48',
  'Total Rides': '127',
  'Active Rides': '3',
  'Bookings Today': '19',
};

final _mockUsers = [
  {'name': 'Sara Ahmed', 'email': 'sara@company.com', 'department': 'Engineering', 'role': 'both', 'isActive': true},
  {'name': 'Ali Hassan', 'email': 'ali@company.com', 'department': 'Marketing', 'role': 'driver', 'isActive': true},
  {'name': 'Ayesha Khan', 'email': 'ayesha@company.com', 'department': 'HR', 'role': 'passenger', 'isActive': true},
  {'name': 'Usman Tariq', 'email': 'usman@company.com', 'department': 'Finance', 'role': 'driver', 'isActive': false},
  {'name': 'Fatima Malik', 'email': 'fatima@company.com', 'department': 'Design', 'role': 'passenger', 'isActive': true},
  {'name': 'Bilal Ahmed', 'email': 'bilal@company.com', 'department': 'Operations', 'role': 'both', 'isActive': true},
];

final _mockRides = [
  {'driverName': 'Ali Hassan', 'date': '08/04/2026 09:00', 'totalSeats': 4, 'booked': 3, 'status': 'active'},
  {'driverName': 'Sara Ahmed', 'date': '08/04/2026 08:30', 'totalSeats': 4, 'booked': 1, 'status': 'upcoming'},
  {'driverName': 'Usman Tariq', 'date': '07/04/2026 09:00', 'totalSeats': 3, 'booked': 3, 'status': 'completed'},
  {'driverName': 'Ayesha Khan', 'date': '07/04/2026 08:00', 'totalSeats': 3, 'booked': 2, 'status': 'completed'},
  {'driverName': 'Bilal Ahmed', 'date': '06/04/2026 09:30', 'totalSeats': 4, 'booked': 0, 'status': 'cancelled'},
];

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final List<Map<String, dynamic>> _users =
      _mockUsers.map((u) => Map<String, dynamic>.from(u)).toList();
  final List<Map<String, dynamic>> _rides =
      _mockRides.map((r) => Map<String, dynamic>.from(r)).toList();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textMedium,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Users'),
            Tab(text: 'Rides'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _OverviewTab(stats: _mockStats),
          _UsersTab(users: _users, onToggle: (i, val) {
            setState(() => _users[i]['isActive'] = val);
          }),
          _RidesTab(rides: _rides, onCancel: (i) {
            setState(() => _rides[i]['status'] = 'cancelled');
          }),
        ],
      ),
    );
  }
}

// ─── Overview Tab ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final Map<String, String> stats;
  const _OverviewTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final icons = [
      Icons.people_outline,
      Icons.directions_car_outlined,
      Icons.play_circle_outline,
      Icons.bookmark_border,
    ];
    final colors = [
      AppTheme.primary,
      AppTheme.success,
      AppTheme.warning,
      AppTheme.secondary,
    ];
    final entries = stats.entries.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text('Statistics',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              )),
          ),
          GridView.builder(
            itemCount: entries.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
            ),
            itemBuilder: (context, i) => _StatCard(
              label: entries[i].key,
              value: entries[i].value,
              icon: icons[i],
              color: colors[i],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMedium)),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          Text(value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
            )),
        ],
      ),
    );
  }
}

// ─── Users Tab ────────────────────────────────────────────────────────────────

class _UsersTab extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final void Function(int index, bool val) onToggle;

  const _UsersTab({required this.users, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, i) {
        final u = users[i];
        final isActive = u['isActive'] as bool;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.bgWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primaryLight,
                child: Text(
                  (u['name'] as String).substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u['name'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textDark,
                      )),
                    Text(u['email'] as String,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMedium)),
                    Text('${u['department']} · ${u['role']}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
                  ],
                ),
              ),
              Switch(
                value: isActive,
                onChanged: (val) => onToggle(i, val),
                activeColor: AppTheme.primary,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Rides Tab ────────────────────────────────────────────────────────────────

class _RidesTab extends StatelessWidget {
  final List<Map<String, dynamic>> rides;
  final void Function(int index) onCancel;

  const _RidesTab({required this.rides, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rides.length,
      itemBuilder: (context, i) {
        final r = rides[i];
        final status = r['status'] as String;

        Color statusColor;
        switch (status) {
          case 'active': statusColor = AppTheme.success; break;
          case 'completed': statusColor = AppTheme.textLight; break;
          case 'cancelled': statusColor = AppTheme.error; break;
          default: statusColor = AppTheme.warning;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.bgWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.directions_car, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['driverName'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textDark)),
                    Text(r['date'] as String,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMedium)),
                    Text('${r['totalSeats']} seats · ${r['booked']} booked',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
                  ],
                ),
              ),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status[0].toUpperCase() + status.substring(1),
                      style: TextStyle(
                        color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  if (status == 'upcoming') ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => onCancel(i),
                      child: const Text('Cancel',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.error,
                          decoration: TextDecoration.underline,
                        )),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}