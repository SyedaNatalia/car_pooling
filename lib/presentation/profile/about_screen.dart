import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('About'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App logo + name
          Center(
            child: Column(children: [
              const SizedBox(height: 12),
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.directions_car,
                    color: Colors.white, size: 48),
              ),
              const SizedBox(height: 16),
              const Text('CarpoolApp',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700,
                      color: AppTheme.textDark)),
              const SizedBox(height: 4),
              const Text('Version 1.0.0',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMedium)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Made with ❤ in Pakistan',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.primary,
                        fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 24),
            ]),
          ),

          // Description
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Text(
              'CarpoolApp connects colleagues who share the same commute route. '
              'Offer or find rides easily, reduce traffic, save fuel costs, '
              'and help the environment — one shared ride at a time.',
              style: TextStyle(
                  fontSize: 14, color: AppTheme.textMedium, height: 1.65),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 16),

          // Info tiles
          Container(
            decoration: BoxDecoration(
              color: AppTheme.bgWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Column(children: [
              _InfoTile(icon: Icons.code, label: 'Built with', value: 'Flutter + Firebase'),
              Divider(height: 1, indent: 56, color: AppTheme.border),
              _InfoTile(icon: Icons.map_outlined, label: 'Maps', value: 'Google Maps Platform'),
              Divider(height: 1, indent: 56, color: AppTheme.border),
              _InfoTile(icon: Icons.verified_outlined, label: 'Version', value: '1.0.0 (Build 1)'),
            ]),
          ),

          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              color: AppTheme.bgWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(children: [
              _LinkTile(
                icon: Icons.description_outlined,
                label: 'Terms of Service',
                onTap: () {},
              ),
              const Divider(height: 1, indent: 56, color: AppTheme.border),
              _LinkTile(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                onTap: () {},
              ),
              const Divider(height: 1, indent: 56, color: AppTheme.border),
              _LinkTile(
                icon: Icons.gavel_outlined,
                label: 'Open Source Licences',
                onTap: () => showLicensePage(context: context),
              ),
            ]),
          ),

          const SizedBox(height: 24),

          const Center(
            child: Text('© 2025 CarpoolApp. All rights reserved.',
                style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: AppTheme.textMedium, size: 20),
      title: Text(label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textMedium)),
      trailing: Text(value,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500,
              color: AppTheme.textDark)),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _LinkTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: AppTheme.textMedium, size: 20),
      title: Text(label,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500,
              color: AppTheme.textDark)),
      trailing: const Icon(Icons.arrow_forward_ios,
          size: 14, color: AppTheme.textLight),
      onTap: onTap,
    );
  }
}