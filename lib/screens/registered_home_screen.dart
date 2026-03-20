import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/google_safe_browsing_service.dart';
import 'help_screen.dart';
import 'scan_settings_screen.dart';
import 'security_insights_screen.dart'; // analytics screen

class RegisteredHomeScreen extends StatefulWidget {
  const RegisteredHomeScreen({super.key});

  @override
  State<RegisteredHomeScreen> createState() => _RegisteredHomeScreenState();
}

class _RegisteredHomeScreenState extends State<RegisteredHomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isScanning = false;

  // Fetch user's first name from Firestore
  Future<String> getUserFirstName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        return userDoc['firstName'] ?? 'User';
      }
    }
    return 'User';
  }

  // Scan using Google Safe Browsing API
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
      backgroundColor: AppColors.mainBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Image.asset(
          'assets/images/LinkSentryLogoTop.png',
          height: 40,
          fit: BoxFit.contain,
        ),
        actions: [
          // Notification icon
          IconButton(
            icon: const Icon(
              Icons.notifications_none,
              color: AppColors.primaryText,
            ),
            onPressed: () {
              // TODO: Open notifications screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notifications coming soon!'),
                  backgroundColor: AppColors.primaryPurple,
                ),
              );
            },
          ),
          // Profile icon
          IconButton(
            icon: const Icon(
              Icons.person_outline,
              color: AppColors.primaryText,
            ),
            onPressed: () {
              // TODO: Navigate to profile screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile screen coming soon!'),
                  backgroundColor: AppColors.primaryPurple,
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: getUserFirstName(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading user data'));
          }
          final userName = snapshot.data ?? 'User';

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Greeting
                  Text(
                    'Ready To Scan $userName?',
                    style: TextStyle(
                      fontSize: isSmall ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap camera to scan link or paste URL below',
                    style: TextStyle(
                      fontSize: isSmall ? 14 : 16,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Stats cards with icons
                  Row(
                    children: [
                      _buildStatCard(
                        icon: Icons.qr_code_scanner,
                        label: 'Total Scans',
                        value: '100',
                        valueColor: AppColors.primaryText,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        icon: Icons.shield,
                        label: 'Safe Links',
                        value: '80',
                        valueColor: AppColors.safe,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        icon: Icons.warning_amber,
                        label: 'Threats',
                        value: '20',
                        valueColor: AppColors.highRisk,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Scan section
                  Text(
                    'Scan a Link',
                    style: TextStyle(
                      fontSize: isSmall ? 18 : 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paste any URL to check if it\'s safe',
                    style: TextStyle(
                      fontSize: isSmall ? 12 : 14,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // URL input row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: InputDecoration(
                            hintText: 'example-link.com',
                            hintStyle: TextStyle(color: AppColors.disabledText),
                            filled: true,
                            fillColor: AppColors.cardBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          style: const TextStyle(color: AppColors.primaryText),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildScanButton(context),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Recents section header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recents',
                        style: TextStyle(
                          fontSize: isSmall ? 18 : 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryText,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // TODO: Navigate to full history screen
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('History screen coming soon!'),
                              backgroundColor: AppColors.primaryPurple,
                            ),
                          );
                        },
                        child: const Text(
                          'View History →',
                          style: TextStyle(color: AppColors.primaryPurple),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Recents list (sample data)
                  _buildRecentItem(
                    'google.com',
                    'URL scan',
                    '2m ago',
                    'threat', // high risk
                  ),
                  _buildRecentItem(
                    'linkbitly.com',
                    'Camera scan',
                    '5d ago',
                    'warning', // medium risk
                  ),
                  _buildRecentItem(
                    'telegramlogin.com',
                    'URL scan',
                    '5d ago',
                    'safe',
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.cardBackground,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryPurple,
        unselectedItemColor: AppColors.secondaryText,
        currentIndex: 1,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.help_outline),
            label: 'Help',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        onTap: (index) {
          // TODO: Handle navigation
          switch (index) {
            case 0: // Scan
              // Already have scan section, can optionally scroll to it
              // For now, do nothing.
              break;
            case 1: // Home
              // Already on home, do nothing
              break;
            case 2: // Help
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpScreen()),
              );
              break;
            case 3: // Analytics
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SecurityInsightsScreen(),
                ),
              );
              break;
            case 4: // Settings
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ScanSettingsScreen(),
                ),
              );
              break;
          }
        },
      ),
    );
  }

  // Stats card with icon
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
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
            Icon(icon, color: AppColors.primaryPurple, size: 24),
            const SizedBox(height: 8),
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

  // Scan button
  Widget _buildScanButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.premiumGradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
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
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        child: _isScanning
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Scan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  // Recent item widget
  Widget _buildRecentItem(
    String url,
    String scanType,
    String time,
    String risk,
  ) {
    final icon = scanType.contains('Camera') ? Icons.camera_alt : Icons.link;
    Color riskColor;
    String riskLabel;
    IconData riskIcon;
    switch (risk) {
      case 'threat':
        riskColor = AppColors.highRisk;
        riskLabel = 'Threat';
        riskIcon = Icons.warning;
        break;
      case 'warning':
        riskColor = AppColors.mediumRisk;
        riskLabel = 'Warning';
        riskIcon = Icons.warning_amber;
        break;
      default:
        riskColor = AppColors.safe;
        riskLabel = 'Safe';
        riskIcon = Icons.check_circle;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primaryPurple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  url,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      scanType,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    Text(
                      ' • ',
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: riskColor.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(riskIcon, color: riskColor, size: 14),
                const SizedBox(width: 4),
                Text(
                  riskLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: riskColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
