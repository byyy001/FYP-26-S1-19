import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart'; // for WidgetsBindingObserver
import '../constants/app_colors.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'help_screen.dart';
import 'scan_settings_screen.dart';
import 'camera_scanner.dart';
import 'result_screen.dart';
import 'invalid_url_screen.dart';
import '../threat_engine/layer5_facade/threat_engine.dart';
import '../threat_engine/scan_settings.dart';

class UnregisteredHomeScreen extends StatefulWidget {
  const UnregisteredHomeScreen({super.key});

  @override
  State<UnregisteredHomeScreen> createState() => _UnregisteredHomeScreenState();
}

class _UnregisteredHomeScreenState extends State<UnregisteredHomeScreen> with WidgetsBindingObserver {
  final TextEditingController _urlController = TextEditingController();
  bool _isScanning = false;
  bool _engineReady = false;
  bool _engineLoading = true;
  String? _engineError;
  late final ThreatEngine _engine;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initEngine();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _urlController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Clear URL when app goes to background or is detached (session ends)
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _urlController.clear();
    }
  }

  Future<void> _initEngine() async {
    setState(() {
      _engineLoading = true;
      _engineError = null;
    });
    try {
      _engine = await ThreatEngine.getInstance();
      if (mounted) {
        setState(() {
          _engineReady = true;
          _engineLoading = false;
        });
      }
    } catch (e) {
      print('Engine initialization error: $e');
      if (mounted) {
        setState(() {
          _engineError = e.toString();
          _engineLoading = false;
          _engineReady = false;
        });
      }
    }
  }

  void _retryInit() {
    _initEngine();
  }

  void _showAuthDialog({String feature = 'this feature'}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text(
            'Sign In Required',
            style: TextStyle(color: AppColors.primaryText),
          ),
          content: Text(
            'You need to be signed in to use $feature. Would you like to log in or create an account?',
            style: const TextStyle(color: AppColors.secondaryText),
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
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
              ),
              child: const Text('Login'),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignUpScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryPurple),
              ),
              child: const Text(
                'Sign Up',
                style: TextStyle(color: AppColors.primaryPurple),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Normalize URL: remove spaces, add https:// if missing
  String _normalizeUrl(String input) {
    String url = input.trim().replaceAll(RegExp(r'\s+'), '');
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    return url;
  }

  /// Validate URL and return list of reasons if invalid, otherwise null
  List<String>? _validateUrl(String rawUrl) {
    final String trimmed = rawUrl.trim();
    final List<String> reasons = [];

    if (trimmed.isEmpty) {
      reasons.add('URL is empty');
      return reasons;
    }

    // Check for invalid characters
    String urlForCheck = trimmed;
    if (!urlForCheck.contains('://')) {
      urlForCheck = 'https://$urlForCheck';
    }

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
      if (trimmed.contains(RegExp(r'\s'))) {
        reasons.add('URL contains spaces');
      }
      if (trimmed.contains('//') && !trimmed.startsWith('http')) {
        reasons.add('Invalid double slash');
      }
    } catch (e) {
      reasons.add('URL format not recognised');
    }

    return reasons.isEmpty ? null : reasons;
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

    // Validate URL first
    final invalidReasons = _validateUrl(rawUrl);
    if (invalidReasons != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InvalidUrlScreen(reasons: invalidReasons),
        ),
      );
      return;
    }

    final url = _normalizeUrl(rawUrl);

    setState(() => _isScanning = true);

    try {
      final settings = ScanSettings.defaultSettings();
      final result = await _engine.analyze(url, settings: settings);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen.fromEngineResult(
            engineResult: result['scan_result'],
            settings: settings,
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
            onPressed: () => _showAuthDialog(feature: 'notifications'),
          ),
          const SizedBox(width: 0),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            icon: const Icon(
              Icons.person_outline_rounded,
              color: AppColors.primaryText,
              size: 25,
            ),
            onPressed: () => _showAuthDialog(feature: 'your profile'),
          ),
          const SizedBox(width: 18),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to LinkSentry',
              style: TextStyle(
                fontSize: isSmall ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sign in to access all features!',
              style: TextStyle(
                fontSize: isSmall ? 13 : 15,
                color: AppColors.secondaryText,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                _buildStatCard(Icons.qr_code_scanner, 'Total Scans', '0'),
                const SizedBox(width: 12),
                _buildStatCard(Icons.shield, 'Safe Links', '0'),
                const SizedBox(width: 12),
                _buildStatCard(Icons.warning_amber_rounded, 'Threats', '0'),
              ],
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
                  if (_engineLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Loading security engine...',
                              style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_engineError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        children: [
                          Text(
                            'Failed to load scanner: $_engineError',
                            style: const TextStyle(color: AppColors.highRisk, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _retryInit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recents',
                          style: TextStyle(
                            fontSize: isSmall ? 16 : 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sign in to save your scan history',
                          style: TextStyle(
                            fontSize: isSmall ? 11 : 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildGradientLoginButton(context),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildCustomBottomNav(context),
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value) {
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
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
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
    final bool isDisabled = _engineLoading || _isScanning || _engineError != null;
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

  Widget _buildGradientLoginButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.premiumGradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        },
        icon: const Icon(Icons.login_rounded, color: Colors.white, size: 18),
        label: const Text(
          'Login',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
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
                    onTap: () => _showAuthDialog(feature: 'analytics'),
                  ),
                  _buildNavItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ScanSettingsScreen(),
                        ),
                      );
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
                final result = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(builder: (context) => const CameraScanner()),
                );
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