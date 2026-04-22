import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmall = screenWidth < 360;

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy Policy',
          style: TextStyle(
            color: AppColors.primaryText,
            fontSize: isSmall ? 20 : 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Your Privacy Matters',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryPurple,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'We believe you have the right to privacy and control over your information.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              const Divider(color: AppColors.divider, thickness: 0.5),
              const SizedBox(height: 24),

              // Sections
              _buildSection(
                '1. Information We Collect',
                Icons.data_usage,
                [
                  'URLs you submit for scanning – stored in your personal Firebase account as scan history (URL, verdict, risk score, timestamp).',
                  'Account information – email address and authentication data (Firebase Auth).',
                  'Device information – model, OS version, app version (for analytics and crash reporting).',
                  'Usage data – features used, scan frequency, settings preferences.',
                  'External API responses – when you enable external threat intelligence, we temporarily process data from VirusTotal, OpenPhish, IPQualityScore, Google Safe Browsing, and WHOIS. No external API data is permanently stored unless required for the scan result.',
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                '2. How We Use Your Information',
                Icons.analytics,
                [
                  'To provide URL scanning and risk analysis (core functionality).',
                  'To store and display your scan history (only visible to you).',
                  'To improve app performance, fix bugs, and enhance threat detection accuracy.',
                  'To send critical security alerts or service updates (rare, only when necessary).',
                  'To comply with legal obligations and enforce our Terms of Service.',
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                '3. Data Storage & Retention',
                Icons.storage,
                [
                  'Scan history is stored in Firebase Firestore and associated with your user ID.',
                  'You can delete individual scans or your entire history from the Profile screen.',
                  'Account deletion removes all associated data permanently.',
                  'Anonymized usage data may be retained longer for research and model training.',
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                '4. External API Usage (Premium Feature)',
                Icons.api,
                [
                  'When you enable external threat intelligence in Settings, we query:',
                  '  • VirusTotal, Google Safe Browsing, OpenPhish, IPQualityScore, WHOIS.',
                  'These services receive the URL you submit and may log it according to their own privacy policies.',
                  'We do not control their data handling. You can disable external APIs at any time.',
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                '5. Data Sharing & Third Parties',
                Icons.share,
                [
                  'We do not sell or rent your personal data. Limited sharing occurs:',
                  '  • With external security APIs (only if you enable them).',
                  '  • With Firebase (Google) for authentication and database hosting.',
                  '  • With crash reporting tools (anonymized data).',
                  '  • If required by law or to protect our legal rights.',
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                '6. Data Security',
                Icons.security,
                [
                  'We use industry‑standard security (Firebase security rules, encrypted connections). However, no internet transmission is 100% secure. You are responsible for keeping your account credentials safe.',
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                '7. Your Rights & Controls',
                Icons.assignment_ind,
                [
                  'Access your scan history in the app.',
                  'Delete individual scans or entire history.',
                  'Delete your account and all associated data (Profile → Delete Account).',
                  'Disable external APIs or machine learning features in Settings.',
                  'Opt out of analytics by contacting support (limited functionality).',
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                '8. Children’s Privacy',
                Icons.child_care,
                [
                  'LinkSentry is not intended for users under 13. We do not knowingly collect data from children. If you believe a child has provided data, contact us to remove it.',
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                '9. Changes to This Policy',
                Icons.update,
                [
                  'We may update this policy. Material changes will be notified via the app or email. Continued use after changes constitutes acceptance.',
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                '10. Contact Us',
                Icons.email,
                [
                  'For privacy questions, data requests, or concerns:\n\nsupport@linksentry.com\n\nPlease allow up to 7 days for a response.',
                ],
              ),

              const SizedBox(height: 32),
              Center(
                child: Text(
                  'Last Updated: April 18, 2026',
                  style: TextStyle(color: AppColors.disabledText, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<String> bulletPoints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primaryPurple),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20, // changed from 18 to 20
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...bulletPoints.map((point) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '•',
                    style: TextStyle(
                      color: AppColors.primaryPurple,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      point,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.secondaryText,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            )),
        const Divider(color: AppColors.divider, thickness: 0.3, height: 24),
      ],
    );
  }
}