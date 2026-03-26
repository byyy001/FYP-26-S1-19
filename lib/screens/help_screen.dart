import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// ============================================================================
// Color Palette
// ============================================================================
class _Colors {
  static const Color mainBackground = Color(0xFF151515);
  static const Color cardBackground = Color(0xFF1A1F2E);
  static const Color primaryText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFFB3B8C5);
  static const Color primaryPurple = Color(0xFF8B5CF6);
}

// ============================================================================
// Help Screen
// ============================================================================
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Colors.mainBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Help & Support',
          style: TextStyle(color: _Colors.primaryText),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _Colors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= HOW TO =================
            const Text(
              'How to Use LinkSentry',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _Colors.primaryText,
              ),
            ),
            const SizedBox(height: 16),
            _buildHowToItem(
              icon: Icons.qr_code_scanner,
              title: 'Scan a Link',
              description:
                  'Tap the Scan button, paste a URL, or use the camera to scan a QR code.',
            ),
            _buildHowToItem(
              icon: Icons.history,
              title: 'View Scan History',
              description:
                  'Go to History to see all your past scans and their results.',
            ),
            _buildHowToItem(
              icon: Icons.settings,
              title: 'Adjust Settings',
              description:
                  'Customize threat detection sensitivity, ad analysis, and more in Settings.',
            ),
            _buildHowToItem(
              icon: Icons.shield,
              title: 'Understand Results',
              description:
                  'Each scan shows a risk score, threat type (MALICIOUS/WARNING/SAFE), and detailed analysis.',
            ),

            const SizedBox(height: 24),

            // ================= FAQ =================
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _Colors.primaryText,
              ),
            ),
            const SizedBox(height: 16),

            _buildFaqTile(
              context: context,
              question: 'What does the risk score mean?',
              answer:
                  'The risk score (0-100%) indicates the likelihood that a URL is malicious. Higher scores mean higher risk.',
            ),
            _buildFaqTile(
              context: context,
              question: 'How accurate is the detection?',
              answer:
                  'LinkSentry uses a hybrid 5-layer engine combining static rules, heuristics, and machine learning (logistic regression + decision tree) trained on thousands of URLs.',
            ),
            _buildFaqTile(
              context: context,
              question: 'Can I scan links from my camera?',
              answer:
                  'Yes! Use the camera icon on the Scan screen to scan QR codes containing URLs.',
            ),
            _buildFaqTile(
              context: context,
              question: 'Is my scan history stored?',
              answer:
                  'If you are logged in, your scan history is saved in your account. You can delete scans anytime.',
            ),
            _buildFaqTile(
              context: context,
              question: 'What should I do if I find a malicious link?',
              answer:
                  'Do not visit it. Report it using the "Report False Positive" option.',
            ),

            const SizedBox(height: 24),

            // ================= CONTACT =================
            const Text(
              'Contact Support',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _Colors.primaryText,
              ),
            ),
            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _Colors.cardBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Email us at:',
                    style: TextStyle(color: _Colors.secondaryText),
                  ),
                  const SizedBox(height: 8),

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
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'support@linksentry.com',
                      style: TextStyle(
                        color: _Colors.primaryPurple,
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Response time: within 24 hours.',
                    style: TextStyle(color: _Colors.secondaryText),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ================= HOW TO ITEM =================
  Widget _buildHowToItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _Colors.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _Colors.primaryPurple, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _Colors.primaryText,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: _Colors.secondaryText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= FAQ TILE (FIXED) =================
  Widget _buildFaqTile({
    required BuildContext context,
    required String question,
    required String answer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _Colors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          unselectedWidgetColor: _Colors.secondaryText,
        ),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            question,
            style: const TextStyle(
              color: _Colors.primaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                answer,
                style:
                    const TextStyle(color: _Colors.secondaryText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}