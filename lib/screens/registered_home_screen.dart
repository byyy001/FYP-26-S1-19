import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../services/scan_history_service.dart';
import '../threat_engine/layer5_facade/threat_engine.dart';
import '../threat_engine/scan_settings.dart';
import 'verdict_notifications_screen.dart';
import 'help_screen.dart';
import 'scan_settings_screen.dart';
import 'security_insights_screen.dart';
import 'camera_scanner.dart';
import 'view_history_screen.dart';
import 'profile_screen.dart';
import 'result_screen.dart';
import 'invalid_url_screen.dart';
import '../services/notification_service.dart';

String formatFirestoreTimestamp(Timestamp timestamp) {
  final DateTime dateTime = timestamp.toDate();
  return DateFormat('MMM d, hh:mm a').format(dateTime);
}

class RegisteredHomeScreen extends StatefulWidget {
  final bool showLoginSuccess;
  const RegisteredHomeScreen({super.key, this.showLoginSuccess = false});

  @override
  State<RegisteredHomeScreen> createState() => _RegisteredHomeScreenState();
}

class _RegisteredHomeScreenState extends State<RegisteredHomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final ScanHistoryService _scanHistoryService = ScanHistoryService();
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.showLoginSuccess) _showLoginSuccessBanner();
      await _checkAndFireRescanNotifications();
    });
  }

  Future<void> _checkAndFireRescanNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final prefsDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('notification_preferences')
          .get();

      final prefs = prefsDoc.data();
      final allowNotifications = prefs?['allowNotifications'] ?? false;
      if (!allowNotifications) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('safe_scans')
          .where('uid', isEqualTo: user.uid)
          .where('rescanned', isEqualTo: true)
          .where('notifiedUser', isEqualTo: false)
          .get();

      final changed = snapshot.docs.where((doc) {
        final verdict = doc.data()['rescannedVerdict']?.toString().toLowerCase() ?? '';
        return verdict.isNotEmpty && verdict != 'safe' && verdict != 'error';
      }).toList();

      if (changed.isEmpty) return;

      final count = changed.length;
      final firstUrl = changed.first.data()['url']?.toString() ?? '';
      final shortUrl = firstUrl.length > 40 ? '${firstUrl.substring(0, 40)}…' : firstUrl;
      final sound = prefs?['sound'] ?? false;

      await NotificationService.instance.showRescanAlert(
        count: count,
        firstUrl: shortUrl,
        playSound: sound,
      );
    } catch (e) {
      debugPrint('Rescan notification check error: $e');
    }
  }

  void _showLoginSuccessBanner() {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: 0,
        right: 0,
        bottom: 74,
        child: Material(
          color: Colors.transparent,
          child: Container(
            height: 56,
            color: Colors.green,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Text('Login successful',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () => entry.remove());
  }

  void _showDeleteHistoryBanner() {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: 0,
        right: 0,
        bottom: 74,
        child: Material(
          color: Colors.transparent,
          child: Container(
            height: 56,
            color: AppColors.primaryPurple,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Text('Scan history deleted successfully.',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () => entry.remove());
  }

  void _showScanSuccessBanner() {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: 0,
        right: 0,
        bottom: 74,
        child: Material(
          color: Colors.transparent,
          child: Container(
            height: 56,
            color: AppColors.primaryPurple,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Text(
              'Scan completed successfully.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () => entry.remove());
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
      if (mounted) {
        setState(() {
          _userSettings = ScanSettings.forBeginner();
          _settingsLoaded = true;
        });
      }
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
        final newSettings = ScanSettings(
          phishingSensitivity: data['phishingSensitivity'] ?? true,
          httpSitesWarning: false,
          scriptAnalysis: data['scriptAnalysis'] ?? true,
          adReductionAnalysis: false,
          adDensityLevel: 1,
          autoRecheckScans: false,
          sharingConfiguration: false,
          useExternalApis: data['useExternalApis'] ?? true,
          // FIX: Force isPremium = true for any logged‑in user
          isPremium: true,
          userLevel: data['userLevel'] ?? 'beginner',
          enableMachineLearning: true,
          useEnsemble: data['useEnsemble'] ?? true,
          useLogisticRegression: data['useLogisticRegression'] ?? true,
          useDecisionTree: data['useDecisionTree'] ?? true,
          useXGBoost: data['useXGBoost'] ?? true,
          useLightGBM: data['useLightGBM'] ?? true,
          deepScan: data['deepScan'] ?? true,
          adFilter: false,
        );
        if (mounted) {
          setState(() {
            _userSettings = newSettings;
          });
        }
      } else {
        // No saved settings – create default premium settings
        if (mounted) {
          setState(() {
            _userSettings = ScanSettings(
              phishingSensitivity: true,
              httpSitesWarning: false,
              scriptAnalysis: true,
              adReductionAnalysis: false,
              adDensityLevel: 1,
              autoRecheckScans: false,
              sharingConfiguration: false,
              useExternalApis: true,
              isPremium: true,
              userLevel: 'beginner',
              enableMachineLearning: true,
              useEnsemble: true,
              useLogisticRegression: true,
              useDecisionTree: true,
              useXGBoost: true,
              useLightGBM: true,
              deepScan: true,
              adFilter: false,
            );
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading scan settings: $e');
    } finally {
      if (mounted) setState(() => _settingsLoaded = true);
    }
  }

  Future<Map<String, int>> _getScanStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'totalScans': 0, 'safeLinks': 0, 'threats': 0};
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
      } else if (verdict == 'malicious' || verdict == 'suspicious' || verdict == 'low risk') {
        threats++;
      }
    }
    return {'totalScans': snapshot.docs.length, 'safeLinks': safeLinks, 'threats': threats};
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<String> getUserFirstName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'User';
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists) return userDoc['firstName'] ?? 'User';
    return 'User';
  }

  Future<void> _saveScanToFirestore({required String url, required Map<String, dynamic> scanResult}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final riskScore = double.tryParse(scanResult['risk_score'] ?? '0') ?? 0.0;
    final verdict = riskScore >= 76 ? 'Malicious' : (riskScore >= 51 ? 'Suspicious' : (riskScore >= 26 ? 'Low Risk' : 'Safe'));
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
      'mlConfidence': scanResult['ml_confidence'] ?? 'none',
      'mlScore': double.tryParse(scanResult['ml_score']?.toString() ?? '0') ?? 0.0,
      'aiScore': double.tryParse(scanResult['ai_score']?.toString() ?? '0') ?? 0.0,
      'behaviorScore': double.tryParse(scanResult['behavior_score']?.toString() ?? '0') ?? 0.0,
      'externalScore': double.tryParse(scanResult['external_score']?.toString() ?? '0') ?? 0.0,
      'actions': scanResult['actions'] is List ? List<String>.from(scanResult['actions']) : [],
      'safetyTips': scanResult['safety_tips'] is List ? List<String>.from(scanResult['safety_tips']) : [],
      'detailedDetectedThreats': scanResult['detailed_detected_threats'] ?? [],
      'behaviorMatchedPatterns': scanResult['behavior_matched_patterns'] ?? [],
      'behaviorCategories': scanResult['behavior_categories'],
      'ensembleProbabilities': scanResult['ensemble_probabilities'],
    });

    if (verdict == 'Safe') {
      await FirebaseFirestore.instance.collection('safe_scans').add({
        'uid': user.uid,
        'url': url,
        'verdict': verdict,
        'riskScore': riskScore,
        'scannedAt': FieldValue.serverTimestamp(),
        'rescanned': false,
        'rescannedAt': null,
        'rescannedVerdict': null,
        'notifiedUser': false,
      });
    }
  }

  String _normalizeUrl(String input) {
    String url = input.trim().replaceAll(RegExp(r'\s+'), '');
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    return url;
  }

  List<String>? _validateUrl(String rawUrl) {
    final String trimmed = rawUrl.trim();
    final List<String> reasons = [];
    if (trimmed.isEmpty) return ['URL is empty'];
    String urlForCheck = trimmed;
    if (!urlForCheck.contains('://')) urlForCheck = 'https://$urlForCheck';
    try {
      final uri = Uri.parse(urlForCheck);
      if (uri.scheme.isEmpty || (uri.scheme != 'http' && uri.scheme != 'https')) {
        reasons.add('Missing or invalid protocol (use http:// or https://)');
      }
      if (uri.host.isEmpty) {
        reasons.add('Domain name not recognised');
      } else if (!uri.host.contains('.')) {
        reasons.add('Domain must contain a dot (e.g., example.com)');
      }
      if (trimmed.contains(RegExp(r'\s'))) reasons.add('URL contains spaces');
      if (trimmed.contains('//') && !trimmed.startsWith('http')) reasons.add('Invalid double slash');
    } catch (e) {
      reasons.add('URL format not recognised');
    }
    return reasons.isEmpty ? null : reasons;
  }

  Future<void> _scanURL(String rawUrl) async {
    if (!_engineReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scanner is still loading, please wait...'), backgroundColor: AppColors.primaryPurple),
      );
      return;
    }
    final invalidReasons = _validateUrl(rawUrl);
    if (invalidReasons != null) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => InvalidUrlScreen(reasons: invalidReasons)),
      );
      return;
    }
    final url = _normalizeUrl(rawUrl);
    setState(() => _isScanning = true);
    try {
      final result = await _engine.analyze(url, settings: _userSettings);
      if (!mounted) return;
      await _saveScanToFirestore(url: url, scanResult: result['scan_result']);

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen.fromEngineResult(
            engineResult: result['scan_result'],
            settings: _userSettings,
          ),
        ),
      );

      if (!mounted) return;

      setState(() {
        _statsFuture = _getScanStats();
      });

      _showScanSuccessBanner();
    } catch (e, stack) {
      debugPrint('SCAN ERROR: $e');
      debugPrint('STACK: $stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan error: $e'), backgroundColor: AppColors.highRisk),
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
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 84,
        centerTitle: false,
        titleSpacing: 22,
        title: Image.asset('assets/images/LinkSentryLogoTop.png', height: 48, fit: BoxFit.contain),
        actions: [
          _buildBellWithBadge(context),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: GestureDetector(
              onTap: () async {
                final deletedHistory = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
                if (!mounted) return;
                if (deletedHistory == true) {
                  if (mounted) {
                    setState(() {
                      _statsFuture = _getScanStats();
                    });
                  }
                  _showDeleteHistoryBanner();
                }
              },
              child: const CircleAvatar(radius: 10, backgroundColor: AppColors.primaryPurple),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: AppColors.divider.withAlpha(60), thickness: 0.6, height: 1),
        ),
      ),
      body: FutureBuilder<String>(
        future: getUserFirstName(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final String userName = snapshot.data ?? 'User';
          if (!_settingsLoaded || !_engineReady) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurple)),
                  const SizedBox(height: 16),
                  Text(
                    _initError != null ? 'Failed to load scanner' : 'Loading security engine...',
                    style: const TextStyle(color: AppColors.secondaryText),
                  ),
                  if (_initError != null) ...[
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _retryInit,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
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
                  style: TextStyle(fontSize: isSmall ? 20 : 24, fontWeight: FontWeight.bold, color: AppColors.primaryText),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap camera to scan link or paste URL below',
                  style: TextStyle(fontSize: isSmall ? 13 : 15, color: AppColors.secondaryText, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 24),
                FutureBuilder<Map<String, int>>(
                  future: _getScanStats(),
                  builder: (context, statsSnapshot) {
                    final stats = statsSnapshot.data ?? {'totalScans': 0, 'safeLinks': 0, 'threats': 0};
                    return Row(
                      children: [
                        _buildStatCard(
                          Icons.qr_code_scanner,
                          'Total Scans',
                          '${stats['totalScans'] ?? 0}',
                          themeColor: AppColors.primaryPurple,
                          iconColor: AppColors.primaryPurple,
                          valueColor: AppColors.primaryText,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          Icons.shield,
                          'Safe Links',
                          '${stats['safeLinks'] ?? 0}',
                          themeColor: AppColors.safe,
                          iconColor: AppColors.safe,
                          valueColor: AppColors.safe,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          Icons.warning_amber_rounded,
                          'Threats',
                          '${stats['threats'] ?? 0}',
                          themeColor: AppColors.highRisk,
                          iconColor: AppColors.highRisk,
                          valueColor: AppColors.highRisk,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildScanCard(isSmall),
                const SizedBox(height: 16),
                _buildRecentsCard(isSmall),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _buildCustomBottomNav(context),
    );
  }

  Widget _buildBellWithBadge(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        icon: const Icon(Icons.notifications_none_rounded, color: AppColors.primaryText, size: 25),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerdictNotificationsScreen())),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_notifications')
          .where('uid', isEqualTo: user.uid)
          .where('notifiedUser', isEqualTo: false)
          .snapshots(),
      builder: (context, adminSnapshot) {
        final adminUnread = adminSnapshot.data?.docs.length ?? 0;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('safe_scans')
              .where('uid', isEqualTo: user.uid)
              .where('rescanned', isEqualTo: true)
              .where('notifiedUser', isEqualTo: false)
              .snapshots(),
          builder: (context, verdictSnapshot) {
            final verdictUnread = (verdictSnapshot.data?.docs ?? []).where((doc) {
              final verdict = (doc.data() as Map<String, dynamic>)['rescannedVerdict']?.toString().toLowerCase() ?? '';
              return verdict.isNotEmpty && verdict != 'safe';
            }).length;

            final unreadCount = adminUnread + verdictUnread;

            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerdictNotificationsScreen())),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none_rounded, color: AppColors.primaryText, size: 25),
                    if (unreadCount > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(color: AppColors.highRisk, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String label,
    String value, {
    required Color themeColor,
    required Color iconColor,
    required Color valueColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: themeColor.withValues(alpha: 0.4), width: 1.2),
          boxShadow: [BoxShadow(color: themeColor.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: valueColor)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildScanCard(bool isSmall) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link_rounded, size: 20, color: AppColors.primaryPurple),
              const SizedBox(width: 6),
              Text(
                'Scan a Link',
                style: TextStyle(fontSize: isSmall ? 18 : 20, fontWeight: FontWeight.w700, color: AppColors.primaryText),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Paste any URL to check if it\'s safe',
            style: TextStyle(fontSize: isSmall ? 12 : 14, color: AppColors.secondaryText),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    hintText: 'example-link.com',
                    hintStyle: const TextStyle(color: AppColors.disabledText),
                    filled: true,
                    fillColor: AppColors.mainBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  style: const TextStyle(color: AppColors.primaryText),
                ),
              ),
              const SizedBox(width: 10),
              _buildScanButton(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentsCard(bool isSmall) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.3), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, size: 18, color: AppColors.primaryPurple),
              const SizedBox(width: 6),
              Text('Recents', style: TextStyle(fontSize: isSmall ? 16 : 18, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ViewHistoryScreen())),
                child: const Text('View History →', style: TextStyle(color: AppColors.primaryPurple, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: _scanHistoryService.getHistoryStream(),
            builder: (context, historySnapshot) {
              if (historySnapshot.connectionState == ConnectionState.waiting) {
                return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()));
              }
              final docs = historySnapshot.data?.docs ?? [];
              if (docs.isEmpty) return _buildEmptyState();
              return ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final riskScore = (data['riskScore'] as num?)?.toDouble() ?? 0.0;
                  final statusText = _getStatusFromRiskScore(riskScore);
                  final timestamp = data['scannedAt'];
                  final formattedTime = timestamp is Timestamp ? formatFirestoreTimestamp(timestamp) : 'Just now';
                  final domain = data['url']?.toString() ?? 'Unknown URL';
                  final source = data['source']?.toString() ?? 'URL scan';
                  return _buildRecentItem(
                    domain: domain,
                    time: '$source • $formattedTime',
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
    );
  }

  String _getStatusFromRiskScore(double riskScore) {
    if (riskScore >= 76) return 'Malicious';
    if (riskScore >= 51) return 'Suspicious';
    if (riskScore >= 26) return 'Low Risk';
    return 'Safe';
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: const Column(
        children: [
          Icon(Icons.history_toggle_off, color: AppColors.secondaryText, size: 48),
          SizedBox(height: 12),
          Text('No recent scans found', style: TextStyle(color: AppColors.secondaryText, fontSize: 15, fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('Your latest scans will appear here', style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
        ],
      ),
    );
  }

  Color _statusColor(String statusText) {
    switch (statusText.toLowerCase()) {
      case 'safe':
        return AppColors.safe;
      case 'suspicious':
        return AppColors.mediumRisk;
      case 'low risk':
        return AppColors.mediumRisk;
      case 'malicious':
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
      case 'low risk':
        return Icons.warning_amber_rounded;
      case 'malicious':
        return Icons.cancel_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Widget _buildScanButton(BuildContext context) {
    final bool isDisabled = !_engineReady || _isScanning || _initError != null;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.premiumGradient, begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ElevatedButton.icon(
        onPressed: isDisabled
            ? null
            : () {
                final url = _urlController.text.trim();
                if (url.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a URL')));
                  return;
                }
                _scanURL(url);
              },
        icon: _isScanning
            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
        label: Text(_isScanning ? '...' : 'Scan', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: leadingColor, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(domain, style: const TextStyle(color: AppColors.primaryText, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(time, style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
              ],
            ),
          ),
          Row(
            children: [
              Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 4),
              Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w700)),
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
                border: Border(top: BorderSide(color: AppColors.divider.withAlpha(50), width: 0.6)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(icon: Icons.home_rounded, label: 'Home', isSelected: true, onTap: () {}),
                  _buildNavItem(
                    icon: Icons.help_outline_rounded,
                    label: 'Help',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpScreen())),
                  ),
                  const SizedBox(width: 78),
                  _buildNavItem(
                    icon: Icons.analytics_outlined,
                    label: 'Analytics',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SecurityInsightsScreen())),
                  ),
                  _buildNavItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (context) => const ScanSettingsScreen()));
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
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final result = await Navigator.push<String>(context, MaterialPageRoute(builder: (context) => const CameraScanner()));
                if (result != null && result.isNotEmpty && mounted) {
                  setState(() => _urlController.text = result);
                  messenger.showSnackBar(
                    SnackBar(content: Text('Extracted: $result'), duration: const Duration(seconds: 2)),
                  );
                }
              },
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: AppColors.premiumGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(color: AppColors.primaryPurple.withAlpha(90), blurRadius: 18, offset: const Offset(0, 6))],
                  border: Border.all(color: AppColors.mainBackground, width: 3),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
                    SizedBox(height: 1),
                    Text('Scan', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
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
    final Color color = isSelected ? AppColors.primaryPurple : AppColors.secondaryText;
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
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}