import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
          'Privacy Policy',
          style: TextStyle(color: AppColors.primaryText),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Last Updated: January 17, 2025',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'We believe that every user has the right to a safe experience while interacting with URLs. We also strongly believe that you have the right to privacy and control over your information. This is our fundamental belief which has shaped our Privacy Policy.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              _buildSection(
                '1. Information We Collect',
                'We collect limited information to provide and improve our service:\n'
                '• URLs you submit for scanning (temporarily processed, not stored permanently)\n'
                '• Device information (model, OS version) for analytics and troubleshooting\n'
                '• Usage data (features used, crash reports) to enhance user experience\n'
                '• If you create an account, we store your email address and authentication data securely.',
              ),
              _buildSection(
                '2. How We Use Your Information',
                '• To provide URL scanning and risk analysis\n'
                '• To improve app functionality and performance\n'
                '• To communicate important updates or security alerts\n'
                '• To ensure compliance with legal obligations',
              ),
              _buildSection(
                '3. Data Sharing',
                'We do not sell or rent your personal information. We may share anonymized, aggregated data with partners for research. We may disclose information if required by law.',
              ),
              _buildSection(
                '4. Data Security',
                'We implement industry-standard security measures to protect your data. However, no method of transmission over the internet is 100% secure.',
              ),
              _buildSection(
                '5. Your Rights',
                'You may request access, correction, or deletion of your personal data by contacting us. You can opt out of non-essential data collection through your device settings.',
              ),
              _buildSection(
                '6. Children\'s Privacy',
                'LinkSentry is not intended for children under 13. We do not knowingly collect data from children.',
              ),
              _buildSection(
                '7. Changes to This Policy',
                'We may update this policy from time to time. We will notify you of significant changes through the app or by email.',
              ),
              _buildSection(
                '8. Contact Us',
                'If you have questions or concerns, please contact us at:\nlinksentry@urlscanning.com',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.secondaryText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}