import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool allowNotifications = false;
  bool scanResultsAlert = false;
  bool aiRiskLevel = false;
  bool highRiskOnly = false;
  bool weeklyReport = false;
  bool phishingTrendAlerts = false;
  bool sound = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notification Settings',
          style: TextStyle(
            color: AppColors.primaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // master toggle
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryPurple.withAlpha(60),
                    width: 1,
                  ),
                ),
                child: _buildToggleRow(
                  title: 'Allow Notifications',
                  value: allowNotifications,
                  onChanged: (value) =>
                      setState(() => allowNotifications = value),
                  showDivider: false,
                  forceEnabled: true,
                ),
              ),
              const SizedBox(height: 24), // 22 → 24
              const Text(
                'Filters',
                style: TextStyle(
                  fontSize: 20,      // 19 → 20
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 16), // 12 → 16

              // sub toggles (greyed out when notifications off)
              AnimatedOpacity(
                opacity: allowNotifications ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 250),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12), // 8 → 12
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryPurple.withAlpha(60),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildToggleRow(
                        title: 'Scan Results Alert',
                        value: scanResultsAlert,
                        onChanged: (v) =>
                            setState(() => scanResultsAlert = v),
                      ),
                      _buildToggleRow(
                        title: 'AI Risk Level',
                        value: aiRiskLevel,
                        onChanged: (v) =>
                            setState(() => aiRiskLevel = v),
                      ),
                      _buildToggleRow(
                        title: 'High Risk Only',
                        value: highRiskOnly,
                        onChanged: (v) =>
                            setState(() => highRiskOnly = v),
                      ),
                      _buildToggleRow(
                        title: 'Weekly Report',
                        value: weeklyReport,
                        onChanged: (v) =>
                            setState(() => weeklyReport = v),
                      ),
                      _buildToggleRow(
                        title: 'Phishing Trend Alerts',
                        value: phishingTrendAlerts,
                        onChanged: (v) =>
                            setState(() => phishingTrendAlerts = v),
                      ),
                      _buildToggleRow(
                        title: 'Sound',
                        value: sound,
                        onChanged: (v) => setState(() => sound = v),
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool showDivider = true,
    bool forceEnabled = false,
  }) {
    final bool isEnabled = forceEnabled || allowNotifications;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 14,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: isEnabled ? onChanged : null,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primaryPurple,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: AppColors.disabledText,
            ),
          ],
        ),
        if (showDivider)
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.divider,
          ),
      ],
    );
  }
}