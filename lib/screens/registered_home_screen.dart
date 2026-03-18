import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class RegisteredHomeScreen extends StatelessWidget {
  // TODO: Replace with actual user name from Firebase
  final String userName = "Alice";

  const RegisteredHomeScreen({super.key});

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
          IconButton(
            icon: const Icon(Icons.person_outline, color: AppColors.primaryText),
            onPressed: () {
              // TODO: Navigate to profile screen
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
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

              // Stats cards
              Row(
                children: [
                  _buildStatCard('Total Scans', '100', AppColors.primaryText),
                  const SizedBox(width: 12),
                  _buildStatCard('Safe Links', '80', AppColors.safe),
                  const SizedBox(width: 12),
                  _buildStatCard('Threats', '20', AppColors.highRisk),
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
              // Scan input row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'example-link.com',
                        hintStyle: TextStyle(color: AppColors.disabledText),
                        filled: true,
                        fillColor: AppColors.cardBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    },
                    child: const Text(
                      'View History →',
                      style: TextStyle(color: AppColors.primaryPurple),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Recents list
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
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.cardBackground,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryPurple,
        unselectedItemColor: AppColors.secondaryText,
        currentIndex: 1, // Home selected
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.help_outline), label: 'Help'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
        onTap: (index) {
          // TODO: Handle navigation
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
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
        onPressed: () {
          // TODO: Trigger scan with threat engine
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        child: const Text(
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

  Widget _buildRecentItem(String url, String scanType, String time, String risk) {
    // Determine icon based on scan type
    IconData icon = scanType.contains('Camera') ? Icons.camera_alt : Icons.link;
    // Determine color and label based on risk
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
      case 'safe':
      default:
        riskColor = AppColors.safe;
        riskLabel = 'Safe';
        riskIcon = Icons.check_circle;
        break;
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
          // Icon for scan type
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primaryPurple, size: 20),
          ),
          const SizedBox(width: 12),
          // URL and details
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
          // Risk indicator
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