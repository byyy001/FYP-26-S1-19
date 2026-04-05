import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  bool _isLoading = false;

  // New top settings
  bool _isPremiumUser = false; // placeholder for now
  String _selectedMode = 'Default';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // Not logged in, use default values

    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('scan_preferences')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _phishingSensitivity = data['phishingSensitivity'] ?? true;
          _httpSitesWarning = data['httpSitesWarning'] ?? true;
          _scriptAnalysis = data['scriptAnalysis'] ?? true;
          _adReductionAnalysis = data['adReductionAnalysis'] ?? true;
          _adDensityLevel = data['adDensityLevel'] ?? 1;
          _autoRecheckScans = data['autoRecheckScans'] ?? true;
          _sharingConfiguration = data['sharingConfiguration'] ?? true;
        });
      }
    } catch (e) {
      // Ignore – keep defaults
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLoginPrompt();
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('scan_preferences')
          .set({
        'phishingSensitivity': _phishingSensitivity,
        'httpSitesWarning': _httpSitesWarning,
        'scriptAnalysis': _scriptAnalysis,
        'adReductionAnalysis': _adReductionAnalysis,
        'adDensityLevel': _adDensityLevel,
        'autoRecheckScans': _autoRecheckScans,
        'sharingConfiguration': _sharingConfiguration,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved!'),
          backgroundColor: AppColors.safe,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: AppColors.highRisk,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text(
            'Sign in Required',
            style: TextStyle(color: AppColors.primaryText),
          ),
          content: const Text(
            'You need to be signed in to save your scan preferences. Would you like to sign in now?',
            style: TextStyle(color: AppColors.secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/login'); // adjust route
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
              ),
              child: const Text('Sign In'),
            ),
          ],
        );
      },
    );
  }

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
  icon: Icons.tune,
  title: 'PLAN & MODE',
),
const SizedBox(height: 8),
Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.workspace_premium,
            color: AppColors.primaryPurple,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Plan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryText,
              ),
            ),
          ),
          Text(
            _isPremiumUser ? 'Premium' : 'Free',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryPurple,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      const Padding(
        padding: EdgeInsets.only(left: 28),
        child: Text(
          'Your current feature tier',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.disabledText,
          ),
        ),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          const Icon(
            Icons.analytics_outlined,
            color: AppColors.primaryPurple,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text(
            'Scan Mode',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryText,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      const Padding(
        padding: EdgeInsets.only(left: 28),
        child: Text(
          'Choose how detailed the scan result should be',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.disabledText,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Default',
                style: TextStyle(color: AppColors.primaryText),
              ),
              value: 'Default',
              groupValue: _selectedMode,
              activeColor: AppColors.primaryPurple,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedMode = value);
                }
              },
            ),
          ),
          Expanded(
            child: RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Advanced',
                style: TextStyle(color: AppColors.primaryText),
              ),
              value: 'Advanced',
              groupValue: _selectedMode,
              activeColor: AppColors.primaryPurple,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedMode = value);
                }
              },
            ),
          ),
        ],
      ),
    ],
  ),
),
const SizedBox(height: 24),

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
                 Container(
  width: double.infinity,
  margin: const EdgeInsets.symmetric(vertical: 4),
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Ad density alert level',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryText,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Choose how strict the app should be when detecting ad-heavy pages',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.disabledText,
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          _buildRadioButton('Low', 0),
          const SizedBox(width: 16),
          _buildRadioButton('Medium', 1),
          const SizedBox(width: 16),
          _buildRadioButton('High', 2),
        ],
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

                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Preferences',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
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