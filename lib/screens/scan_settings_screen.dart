import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ScanSettingsScreen extends StatefulWidget {
  const ScanSettingsScreen({super.key});

  @override
  State<ScanSettingsScreen> createState() => _ScanSettingsScreenState();
}

class _ScanSettingsScreenState extends State<ScanSettingsScreen> {
  // Threat Detection toggles
  bool _phishingSensitivity = true;
  bool _httpSitesWarning = true;
  bool _scriptAnalysis = true;

  // Ad & Tracker Analysis
  bool _adReductionAnalysis = true;
  int _adDensityLevel = 1; // 0: Low, 1: Medium, 2: High

  // Smart Monitoring
  bool _autoRecheckScans = true;
  bool _sharingConfiguration = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Scan Preferences',
          style: TextStyle(color: AppColors.primaryText),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.shield,
              title: 'THREAT DETECTION',
            ),
            const SizedBox(height: 8),
            _buildSwitchTile(
              title: 'Phishing Sensitivity',
              subtitle: 'Analyze URLs for phishing patterns',
              value: _phishingSensitivity,
              onChanged: (val) => setState(() => _phishingSensitivity = val),
            ),
            _buildSwitchTile(
              title: 'HTTP Sites Warning',
              subtitle: 'Detect suspicious scripts on HTTP sites',
              value: _httpSitesWarning,
              onChanged: (val) => setState(() => _httpSitesWarning = val),
            ),
            _buildSwitchTile(
              title: 'Script Analysis',
              subtitle: 'Detect suspicious scripts',
              value: _scriptAnalysis,
              onChanged: (val) => setState(() => _scriptAnalysis = val),
            ),
            const SizedBox(height: 24),

            _buildSectionHeader(
              icon: Icons.track_changes,
              title: 'AD & TRACKER ANALYSIS',
            ),
            const SizedBox(height: 8),
            _buildSwitchTile(
              title: 'Ad-Reduction Analysis',
              subtitle: 'Identify tracking parameters',
              value: _adReductionAnalysis,
              onChanged: (val) => setState(() => _adReductionAnalysis = val),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ad density alert level',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildRadioButton('Low', 0),
                      const SizedBox(width: 16),
                      _buildRadioButton('Medium', 1),
                      const SizedBox(width: 16),
                      _buildRadioButton('High', 2),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'High = stricter ad density alerts',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.disabledText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionHeader(
              icon: Icons.smart_toy,
              title: 'SMART MONITORING',
            ),
            const SizedBox(height: 8),
            _buildSwitchTile(
              title: 'Auto-Recheck Scans',
              subtitle: 'Daily safety checks on past scans',
              value: _autoRecheckScans,
              onChanged: (val) => setState(() => _autoRecheckScans = val),
            ),
            _buildSwitchTile(
              title: 'Sharing Configuration',
              subtitle: 'Scan from any apps (Browser, Messages)',
              value: _sharingConfiguration,
              onChanged: (val) => setState(() => _sharingConfiguration = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryPurple, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.secondaryText,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.primaryText,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: AppColors.secondaryText),
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primaryPurple,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        secondary: Icon(
          value ? Icons.check_circle : Icons.radio_button_unchecked,
          color: value ? AppColors.safe : AppColors.disabledText,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildRadioButton(String label, int value) {
    return Row(
      children: [
        Radio<int>(
          value: value,
          groupValue: _adDensityLevel,
          onChanged: (val) {
            if (val != null) {
              setState(() => _adDensityLevel = val);
            }
          },
          activeColor: AppColors.primaryBlue,
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.primaryText),
        ),
      ],
    );
  }
}