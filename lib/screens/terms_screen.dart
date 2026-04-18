import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
          'Terms & Conditions',
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LinkSentry Software License Agreement',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'PLEASE READ THESE TERMS CAREFULLY BEFORE USING THE APP',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryText,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _buildSection(
                '1. Acceptance of Terms',
                'By downloading, installing, or using LinkSentry, you agree to be bound by these Terms and Conditions. If you do not agree, do not use the app.',
              ),
              _buildSection(
                '2. Service Description',
                'LinkSentry is a URL scanning tool that uses a 5‑layer hybrid engine (static rules, machine learning, behaviour analysis, AI heuristics, and external threat intelligence) to provide risk scores and threat classifications. Results are for informational purposes only and do not guarantee absolute safety.',
              ),
              _buildSection(
                '3. User Responsibilities',
                'You are solely responsible for your use of the app and any actions taken based on scan results. LinkSentry is not liable for any loss, damage, or harm arising from your reliance on the service.',
              ),
              _buildSection(
                '4. Data Collection & Privacy',
                'We collect scan history (URLs, verdicts, timestamps) and store it in your personal Firebase account. We may also use external security APIs (e.g., VirusTotal, OpenPhish) when enabled. No personal data is sold or shared beyond what is necessary to provide the service. See our Privacy Policy for full details.',
              ),
              _buildSection(
                '5. Free vs Premium Features',
                'Free users receive basic threat detection from external sources. Premium users access the full 5‑layer engine, including machine learning models, behaviour analysis, AI scoring, and detailed technical reports. Premium status is tied to your Firebase account and may be revoked if terms are violated.',
              ),
              _buildSection(
                '6. External API Usage',
                'With your consent, LinkSentry queries third‑party security services (VirusTotal, IPQualityScore, Google Safe Browsing, WHOIS, etc.). These services have their own terms, and we are not responsible for their data handling.',
              ),
              _buildSection(
                '7. Intellectual Property',
                'The app, its source code, design, and content are owned by LinkSentry and protected by copyright laws. You may not reverse‑engineer, copy, or redistribute the software without permission.',
              ),
              _buildSection(
                '8. Termination',
                'We may suspend or terminate your access if you violate these terms or misuse the service. You may delete your account and all associated data at any time.',
              ),
              _buildSection(
                '9. Changes to Terms',
                'We reserve the right to update these terms. Continued use after changes constitutes acceptance. Material changes will be notified via the app.',
              ),
              _buildSection(
                '10. Contact Information',
                'For questions, concerns, or to report violations, contact us at:\n\nsupport@linksentry.com',
              ),
              const SizedBox(height: 24),
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

  Widget _buildSection(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
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