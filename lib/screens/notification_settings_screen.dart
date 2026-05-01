import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  
  bool _isLoading = true;
  bool _isSaving = false;

  bool allowNotifications = false;
  bool scanResultsAlert = false;
  bool aiRiskLevel = false;
  bool highRiskOnly = false;
  bool weeklyReport = false;
  bool phishingTrendAlerts = false;
  bool sound = false;

  // Firestore reference shorthand
  DocumentReference? _prefsDoc;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

    Future<void> _loadPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
 
    _prefsDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('notification_preferences');
 
    try {
      final doc = await _prefsDoc!.get();
      final data = doc.data() as Map<String, dynamic>?;
 
      if (data != null && mounted) {
        setState(() {
          allowNotifications  = data['allowNotifications']  ?? false;
          scanResultsAlert    = data['scanResultsAlert']    ?? false;
          aiRiskLevel         = data['aiRiskLevel']         ?? false;
          highRiskOnly        = data['highRiskOnly']        ?? false;
          weeklyReport        = data['weeklyReport']        ?? false;
          phishingTrendAlerts = data['phishingTrendAlerts'] ?? false;
          sound               = data['sound']               ?? false;
        });
      }
    } catch (e) {
      // docs dont exists: defaults
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
 
  Future<void> _savePreferences() async {
    if (_prefsDoc == null || _isSaving) return;
 
    setState(() => _isSaving = true);
 
    try {
      await _prefsDoc!.set({
        'allowNotifications':  allowNotifications,
        'scanResultsAlert':    scanResultsAlert,
        'aiRiskLevel':         aiRiskLevel,
        'highRiskOnly':        highRiskOnly,
        'weeklyReport':        weeklyReport,
        'phishingTrendAlerts': phishingTrendAlerts,
        'sound':               sound,
        'updatedAt':           FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save preferences: $e'),
          backgroundColor: AppColors.highRisk,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
 
  // Toggle handler: updates state then persists
  void _onToggle(String field, bool value) {
    setState(() {
      switch (field) {
        case 'allowNotifications':
          allowNotifications = value;
          // if master is turned off, clear all sub-toggles
          if (!value) {
            scanResultsAlert    = false;
            aiRiskLevel         = false;
            highRiskOnly        = false;
            weeklyReport        = false;
            phishingTrendAlerts = false;
            sound               = false;
          }
          break;
        case 'scanResultsAlert':    scanResultsAlert    = value; break;
        case 'aiRiskLevel':         aiRiskLevel         = value; break;
        case 'highRiskOnly':        highRiskOnly        = value; break;
        case 'weeklyReport':        weeklyReport        = value; break;
        case 'phishingTrendAlerts': phishingTrendAlerts = value; break;
        case 'sound':               sound               = value; break;
      }
    });
 
    _savePreferences();
  }

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
        actions: [
          // subtle saving indicator
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryPurple,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Master toggle
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
                        field: 'allowNotifications',
                        showDivider: false,
                        forceEnabled: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 16),

              // sub toggles (greyed out when notifications off)
                    AnimatedOpacity(
                      opacity: allowNotifications ? 1.0 : 0.4,
                      duration: const Duration(milliseconds: 250),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
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
                              subtitle: 'Notify after every scan completes',
                              value: scanResultsAlert,
                              field: 'scanResultsAlert',
                            ),
                            _buildToggleRow(
                              title: 'AI Risk Level',
                              subtitle: 'Alert when ML model flags a risk',
                              value: aiRiskLevel,
                              field: 'aiRiskLevel',
                            ),
                            _buildToggleRow(
                              title: 'High Risk Only',
                              subtitle: 'Only notify for High severity results',
                              value: highRiskOnly,
                              field: 'highRiskOnly',
                            ),
                            _buildToggleRow(
                              title: 'Weekly Report',
                              subtitle: 'Summary of your scan activity',
                              value: weeklyReport,
                              field: 'weeklyReport',
                            ),
                            _buildToggleRow(
                              title: 'Phishing Trend Alerts',
                              subtitle: 'Notify when a new threat type is detected',
                              value: phishingTrendAlerts,
                              field: 'phishingTrendAlerts',
                            ),
                            _buildToggleRow(
                              title: 'Sound',
                              subtitle: 'Play sound with notifications',
                              value: sound,
                              field: 'sound',
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
    required String field,
    String? subtitle,
    bool showDivider = true,
    bool forceEnabled = false,
  }) {
    final bool isEnabled = forceEnabled || allowNotifications;
 
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: isEnabled ? (v) => _onToggle(field, v) : null,
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