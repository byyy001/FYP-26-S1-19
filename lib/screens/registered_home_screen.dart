import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import 'help_screen.dart';
import 'scan_settings_screen.dart';
import 'camera_scanner.dart';
import 'view_history_screen.dart';
import 'profile_screen.dart';
import 'result_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/scan_history_service.dart';
import '../services/scan_settings_service.dart';
import '../threat_engine/layer5_facade/threat_engine.dart';
import '../threat_engine/scan_settings.dart';

String formatFirestoreTimestamp(Timestamp timestamp) {
  DateTime dateTime = timestamp.toDate();
  return DateFormat('MMM d, hh:mm a').format(dateTime);
}

class RegisteredHomeScreen extends StatefulWidget {
  const RegisteredHomeScreen({super.key});

  @override
  State<RegisteredHomeScreen> createState() => _RegisteredHomeScreenState();
}

class _RegisteredHomeScreenState extends State<RegisteredHomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final ScanHistoryService _scanHistoryService = ScanHistoryService();
  final ScanSettingsService _scanSettingsService = ScanSettingsService();
  bool _isScanning = false;
  bool _engineReady = false;
  bool _settingsLoaded = false;
  String? _initError;
  late final ThreatEngine _engine;
  late Future<Map<String, int>> _statsFuture;
  ScanSettings _userSettings = ScanSettings.forBeginner();

  @override
  void initState() {
    super.initState();
    _initEngine();
    _loadUserSettings();
    _statsFuture = _getScanStats();
  }

  Future<void> _initEngine() async {
    try {
      _engine = await ThreatEngine.getInstance();
      if (mounted) {
        setState(() {
          _engineReady = true;
          _initError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _engineReady = false;
          _initError = e.toString();
        });
      }
    }
  }

  Future<void> _retryInit() async {
    setState(() {
      _engineReady = false;
      _initError = null;
    });
    await _initEngine();
  }

  Future<void> _loadUserSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _settingsLoaded = true);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('scan_preferences')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final userLevel = data['userLevel'] ?? 'beginner';
        final isPremium = data['isPremium'] ?? true;
        final phishingSensitivity = data['phishingSensitivity'] ?? true;
        final deepScan = data['deepScan'] ?? true;
        final scriptAnalysis = data['scriptAnalysis'] ?? true;
        final useExternalApis = data['useExternalApis'] ?? true;
        final useEnsemble = data['useEnsemble'] ?? (userLevel == 'beginner');
        final useLogisticRegression = data['useLogisticRegression'] ?? true;
        final useDecisionTree = data['useDecisionTree'] ?? true;
        final useXGBoost = data['useXGBoost'] ?? true;
        final useLightGBM = data['useLightGBM'] ?? true;

        if (mounted) {
          setState(() {
            _userSettings = ScanSettings(
              phishingSensitivity: phishingSensitivity,
              httpSitesWarning: false,
              scriptAnalysis: scriptAnalysis,
              adReductionAnalysis: false,
              adDensityLevel: 1,
              autoRecheckScans: false,
              sharingConfiguration: false,
              useExternalApis: useExternalApis,
              isPremium: isPremium,
              userLevel: userLevel,
              enableMachineLearning: true,
              useEnsemble: useEnsemble,
              useLogisticRegression: useLogisticRegression,
              useDecisionTree: useDecisionTree,
              useXGBoost: useXGBoost,
              useLightGBM: useLightGBM,
              deepScan: deepScan,
              adFilter: false,
            );
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _userSettings = ScanSettings.forBeginner();
          });
        }
      }
    } catch (e) {
      print('Error loading scan settings: $e');
    } finally {
      if (mounted) setState(() => _settingsLoaded = true);
    }
  }

  Future<Map<String, int>> _getScanStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {
        'totalScans': 0,
        'safeLinks': 0,
        'threats': 0,
      };
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('scans')
        .get();

    int safeLinks = 0;
    int threats = 0;

    for (final doc in snapshot.docs) {
      final verdict = (doc.data()['verdict'] ?? '').toString().toLowerCase();
      if (verdict == 'safe') {
        safeLinks++;
      } else if (verdict == 'unsafe' || verdict == 'suspicious') {
        threats++;
      }
    }

    return {
      'totalScans': snapshot.docs.length,
      'safeLinks': safeLinks,
      'threats': threats,
    };
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<String> getUserFirstName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'User';
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (userDoc.exists) {
      return userDoc['firstName'] ?? 'User';
    }
    return 'User';
  }

  Future<void> _saveScanToFirestore({
    required String url,
    required Map<String, dynamic> scanResult,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final riskScore = double.tryParse(scanResult['risk_score'] ?? '0') ?? 0.0;
    final verdict = riskScore >= 50 ? 'Unsafe' : (riskScore >= 25 ? 'Suspicious' : 'Safe');
    final threatType = scanResult['threat_type'] ?? 'unknown';

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('scans')
        .add({
      'url': url,
      'result': verdict,
      'source': 'URL scan',
      'verdict': verdict,
      'riskScore': riskScore,
      'threatType': threatType,
      'explanation': scanResult['explanation'] ?? '',
      'detectedThreats': scanResult['detected_threats'] ?? [],
      'externalSources': scanResult['external_sources'] ?? [],
      'scannedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      setState(() {
        _statsFuture = _getScanStats();
      });
    }
  }

  /// Normalize URL: remove spaces, add https:// if missing
  String _normalizeUrl(String input) {
    String url = input.trim().replaceAll(RegExp(r'\s+'), '');
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    return url;
  }

  Future<void> _scanURL(String rawUrl) async {
    if (!_engineReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scanner is still loading, please wait...'),
          backgroundColor: AppColors.primaryPurple,
        ),
      );
      return;
    }

    final url = _normalizeUrl(rawUrl);

    setState(() => _isScanning = true);

    try {
      final result = await _engine.analyze(url, settings: _userSettings);

      if (!mounted) return;

      await _saveScanToFirestore(url: url, scanResult: result['scan_result']);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen.fromEngineResult(
            engineResult: result['scan_result'],
            settings: _userSettings,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan error: $e'),
          backgroundColor: AppColors.highRisk,
        ),
      );
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmall = screenWidth < 360;

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.mainBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 84,
        centerTitle: false,
        titleSpacing: 22,
        title: Image.asset(
          'assets/images/LinkSentryLogoTop.png',
          height: 48,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.primaryText,
              size: 25,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications coming soon')),
              );
            },
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
              child: const CircleAvatar(
                radius: 10,
                backgroundColor: AppColors.primaryPurple,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            color: AppColors.divider.withAlpha(60),
            thickness: 0.6,
            height: 1,
          ),
        ),
      ),
      body: FutureBuilder<String>(
        future: getUserFirstName(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          String userName = snapshot.data ?? 'User';

          if (!_settingsLoaded || !_engineReady) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _initError != null ? 'Failed to load scanner' : 'Loading security engine...',
                    style: const TextStyle(color: AppColors.secondaryText),
                  ),
                  if (_initError != null) ...[
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _retryInit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready To Scan $userName?',
                  style: TextStyle(
                    fontSize: isSmall ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap camera to scan link or paste URL below',
                  style: TextStyle(
                    fontSize: isSmall ? 13 : 15,
                    color: AppColors.secondaryText,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 22),
                FutureBuilder<Map<String, int>>(
                  future: _statsFuture,
                  builder: (context, statsSnapshot) {
                    final stats = statsSnapshot.data ??
                        {
                          'totalScans': 0,
                          'safeLinks': 0,
                          'threats': 0,
                        };

                    return Row(
                      children: [
                        _buildStatCard(
                          Icons.qr_code_scanner,
                          'Total Scans',
                          '${stats['totalScans'] ?? 0}',
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          Icons.shield,
                          'Safe Links',
                          '${stats['safeLinks'] ?? 0}',
                          valueColor: AppColors.safe,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          Icons.warning_amber_rounded,
                          'Threats',
                          '${stats['threats'] ?? 0}',
                          valueColor: AppColors.highRisk,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.link_rounded,
                            size: 20,
                            color: AppColors.primaryPurple,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Scan a Link',
                            style: TextStyle(
                              fontSize: isSmall ? 18 : 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Paste any URL to check if it\'s safe',
                        style: TextStyle(
                          fontSize: isSmall ? 12 : 14,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _urlController,
                              decoration: InputDecoration(
                                hintText: 'example-link.com',
                                hintStyle: const TextStyle(
                                  color: AppColors.disabledText,
                                ),
                                filled: true,
                                fillColor: AppColors.mainBackground,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              style: const TextStyle(
                                color: AppColors.primaryText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildScanButton(context),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.history_rounded,
                            size: 18,
                            color: AppColors.primaryPurple,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Recents',
                            style: TextStyle(
                              fontSize: isSmall ? 16 : 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryText,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ViewHistoryScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'View History →',
                              style: TextStyle(
                                color: AppColors.primaryPurple,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<QuerySnapshot>(
                        stream: _scanHistoryService.getHistoryStream(),
                        builder: (context, historySnapshot) {
                          if (historySnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          final docs = historySnapshot.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return _buildEmptyState();
                          }

                          return ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final data =
                                  docs[index].data() as Map<String, dynamic>;
                              final statusText = (data['result'] ??
                                      data['verdict'] ??
                                      'Unknown')
                                  .toString();
                              final timestamp = data['scannedAt'];
                              final formattedTime = timestamp is Timestamp
                                  ? formatFirestoreTimestamp(timestamp)
                                  : 'Just now';

                              return _buildRecentItem(
                                domain:
                                    data['url']?.toString() ?? 'Unknown URL',
                                time:
                                    '${data['source']?.toString() ?? 'URL scan'} • $formattedTime',
                                statusText: statusText,
                                statusColor: _statusColor(statusText),
                                leadingColor: _statusColor(statusText),
                                statusIcon: _statusIcon(statusText),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _buildCustomBottomNav(context),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: const Column(
        children: [
          Icon(
            Icons.history_toggle_off,
            color: AppColors.secondaryText,
            size: 48,
          ),
          SizedBox(height: 12),
          Text(
            'No recent scans found',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Your latest scans will appear here',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String statusText) {
    switch (statusText.toLowerCase()) {
      case 'safe':
        return AppColors.safe;
      case 'suspicious':
        return Colors.orange;
      case 'unsafe':
      case 'threat':
        return AppColors.highRisk;
      default:
        return AppColors.secondaryText;
    }
  }

  IconData _statusIcon(String statusText) {
    switch (statusText.toLowerCase()) {
      case 'safe':
        return Icons.check_rounded;
      case 'suspicious':
        return Icons.warning_amber_rounded;
      case 'unsafe':
      case 'threat':
        return Icons.close_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Widget _buildStatCard(
    IconData icon,
    String label,
    String value, {
    Color valueColor = AppColors.primaryText,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryPurple, size: 26),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton(BuildContext context) {
    final bool isDisabled = !_engineReady || _isScanning || _initError != null;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.premiumGradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ElevatedButton.icon(
        onPressed: isDisabled
            ? null
            : () {
                final url = _urlController.text.trim();
                if (url.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a URL')),
                  );
                  return;
                }
                _scanURL(url);
              },
        icon: _isScanning
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.shield_outlined,
                color: Colors.white,
                size: 18,
              ),
        label: Text(
          _isScanning ? '...' : 'Scan',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentItem({
    required String domain,
    required String time,
    required String statusText,
    required Color statusColor,
    required Color leadingColor,
    required IconData statusIcon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: leadingColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  domain,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(
                statusIcon,
                size: 16,
                color: statusColor,
              ),
              const SizedBox(width: 4),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomBottomNav(BuildContext context) {
    return SizedBox(
      height: 94,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 74,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                border: Border(
                  top: BorderSide(
                    color: AppColors.divider.withAlpha(50),
                    width: 0.6,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    isSelected: true,
                    onTap: () {},
                  ),
                  _buildNavItem(
                    icon: Icons.help_outline_rounded,
                    label: 'Help',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HelpScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 78),
                  _buildNavItem(
                    icon: Icons.analytics_outlined,
                    label: 'Analytics',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Analytics coming soon')),
                      );
                    },
                  ),
                  _buildNavItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ScanSettingsScreen(),
                        ),
                      );
                      // Reload settings after returning
                      await _loadUserSettings();
                    },
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -2,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CameraScanner(),
                  ),
                );
              },
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: AppColors.premiumGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withAlpha(90),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: AppColors.mainBackground,
                    width: 3,
                  ),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Scan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    final Color color =
        isSelected ? AppColors.primaryPurple : AppColors.secondaryText;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
