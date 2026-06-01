import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  // ── FAQs ──────────────────────────────────────────────────────────
  final _faqs = const [
    _FAQ(
      q: 'How do I book a ride?',
      a: 'Go to "Find a Ride", enter your pickup and destination, select a ride type and tap "Search Rides". Choose a ride from results and confirm your booking.',
    ),
    _FAQ(
      q: 'How do I offer a ride?',
      a: 'Tap "Offer a Ride" from the home screen. Set your route, departure time, and available seats. Once published, passengers can send you booking requests.',
    ),
    _FAQ(
      q: 'How do I accept or reject a booking?',
      a: 'Go to your ride from "My Rides" and open "Manage Requests". You can accept or reject each pending request there.',
    ),
    _FAQ(
      q: 'Can I cancel a ride?',
      a: 'Yes. Open the ride from "My Rides" or "My Bookings" and tap the Cancel option. Cancellations should be made at least 1 hour before departure.',
    ),
    _FAQ(
      q: 'How is the fare calculated?',
      a: 'Fare = Base fare (Rs.40) + Rate per km × Distance. Each ride type (Economy, Comfort, Premium) has a different rate per km.',
    ),
    _FAQ(
      q: 'What if my driver does not show up?',
      a: 'Contact the driver via the ride details page. If unreachable, report the issue using the "Contact Support" button below.',
    ),
  ];

  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Help & Support'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
            ),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.support_agent,
                    color: AppTheme.primary, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('We are here to help',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600,
                            color: AppTheme.primary)),
                    SizedBox(height: 3),
                    Text('Browse FAQs or contact us directly',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textMedium)),
                  ],
                ),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          // FAQ section
          const Text('Frequently Asked Questions',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppTheme.textMedium, letterSpacing: 0.4)),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: AppTheme.bgWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: _faqs.asMap().entries.map((e) {
                final i      = e.key;
                final faq    = e.value;
                final isOpen = _expandedIndex == i;
                final isLast = i == _faqs.length - 1;
                return Column(children: [
                  InkWell(
                    onTap: () =>
                        setState(() => _expandedIndex = isOpen ? null : i),
                    borderRadius: BorderRadius.vertical(
                      top:    Radius.circular(i == 0 ? 14 : 0),
                      bottom: Radius.circular(isLast && !isOpen ? 14 : 0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(children: [
                        Expanded(
                          child: Text(faq.q,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isOpen
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isOpen
                                      ? AppTheme.primary
                                      : AppTheme.textDark)),
                        ),
                        Icon(
                          isOpen
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: isOpen
                              ? AppTheme.primary
                              : AppTheme.textLight,
                          size: 20,
                        ),
                      ]),
                    ),
                  ),
                  if (isOpen)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Text(faq.a,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textMedium,
                              height: 1.6)),
                    ),
                  if (!isLast)
                    const Divider(height: 1, color: AppTheme.border),
                ]);
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),

          // Contact options
          const Text('Contact Us',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppTheme.textMedium, letterSpacing: 0.4)),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: AppTheme.bgWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(children: [
              _ContactTile(
                icon: Icons.email_outlined,
                label: 'Email Support',
                subtitle: 'support@yourapp.com',
                iconColor: AppTheme.primary,
                onTap: () {},
              ),
            ]),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _FAQ {
  final String q;
  final String a;
  const _FAQ({required this.q, required this.a});
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  const _ContactTile({
    required this.icon, required this.label,
    required this.subtitle, required this.onTap, required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(label,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500,
              color: AppTheme.textDark)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMedium)),
      trailing: const Icon(Icons.arrow_forward_ios,
          size: 14, color: AppTheme.textLight),
      onTap: onTap,
    );
  }
}