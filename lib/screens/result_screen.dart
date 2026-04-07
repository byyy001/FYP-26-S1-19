import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum ScanMode {
  defaultMode,
  advanced,
}

class ResultScreen extends StatefulWidget {
  final bool isRegistered;
  final ScanMode scanMode;

  final String verdict; // Safe / Suspicious / Unsafe
  final String url;
  final String explanation;
  final int score;
  final List<String> reasons;
  final List<String> recommendedActions;

  const ResultScreen({
    super.key,
    required this.isRegistered,
    required this.scanMode,
    required this.verdict,
    required this.url,
    required this.explanation,
    required this.score,
    required this.reasons,
    required this.recommendedActions,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _showThreatBreakdown = false;
  bool _showBlacklistChecks = false;
  bool _showScriptAnalysis = false;
  bool _showAdAnalysis = false;

  Color get _verdictColor {
    final v = widget.verdict.toLowerCase();

    if (v == 'safe') {
      return const Color(0xFF22C55E);
    } else if (v == 'suspicious') {
      return const Color(0xFFF59E0B);
    } else {
      return const Color(0xFFEF4444);
    }
  }

  String get _simpleVerdictText {
    final v = widget.verdict.toLowerCase();

    if (v == 'safe') {
      return 'Safe';
    } else if (v == 'suspicious') {
      return 'Use Caution';
    } else {
      return 'Unsafe';
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
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.primaryText,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Scan Results',
          style: TextStyle(
            color: AppColors.primaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopCard(isSmall),
              const SizedBox(height: 24),
              if (!widget.isRegistered) ...[
                _buildUnregisteredSection(isSmall),
              ] else if (widget.scanMode == ScanMode.defaultMode) ...[
                _buildRegisteredDefaultSection(isSmall),
              ] else ...[
                _buildRegisteredAdvancedSection(isSmall),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopCard(bool isSmall) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _verdictColor.withAlpha(120),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _verdictColor.withAlpha(35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.isRegistered ? widget.verdict : _simpleVerdictText,
                  style: TextStyle(
                    fontSize: isSmall ? 24 : 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
              if (widget.isRegistered)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.premiumGradient,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.score}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.explanation,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 220,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.mainBackground,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.divider),
              ),
              child: Text(
                widget.url,
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Scanned just now',
              style: TextStyle(
                color: AppColors.disabledText,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnregisteredSection(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What this means',
          style: TextStyle(
            fontSize: isSmall ? 17 : 19,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 10),
        _buildInfoCard(
          widget.verdict.toLowerCase() == 'safe'
              ? 'This link looks safe to open.'
              : 'This link may not be safe. Avoid opening it unless you trust the source.',
        ),
        const SizedBox(height: 16),
        Text(
          'What you should do',
          style: TextStyle(
            fontSize: isSmall ? 17 : 19,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 10),
        _buildInfoCard(
          widget.verdict.toLowerCase() == 'safe'
              ? 'You may continue, but still stay alert.'
              : 'Do not enter personal information and avoid clicking further.',
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Go Back',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Sign up for more detailed scan results',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisteredDefaultSection(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What we found',
          style: TextStyle(
            fontSize: isSmall ? 17 : 19,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 10),
        ...widget.reasons.take(3).map(
          (reason) => _buildListCard(reason),
        ),
        const SizedBox(height: 14),
        Text(
          'Recommended Actions',
          style: TextStyle(
            fontSize: isSmall ? 17 : 19,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 10),
        ...widget.recommendedActions.take(3).map(
          (action) => _buildListCard(action),
        ),
        const SizedBox(height: 14),
        Text(
          'Safety Tips',
          style: TextStyle(
            fontSize: isSmall ? 17 : 19,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 10),
        _buildInfoCard(
          widget.verdict.toLowerCase() == 'safe'
              ? 'No major issues found. Continue checking links carefully.'
              : 'Check the sender, avoid shortened links, and confirm the website before entering any information.',
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 160,
          height: 46,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Back',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisteredAdvancedSection(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Threat Summary',
          style: TextStyle(
            fontSize: isSmall ? 17 : 19,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 10),
        _buildInfoCard(
          'Confidence score: ${widget.score}%\n'
          'This result includes deeper scan analysis for advanced users.',
        ),
        const SizedBox(height: 14),
        Text(
          'Reasons',
          style: TextStyle(
            fontSize: isSmall ? 17 : 19,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 10),
        ...widget.reasons.map((reason) => _buildListCard(reason)),
        const SizedBox(height: 14),
        Text(
          'Recommended Actions',
          style: TextStyle(
            fontSize: isSmall ? 17 : 19,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 10),
        ...widget.recommendedActions.map((action) => _buildListCard(action)),
        const SizedBox(height: 14),
        _buildExpandableSection(
          title: 'ML Breakdown',
          isExpanded: _showThreatBreakdown,
          onTap: () {
            setState(() {
              _showThreatBreakdown = !_showThreatBreakdown;
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '• Logistic Regression: suspicious',
                style: TextStyle(color: AppColors.primaryText),
              ),
              SizedBox(height: 8),
              Text(
                '• Decision Tree: suspicious',
                style: TextStyle(color: AppColors.primaryText),
              ),
              SizedBox(height: 8),
              Text(
                '• Ensemble score contributed to final result',
                style: TextStyle(color: AppColors.primaryText),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildExpandableSection(
          title: 'Blacklist Checks',
          isExpanded: _showBlacklistChecks,
          onTap: () {
            setState(() {
              _showBlacklistChecks = !_showBlacklistChecks;
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '• Google Safe Browsing: no direct hit',
                style: TextStyle(color: AppColors.primaryText),
              ),
              SizedBox(height: 8),
              Text(
                '• CSA / SPF lists: no direct hit',
                style: TextStyle(color: AppColors.primaryText),
              ),
              SizedBox(height: 8),
              Text(
                '• Reputation signals still triggered warning',
                style: TextStyle(color: AppColors.primaryText),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildExpandableSection(
          title: 'Script Behaviour',
          isExpanded: _showScriptAnalysis,
          onTap: () {
            setState(() {
              _showScriptAnalysis = !_showScriptAnalysis;
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '• Script behaviour appears unusual',
                style: TextStyle(color: AppColors.primaryText),
              ),
              SizedBox(height: 8),
              Text(
                '• Redirect pattern may require closer review',
                style: TextStyle(color: AppColors.primaryText),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildExpandableSection(
          title: 'Ad / Tracker Analysis',
          isExpanded: _showAdAnalysis,
          onTap: () {
            setState(() {
              _showAdAnalysis = !_showAdAnalysis;
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '• Ad intensity: medium',
                style: TextStyle(color: AppColors.primaryText),
              ),
              SizedBox(height: 8),
              Text(
                '• Tracking behaviour detected',
                style: TextStyle(color: AppColors.primaryText),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: export later
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.primaryPurple.withAlpha(180),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(
                    Icons.download_outlined,
                    color: AppColors.primaryText,
                  ),
                  label: const Text(
                    'Export',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primaryText,
          fontSize: 14,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _buildListCard(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primaryText,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.primaryText,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: child,
            ),
        ],
      ),
    );
  }
}