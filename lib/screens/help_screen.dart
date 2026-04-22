import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';
import 'about_screen.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

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
          'Help & Support',
          style: TextStyle(
            color: AppColors.primaryText,
            fontSize: isSmall ? 20 : 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= HOW TO USE =================
            _buildSectionHeader('How to Use LinkSentry', Icons.tips_and_updates),
            const SizedBox(height: 12),
            _buildHowToItem(
              icon: Icons.qr_code_scanner,
              title: 'Scan a URL or QR Code',
              description:
                  'Tap the central Scan button, paste any link, or use your camera to scan a QR code – we’ll analyse it instantly.',
            ),
            _buildHowToItem(
              icon: Icons.history,
              title: 'Review Scan History',
              description:
                  'All your past scans are saved in History. Filter by status (Safe, Suspicious, Malicious) or search for specific URLs.',
            ),
            _buildHowToItem(
              icon: Icons.settings,
              title: 'Tune Detection Settings',
              description:
                  'Premium users can adjust sensitivity, enable deep script analysis, and choose which machine learning models to use.',
            ),
            _buildHowToItem(
              icon: Icons.shield,
              title: 'Understand Results',
              description:
                  'Each scan shows a risk score (0–100%), threat type, and detailed reasons. Expand technical sections for full transparency.',
            ),
            const SizedBox(height: 24),
            const Divider(color: AppColors.divider, thickness: 0.5, height: 1),
            const SizedBox(height: 24), // was 28 → 24

            // ================= FAQ =================
            _buildSectionHeader('Frequently Asked Questions', Icons.help_outline),
            const SizedBox(height: 12),
            _buildFaqTile(
              context: context,
              question: 'How is the risk score calculated?',
              answer:
                  'The score (0–100) combines static rules, machine learning (4 models), behaviour analysis, AI heuristics, and external threat feeds. Scores ≥75 are High Risk, 50–74 Medium, 25–49 Low, <25 Safe.',
            ),
            _buildFaqTile(
              context: context,
              question: 'What’s the difference between free and premium?',
              answer:
                  'Free users get basic threat detection from external sources. Premium users unlock the full 5‑layer hybrid engine (ML, behaviour analysis, AI, deep script scanning) and detailed technical reports.',
            ),
            _buildFaqTile(
              context: context,
              question: 'Can I trust the ML models?',
              answer:
                  'Yes – we use logistic regression, decision tree, XGBoost, and LightGBM, trained on thousands of malicious and benign URLs. The ensemble approach reduces false positives.',
            ),
            _buildFaqTile(
              context: context,
              question: 'Does LinkSentry use external APIs?',
              answer:
                  'When enabled, we check VirusTotal, OpenPhish, IPQualityScore, Google Safe Browsing, and WHOIS data. You can disable external APIs in Settings for faster, offline‑only scans.',
            ),
            _buildFaqTile(
              context: context,
              question: 'Is my data private?',
              answer:
                  'We store scan history only in your personal Firebase account. No data is shared with third parties except the external security APIs you explicitly enable.',
            ),
            _buildFaqTile(
              context: context,
              question: 'What should I do with a malicious link?',
              answer:
                  'Do not visit it. Close the page, run a local antivirus scan, and report the URL using the “Report” option in the result screen.',
            ),
            _buildFaqTile(
              context: context,
              question: 'Can I re‑scan a previously checked URL?',
              answer:
                  'Yes – tap the refresh icon in the result screen’s app bar to run a fresh analysis, which may pick up newly reported threats.',
            ),
            const SizedBox(height: 24),
            const Divider(color: AppColors.divider, thickness: 0.5, height: 1),
            const SizedBox(height: 24), // was 28 → 24

            // ================= CONTACT SUPPORT =================
            _buildSectionHeader('Contact Support', Icons.contact_mail),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider.withOpacity(0.3)),
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
                    'For technical issues, feature requests, or false positive reports:',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final Uri emailUri = Uri(
                        scheme: 'mailto',
                        path: 'support@linksentry.com',
                        query: 'subject=LinkSentry Support Request',
                      );
                      if (await canLaunchUrl(emailUri)) {
                        await launchUrl(emailUri);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not launch email'),
                            backgroundColor: AppColors.highRisk,
                          ),
                        );
                      }
                    },
                    child: Text(
                      'support@linksentry.com',
                      style: TextStyle(
                        color: AppColors.primaryPurple,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Please include the scan ID or a screenshot if reporting a specific result.\nResponse time: within 24 hours.',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: AppColors.divider, thickness: 0.5, height: 1),
            const SizedBox(height: 24), // was 28 → 24

            // ================= ABOUT LINKSENTRY =================
            _buildSectionHeader('About LinkSentry', Icons.info_outline),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Learn more about the app, our team, and open source licenses.',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AboutScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.help_outline, size: 18),
                      label: const Text('Open About Screen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: AppColors.divider, thickness: 0.5, height: 1),
            const SizedBox(height: 24), // was 28 → 24

            // ================= LEGAL LINKS =================
            _buildSectionHeader('Legal', Icons.gavel),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.privacy_tip, size: 20),
                    label: const Text('Privacy Policy'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TermsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.description, size: 20),
                    label: const Text('Terms & Conditions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24), // was 20 → 24
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryPurple, size: 24),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryText,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildHowToItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12), // was 14 → 12
              border: Border.all(color: AppColors.divider.withOpacity(0.3)),
            ),
            child: Icon(icon, color: AppColors.primaryPurple, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqTile({
    required BuildContext context,
    required String question,
    required String answer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12), // was 14 → 12
        border: Border.all(color: AppColors.divider.withOpacity(0.3)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          unselectedWidgetColor: AppColors.secondaryText,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            question,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          children: [
            const Divider(
              color: AppColors.divider,
              thickness: 0.5,
              height: 1,
              indent: 16,
              endIndent: 16,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                answer,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}