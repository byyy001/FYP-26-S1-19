import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
          'Terms & Conditions',
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
                'LinkSentry Software License Agreement',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryPurple,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'PLEASE READ THE FOLLOWING TERMS AND CONDITIONS CAREFULLY BEFORE DOWNLOADING, INSTALLING OR USING THE LINKSENTRY MOBILE APPLICATION SOFTWARE',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 24),
              _buildSection(
                '1. Acceptance of Terms',
                'By accessing or using LinkSentry, you agree to be bound by these Terms and Conditions. If you do not agree, please do not use the app.',
              ),
              _buildSection(
                '2. Service Description',
                'LinkSentry is a URL scanning and risk analysis tool designed to provide security insights. The results provided are for informational purposes only and do not guarantee that a link is completely safe or malicious.',
              ),
              _buildSection(
                '3. User Responsibility',
                'You are held responsible for how you use the App and for any actions taken based on scan results provided. LinkSentry will not be liable for any loss, damage, or harm arising from the use of the App.',
              ),
              _buildSection(
                '4. Data Collection',
                'LinkSentry may collect and process limited data to provide scanning features and improve performance. For more details refer to our Privacy Policy.',
              ),
              _buildSection(
                '5. Updates',
                'We reserve the rights to update these terms. Continued use of the app after changes constitutes acceptance of the new terms.',
              ),
              _buildSection(
                '6. Contact',
                'For questions, please contact us at linksentry@urlscanning.com',
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Last Updated: January 17, 2025',
                  style: TextStyle(color: AppColors.disabledText, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
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
          const SizedBox(height: 4),
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