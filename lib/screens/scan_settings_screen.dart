import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import '../services/scan_settings_service.dart';
import '../threat_engine/scan_settings.dart';

class ScanSettingsScreen extends StatefulWidget {
  const ScanSettingsScreen({super.key});

  @override
  State<ScanSettingsScreen> createState() => _ScanSettingsScreenState();
}

class _ScanSettingsScreenState extends State<ScanSettingsScreen> {
  final ScanSettingsService _scanSettingsService = ScanSettingsService();

  // Auth state
  bool _isLoggedIn = false;
  bool _isPremium = false;

  // Scan mode
  String _userLevel = 'beginner'; 

  // Threat detection toggles
  bool _phishingSensitivity = true;
  bool _deepScan = true;
  bool _scriptAnalysis = true;
  bool _useExternalApis = true;

  // ML model selection
  bool _useEnsemble = false;
  bool _useLogisticRegression = true;
  bool _useDecisionTree = true;
  bool _useXGBoost = true;
  bool _useLightGBM = true;

  bool _isLoading = false;
  bool get _canCustomize => FirebaseAuth.instance.currentUser != null;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
  }

  Future<void> _checkAuthAndLoad() async {
    final user = FirebaseAuth.instance.currentUser;

    setState(() {
      _isLoggedIn = user != null;
      _isPremium = user != null;
    });

    if (_isLoggedIn) {
      await _loadSettings();
    } else {
      // Guest / free defaults
      setState(() {
        _userLevel = 'beginner';
        _phishingSensitivity = true;
        _deepScan = false;
        _scriptAnalysis = false;
        _useExternalApis = false;
        _useEnsemble = true;
        _useLogisticRegression = true;
        _useDecisionTree = true;
        _useXGBoost = true;
        _useLightGBM = true;
      });
    }
  }

  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final data = await _scanSettingsService.getSettings(userId: user.uid);

      if (data != null) {
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
        await _scanSettingsService.createDefaultSettingsForUser(userId: user.uid);
        final fallbackData = await _scanSettingsService.getSettings(userId: user.uid);

        if (!mounted || fallbackData == null) {
          return;
        }
        
        // Default for registered / paid users
        setState(() {
          _userLevel = 'beginner';
          _phishingSensitivity = true;
          _deepScan = true;
          _scriptAnalysis = true;
          _useExternalApis = true;
          _useEnsemble = true;
          _useLogisticRegression = true;
          _useDecisionTree = true;
          _useXGBoost = true;
          _useLightGBM = true;
        });
      }
    } catch (e) {
      // ignore for now
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
      await _scanSettingsService.updateSettings(
        userId: user.uid,
        settings: {
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
        'isPremium': true,
        },
      );

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
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
            'You need to be signed in to save your scan settings. Would you like to sign in now?',
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

  ScanSettings buildScanSettings() {
    return ScanSettings(
      phishingSensitivity: _phishingSensitivity,
      httpSitesWarning: false,
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
    final bool advancedModelsEnabled = _canCustomize && _userLevel == 'advanced';

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Scan Settings',
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
                  _buildPlanAndModeCard(),
                  const SizedBox(height: 24),

                  _buildSectionHeader(
                    icon: Icons.shield,
                    title: 'THREAT DETECTION',
                  ),
                  const SizedBox(height: 8),

                  _buildSwitchTile(
                    title: 'Phishing Sensitivity',
                    subtitle: 'Analyze URLs for phishing keywords and patterns',
                    value: _phishingSensitivity,
                    enabled: _canCustomize,
                    onChanged: (val) => setState(() => _phishingSensitivity = val),
                  ),
                  _buildSwitchTile(
                    title: 'Deep Scan',
                    subtitle: 'Follow redirects and analyze page behavior',
                    value: _deepScan,
                    enabled: _canCustomize,
                    onChanged: (val) => setState(() => _deepScan = val),
                  ),
                  _buildSwitchTile(
                    title: 'Script Analysis',
                    subtitle: 'Detect obfuscated or suspicious JavaScript',
                    value: _scriptAnalysis,
                    enabled: _canCustomize,
                    onChanged: (val) => setState(() => _scriptAnalysis = val),
                  ),
                  _buildSwitchTile(
                    title: 'Use External APIs',
                    subtitle: 'Query VirusTotal, OpenPhish, IPQS, etc.',
                    value: _useExternalApis,
                    enabled: _canCustomize,
                    onChanged: (val) => setState(() => _useExternalApis = val),
                  ),

                  const SizedBox(height: 24),

                  _buildSectionHeader(
                    icon: Icons.memory,
                    title: 'MACHINE LEARNING MODELS',
                  ),
                  const SizedBox(height: 6),

                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      _canCustomize
                          ? (_userLevel == 'advanced'
                              ? 'Available in Advanced mode.'
                              : 'Switch to Advanced mode to customize individual models.')
                          : 'Sign in to unlock advanced model controls.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.disabledText,
                      ),
                    ),
                  ),

                  _buildSwitchTile(
                    title: 'Use Ensemble',
                    subtitle: 'Turn off to manually select individual models',
                    value: _useEnsemble,
                    enabled: advancedModelsEnabled,
                    onChanged: (val) => setState(() => _useEnsemble = val),
                  ),

                  _buildSwitchTile(
                    title: 'Logistic Regression',
                    subtitle: 'Linear model for threat classification',
                    value: _useLogisticRegression,
                    enabled: advancedModelsEnabled && !_useEnsemble,
                    onChanged: (val) =>
                        setState(() => _useLogisticRegression = val),
                  ),
                  _buildSwitchTile(
                    title: 'Decision Tree',
                    subtitle: 'Rule-based tree classifier',
                    value: _useDecisionTree,
                    enabled: advancedModelsEnabled && !_useEnsemble,
                    onChanged: (val) => setState(() => _useDecisionTree = val),
                  ),
                  _buildSwitchTile(
                    title: 'XGBoost',
                    subtitle: 'Gradient boosted trees',
                    value: _useXGBoost,
                    enabled: advancedModelsEnabled && !_useEnsemble,
                    onChanged: (val) => setState(() => _useXGBoost = val),
                  ),
                  _buildSwitchTile(
                    title: 'LightGBM',
                    subtitle: 'Light gradient boosting (if available)',
                    value: _useLightGBM,
                    enabled: advancedModelsEnabled && !_useEnsemble,
                    onChanged: (val) => setState(() => _useLightGBM = val),
                  ),

                  const SizedBox(height: 24),

                  if (_canCustomize)
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
                                'Save Settings',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),

                  const SizedBox(height: 24), // was 20 → 24
                ],
              ),
            ),
    );
  }


  Widget _buildPlanAndModeCard() {
  final user = FirebaseAuth.instance.currentUser;
  final isGuest = user == null;
  final double disabledOpacity = _canCustomize ? 1.0 : 0.55;

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: _canCustomize
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.08),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔹 PLAN ROW
        Row(
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
              isGuest ? 'Free' : 'Premium',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isGuest
                    ? AppColors.disabledText
                    : AppColors.primaryPurple,
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Text(
            isGuest
                ? 'Sign in to unlock premium scanning (ML models, deep scan, external APIs)'
                : 'You have access to all features',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.disabledText,
            ),
          ),
        ),

        const SizedBox(height: 18),

        // SCAN MODE
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
            if (!_canCustomize) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.lock_outline,
                size: 16,
                color: AppColors.disabledText,
              ),
            ],
          ],
        ),

        const SizedBox(height: 4),

        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Text(
            _canCustomize
                ? 'Default: simple result. Advanced: detailed technical analysis.'
                : 'Visible for free users, but locked until sign in.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.disabledText,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // 🔹 RADIO BUTTONS
        Opacity(
          opacity: disabledOpacity,
          child: IgnorePointer(
            ignoring: !_canCustomize,
            child: Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                    dense: true,
                    title: Text(
                      'Default',
                      style: TextStyle(
                        color: _canCustomize
                            ? AppColors.primaryText
                            : AppColors.disabledText,
                      ),
                    ),
                    value: 'beginner',
                    groupValue: _userLevel,
                    activeColor: AppColors.primaryPurple,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _userLevel = value;
                          _useEnsemble = true;
                        });
                      }
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                    dense: true,
                    title: Text(
                      'Advanced',
                      style: TextStyle(
                        color: _canCustomize
                            ? AppColors.primaryText
                            : AppColors.disabledText,
                      ),
                    ),
                    value: 'advanced',
                    groupValue: _userLevel,
                    activeColor: AppColors.primaryPurple,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _userLevel = value;
                          _useEnsemble = true;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
  }) {
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
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    final double opacity = enabled ? 1.0 : 0.5;

    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? Colors.white.withOpacity(0.04)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: SwitchListTile(
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: enabled
                  ? AppColors.primaryText
                  : AppColors.disabledText,
            ),
          ),
          subtitle: Text(
            enabled ? subtitle : '$subtitle • Locked',
            style: TextStyle(
              color: enabled
                  ? AppColors.secondaryText
                  : AppColors.disabledText,
            ),
          ),
          value: value,
          onChanged: enabled ? onChanged : null,
          activeThumbColor: AppColors.primaryPurple,
          inactiveThumbColor: AppColors.disabledText,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          secondary: Icon(
            enabled
                ? (value ? Icons.check_circle : Icons.radio_button_unchecked)
                : Icons.lock_outline,
            color: enabled
                ? (value ? AppColors.safe : AppColors.disabledText)
                : AppColors.disabledText,
            size: 22,
          ),
        ),
      ),
    );
  }
}