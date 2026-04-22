import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'About',
          style: TextStyle(color: AppColors.primaryText),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: const AlwaysStoppedAnimation(1.0),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // App Logo (rectangular, no circle)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withAlpha(40),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/LinkSentryLogoTop.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // App Name
              const Text(
                'LinkSentry',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),

              // Version
              Text(
                'Version 1.0.0',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 24),

              // Description Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'About the App',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'LinkSentry is an advanced URL scanning and threat detection application. '
                      'It uses a hybrid 5‑layer engine combining static rules, heuristics, '
                      'machine learning (logistic regression + decision tree), and optional '
                      'behavioral analysis to identify phishing, malware, defacement, and '
                      'ad‑tracking URLs.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.secondaryText,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Team Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Team',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Team members – placeholders (replace with real names/roles)
                    _buildTeamMember(
                      name: 'Member 1',
                      role: 'Role / Responsibility',
                      icon: Icons.person,
                    ),
                    _buildTeamMember(
                      name: 'Member 2',
                      role: 'Role / Responsibility',
                      icon: Icons.person,
                    ),
                    _buildTeamMember(
                      name: 'Member 3',
                      role: 'Role / Responsibility',
                      icon: Icons.person,
                    ),
                    _buildTeamMember(
                      name: 'Member 4',
                      role: 'Role / Responsibility',
                      icon: Icons.person,
                    ),
                    _buildTeamMember(
                      name: 'Member 5',
                      role: 'Role / Responsibility',
                      icon: Icons.person,
                    ),
                    _buildTeamMember(
                      name: 'Member 6',
                      role: 'Role / Responsibility',
                      icon: Icons.person,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Licenses Button (now a consistent ElevatedButton)
              ElevatedButton.icon(
                onPressed: () => _showLicensesDialog(context),
                icon: const Icon(Icons.description, color: Colors.white),
                label: const Text('Open Source Licenses'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 20),

              // Copyright
              Text(
                '© 2026 LinkSentry Team. All rights reserved.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.disabledText,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamMember({
    required String name,
    required String role,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.primaryPurple,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                role,
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLicensesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text(
            'Open Source Licenses',
            style: TextStyle(color: AppColors.primaryText),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                _buildLicenseTile('Flutter', 'BSD 3-Clause License'),
                _buildLicenseTile('tldts', 'MIT License'),
                _buildLicenseTile('Firebase SDK', 'Apache 2.0'),
                _buildLicenseTile('Material Icons', 'Apache 2.0'),
                _buildLicenseTile('Google ML Kit', 'Google Terms'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'OK',
                style: TextStyle(color: AppColors.primaryPurple),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLicenseTile(String library, String license) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            library,
            style: const TextStyle(color: AppColors.primaryText),
          ),
          Text(
            license,
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}