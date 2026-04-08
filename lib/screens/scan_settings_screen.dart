import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../threat_engine/scan_settings.dart'; // your engine's ScanSettings class

class ScanSettingsScreen extends StatefulWidget {
  const ScanSettingsScreen({super.key});

  @override
  State<ScanSettingsScreen> createState() => _ScanSettingsScreenState();
}

class _ScanSettingsScreenState extends State<ScanSettingsScreen> {
  // Auth state
  bool _isLoggedIn = false;

  // Plan & Mode (only relevant when logged in)
  String _userLevel = 'beginner'; // 'beginner' or 'advanced'
  bool _isPremium = false;        // true for logged-in users, false for guests

  // Threat detection toggles
  bool _phishingSensitivity = true;
  bool _deepScan = true;           // replaces httpSitesWarning
  bool _scriptAnalysis = true;
  bool _useExternalApis = true;

  // ML model selection (only shown when _userLevel == 'advanced')
  bool _useEnsemble = false;
  bool _useLogisticRegression = true;
  bool _useDecisionTree = true;
  bool _useXGBoost = true;
  bool _useLightGBM = true;        // if model available

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
  }

  Future<void> _checkAuthAndLoad() async {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _isLoggedIn = user != null;
      _isPremium = _isLoggedIn; // logged-in users are premium for now
    });
    if (_isLoggedIn) {
      await _loadSettings();
    } else {
      // Guest mode: use free defaults
      _userLevel = 'free';
      _phishingSensitivity = true;
      _deepScan = false;
      _scriptAnalysis = false;
      _useExternalApis = false;
      _useEnsemble = false;
      _useLogisticRegression = false;
      _useDecisionTree = false;
      _useXGBoost = false;
      _useLightGBM = false;
    }
  }

  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
          _userLevel = data['userLevel'] ?? 'beginner';
          _phishingSensitivity = data['phishingSensitivity'] ?? true;
          _deepScan = data['deepScan'] ?? true;
          _scriptAnalysis = data['scriptAnalysis'] ?? true;
          _useExternalApis = data['useExternalApis'] ?? true;
          _useEnsemble = data['useEnsemble'] ?? (_userLevel == 'beginner');
          _useLogisticRegression = data['useLogisticRegression'] ?? true;
          _useDecisionTree = data['useDecisionTree'] ?? true;
          _useXGBoost = data['useXGBoost'] ?? true;
          _useLightGBM = data['useLightGBM'] ?? true;
        });
      } else {
        // Default for logged-in: beginner mode with ensemble
        _userLevel = 'beginner';
        _useEnsemble = true;
      }
    } catch (e) {
      // ignore
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
        'userLevel': _userLevel,
        'phishingSensitivity': _phishingSensitivity,
        'deepScan': _deepScan,
        'scriptAnalysis': _scriptAnalysis,
        'useExternalApis': _useExternalApis,
        'useEnsemble': _useEnsemble,
        'useLogisticRegression': _useLogisticRegression,
        'useDecisionTree': _useDecisionTree,
        'useXGBoost': _useXGBoost,
        'useLightGBM': _useLightGBM,
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
                Navigator.pushNamed(context, '/login');
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

  /// Build a ScanSettings object from current UI state (to be used by the scanner)
  ScanSettings buildScanSettings() {
    return ScanSettings(
      phishingSensitivity: _phishingSensitivity,
      httpSitesWarning: false, // not used
      scriptAnalysis: _scriptAnalysis,
      adReductionAnalysis: false,
      adDensityLevel: 1,
      autoRecheckScans: false,
      sharingConfiguration: false,
      useExternalApis: _useExternalApis,
      isPremium: _isPremium,
      userLevel: _userLevel,
      enableMachineLearning: true,
      useEnsemble: _useEnsemble,
      useLogisticRegression: _useLogisticRegression,
      useDecisionTree: _useDecisionTree,
      useXGBoost: _useXGBoost,
      useLightGBM: _useLightGBM,
      deepScan: _deepScan,
      adFilter: false,
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
                  // PLAN & MODE section
                  _buildSectionHeader(
                    icon: Icons.tune,
                    title: 'PLAN & MODE',
                  ),
                  const SizedBox(height: 8),
                  _buildPlanAndModeCard(),
                  const SizedBox(height: 24),

                  // THREAT DETECTION
                  _buildSectionHeader(
                    icon: Icons.shield,
                    title: 'THREAT DETECTION',
                  ),
                  const SizedBox(height: 8),
                  _buildSwitchTile(
                    title: 'Phishing Sensitivity',
                    subtitle: 'Analyze URLs for phishing keywords and patterns',
                    value: _phishingSensitivity,
                    onChanged: _isLoggedIn ? (val) => setState(() => _phishingSensitivity = val) : null,
                  ),
                  _buildSwitchTile(
                    title: 'Deep Scan',
                    subtitle: 'Follow redirects and analyze page behavior',
                    value: _deepScan,
                    onChanged: _isLoggedIn ? (val) => setState(() => _deepScan = val) : null,
                  ),
                  _buildSwitchTile(
                    title: 'Script Analysis',
                    subtitle: 'Detect obfuscated or suspicious JavaScript',
                    value: _scriptAnalysis,
                    onChanged: _isLoggedIn ? (val) => setState(() => _scriptAnalysis = val) : null,
                  ),
                  _buildSwitchTile(
                    title: 'Use External APIs',
                    subtitle: 'Query VirusTotal, OpenPhish, IPQS, etc.',
                    value: _useExternalApis,
                    onChanged: _isLoggedIn ? (val) => setState(() => _useExternalApis = val) : null,
                  ),
                  const SizedBox(height: 24),

                  // MACHINE LEARNING MODELS (only for advanced users)
                  if (_isLoggedIn && _userLevel == 'advanced') ...[
                    _buildSectionHeader(
                      icon: Icons.memory,
                      title: 'MACHINE LEARNING MODELS',
                    ),
                    const SizedBox(height: 8),
                    _buildSwitchTile(
                      title: 'Use Ensemble',
                      subtitle: 'Combine all selected models',
                      value: _useEnsemble,
                      onChanged: (val) => setState(() => _useEnsemble = val),
                    ),
                    if (!_useEnsemble) ...[
                      _buildSwitchTile(
                        title: 'Logistic Regression',
                        subtitle: 'Linear model for threat classification',
                        value: _useLogisticRegression,
                        onChanged: (val) => setState(() => _useLogisticRegression = val),
                      ),
                      _buildSwitchTile(
                        title: 'Decision Tree',
                        subtitle: 'Rule‑based tree classifier',
                        value: _useDecisionTree,
                        onChanged: (val) => setState(() => _useDecisionTree = val),
                      ),
                      _buildSwitchTile(
                        title: 'XGBoost',
                        subtitle: 'Gradient boosted trees',
                        value: _useXGBoost,
                        onChanged: (val) => setState(() => _useXGBoost = val),
                      ),
                      _buildSwitchTile(
                        title: 'LightGBM',
                        subtitle: 'Light gradient boosting (if available)',
                        value: _useLightGBM,
                        onChanged: (val) => setState(() => _useLightGBM = val),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],

                  // Save button (only for logged-in users)
                  if (_isLoggedIn)
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

  Widget _buildPlanAndModeCard() {
    return Container(
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
            children: [
              const Icon(Icons.workspace_premium, color: AppColors.primaryPurple, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Plan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.primaryText),
                ),
              ),
              Text(
                _isLoggedIn ? 'Premium' : 'Free',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryPurple),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              _isLoggedIn
                  ? 'You have access to all features'
                  : 'Sign in to unlock premium scanning (ML models, deep scan, external APIs)',
              style: const TextStyle(fontSize: 12, color: AppColors.disabledText),
            ),
          ),
          if (_isLoggedIn) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: AppColors.primaryPurple, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Scan Mode',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.primaryText),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.only(left: 28),
              child: Text(
                'Beginner: ensemble of all models, simplified output. Advanced: choose individual models, detailed technical data.',
                style: TextStyle(fontSize: 12, color: AppColors.disabledText),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Beginner', style: TextStyle(color: AppColors.primaryText)),
                    value: 'beginner',
                    groupValue: _userLevel,
                    activeColor: AppColors.primaryPurple,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _userLevel = value;
                          if (_userLevel == 'beginner') {
                            _useEnsemble = true;
                          } else {
                            _useEnsemble = false;
                          }
                        });
                      }
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Advanced', style: TextStyle(color: AppColors.primaryText)),
                    value: 'advanced',
                    groupValue: _userLevel,
                    activeColor: AppColors.primaryPurple,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _userLevel = value;
                          if (_userLevel == 'advanced') {
                            _useEnsemble = false;
                          }
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
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
    required ValueChanged<bool>? onChanged,
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
          style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.primaryText),
        ),
        subtitle: Text(subtitle, style: TextStyle(color: AppColors.secondaryText)),
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
}