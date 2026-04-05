import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'help_screen.dart';
import 'scan_settings_screen.dart';
import '../services/google_safe_browsing_service.dart';
import 'camera_scanner.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class RegisteredHomeScreen extends StatefulWidget {
  const RegisteredHomeScreen({super.key});

  @override
  State<RegisteredHomeScreen> createState() => _RegisteredHomeScreenState();
}

class _RegisteredHomeScreenState extends State<RegisteredHomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isScanning = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _scanURL(String url) async {
    setState(() => _isScanning = true);

    try {
      final bool? isSafe = await GoogleSafeBrowsingService().isUrlSafe(url);

      if (!mounted) return;

      if (isSafe == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This URL is safe!'),
            backgroundColor: AppColors.safe,
          ),
        );
      } else if (isSafe == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This URL is unsafe!'),
            backgroundColor: AppColors.highRisk,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not check URL. API or network error.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ready To Scan Alice?',
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
            Row(
              children: [
                _buildStatCard(Icons.qr_code_scanner, 'Total Scans', '100'),
                const SizedBox(width: 12),
                _buildStatCard(Icons.shield, 'Safe Links', '80'),
                const SizedBox(width: 12),
                _buildStatCard(Icons.warning_amber_rounded, 'Threats', '20'),
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
                              builder: (context) => const HistoryScreen(),
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
                  _buildRecentItem(
                    domain: 'google.com',
                    time: '4 URL scans • 2m ago',
                    statusText: 'Threat',
                    statusColor: AppColors.highRisk,
                    leadingColor: Colors.redAccent,
                    statusIcon: Icons.close_rounded,
                  ),
                  const SizedBox(height: 10),
                  _buildRecentItem(
                    domain: 'linkbitly.com',
                    time: '6 URL scans • 5d ago',
                    statusText: 'Warning',
                    statusColor: Colors.orange,
                    leadingColor: Colors.orange,
                    statusIcon: Icons.warning_amber_rounded,
                  ),
                  const SizedBox(height: 10),
                  _buildRecentItem(
                    domain: 'telegramlogin.com',
                    time: '4 URL scans • 5d ago',
                    statusText: 'Safe',
                    statusColor: AppColors.safe,
                    leadingColor: Colors.green,
                    statusIcon: Icons.check_rounded,
                  ),
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
        onPressed: _isScanning
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