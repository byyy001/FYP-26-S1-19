import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../threat_engine/scan_settings.dart';

enum ScanMode {
  defaultMode,
  advanced,
}

class ResultScreen extends StatefulWidget {
  // Legacy fields
  final bool isRegistered;
  final ScanMode scanMode;
  final String verdict;
  final String url;
  final String explanation;
  final int score;
  final List<String> reasons;
  final List<String> recommendedActions;

  // New fields
  final Map<String, dynamic>? engineResult;
  final ScanSettings? settings;

  // Legacy constructor
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
    this.engineResult,
    this.settings,
  });

  // Factory constructor from engine result
  factory ResultScreen.fromEngineResult({
    required Map<String, dynamic> engineResult,
    required ScanSettings settings,
  }) {
    final String verdict = _mapVerdict(engineResult['severity'] ?? 'SAFE');
    final int score =
        (double.tryParse(engineResult['risk_score'] ?? '0') ?? 0).toInt();
    final List<String> reasons =
        List<String>.from(engineResult['detected_threats'] ?? []);
    final List<String> actions =
        List<String>.from(engineResult['actions'] ?? []);

    return ResultScreen(
      isRegistered: true,
      scanMode: ScanMode.advanced,
      verdict: verdict,
      url: engineResult['url'] ?? '',
      explanation: engineResult['explanation'] ?? '',
      score: score,
      reasons: reasons,
      recommendedActions: actions,
      engineResult: engineResult,
      settings: settings,
    );
  }

  static String _mapVerdict(String severity) {
    if (severity.contains('HIGH')) return 'Unsafe';
    if (severity.contains('MEDIUM')) return 'Suspicious';
    if (severity.contains('LOW')) return 'Suspicious';
    return 'Safe';
  }

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _showThreatBreakdown = false;
  bool _showBlacklistChecks = false;
  bool _showScriptAnalysis = false;
  bool _showAdAnalysis = false;

  bool _showStaticRules = false;
  bool _showMLDetails = false;
  bool _showExternalDetails = false;

  List<String> get _safetyTips {
    if (widget.engineResult != null) {
      return List<String>.from(widget.engineResult!['safety_tips'] ?? []);
    }
    return [];
  }

  List<String> get _externalSources {
    if (widget.engineResult != null) {
      return List<String>.from(widget.engineResult!['external_sources'] ?? []);
    }
    return [];
  }

  double get _riskScore => widget.score.toDouble();

  String get _riskLevelText {
    if (_riskScore >= 76) return 'High Risk';
    if (_riskScore >= 51) return 'Medium Risk';
    if (_riskScore >= 26) return 'Low Risk';
    return 'Safe';
  }

  Color get _riskColor {
    if (_riskScore >= 76) return AppColors.highRisk;
    if (_riskScore >= 51) return AppColors.mediumRisk;
    if (_riskScore >= 26) return AppColors.mediumRisk;
    return AppColors.safe;
  }

  String _getSimpleVerdict() {
    if (_riskScore >= 76) return 'Unsafe';
    if (_riskScore >= 51) return 'Suspicious';
    if (_riskScore >= 26) return 'Low Risk';
    return 'Safe';
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
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => Navigator.pop(context),
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
    LinearGradient cardGradient;
    if (_riskScore >= 76) {
      cardGradient = LinearGradient(
        colors: [
          AppColors.highRisk.withOpacity(0.15),
          AppColors.cardBackground,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (_riskScore >= 51) {
      cardGradient = LinearGradient(
        colors: [
          AppColors.mediumRisk.withOpacity(0.15),
          AppColors.cardBackground,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (_riskScore >= 26) {
      cardGradient = LinearGradient(
        colors: [
          AppColors.mediumRisk.withOpacity(0.1),
          AppColors.cardBackground,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      cardGradient = LinearGradient(
        colors: [
          AppColors.safe.withOpacity(0.1),
          AppColors.cardBackground,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _riskColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: _riskColor.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isRegistered ? widget.verdict : _getSimpleVerdict(),
                      style: TextStyle(
                        fontSize: isSmall ? 24 : 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _riskLevelText,
                      style: TextStyle(
                        fontSize: 14,
                        color: _riskColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _riskColor,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: _riskColor.withOpacity(0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  '${widget.score}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Risk Score',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${widget.score}%',
                    style: TextStyle(
                      color: _riskColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _riskScore / 100,
                  backgroundColor: AppColors.divider,
                  color: _riskColor,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Safe',
                    style: TextStyle(color: AppColors.safe, fontSize: 11),
                  ),
                  Text(
                    'Low',
                    style: TextStyle(
                      color: AppColors.mediumRisk,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    'Medium',
                    style: TextStyle(
                      color: AppColors.mediumRisk,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    'High',
                    style: TextStyle(
                      color: AppColors.highRisk,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          const SizedBox(height: 12),
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
    String externalMsg = '';
    if (_externalSources.isNotEmpty) {
      final sources = _externalSources.map((s) {
        if (s == 'VirusTotal') return 'VirusTotal';
        if (s == 'OpenPhish') return 'OpenPhish';
        if (s == 'IPQualityScore') return 'IPQualityScore';
        return s;
      }).join(', ');
      externalMsg = '✓ Flagged by $sources';
    }

    String whatThisMeans;
    String whatToDo;
    if (_riskScore >= 76) {
      whatThisMeans =
          'This link is highly likely to be malicious. Do not proceed.';
      whatToDo =
          'Close the page immediately. Do not enter any information. Report the link if possible.';
    } else if (_riskScore >= 51) {
      whatThisMeans =
          'This link shows clear signs of suspicious activity. Proceed with extreme caution.';
      whatToDo =
          'Avoid entering personal details. Consider verifying the link with another scanner.';
    } else if (_riskScore >= 26) {
      whatThisMeans =
          'This link has a low but non-zero risk. It may be safe, but some indicators are unusual.';
      whatToDo =
          'You can proceed, but avoid entering sensitive information. Double-check the URL.';
    } else {
      whatThisMeans =
          'No security issues were detected. This link appears safe.';
      whatToDo =
          'You may proceed, but always stay cautious. Keep your browser and antivirus updated.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (externalMsg.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _riskColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: _riskColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    externalMsg,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          'What this means',
          style: TextStyle(
            fontSize: isSmall ? 17 : 19,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 10),
        _buildInfoCard(whatThisMeans),
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
        _buildInfoCard(whatToDo),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
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
        ...widget.reasons.take(3).map((reason) => _buildListCard(reason)),
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
        ...widget.recommendedActions
            .take(3)
            .map((action) => _buildListCard(action)),
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
            onPressed: () => Navigator.pop(context),
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
    final engine = widget.engineResult;
    final isEngineResult = engine != null;

    final externalSources = isEngineResult
    ? List<String>.from(engine['external_sources'] ?? [])
    : <String>[];

    final dynamic externalScoreRaw =
        isEngineResult ? engine['external_score'] : null;

    final double externalScore = externalScoreRaw is num
        ? externalScoreRaw.toDouble()
        : double.tryParse(externalScoreRaw?.toString() ?? '0') ?? 0.0;

    final String mlConfidence =
        isEngineResult ? (engine['ml_confidence']?.toString() ?? 'N/A') : 'N/A';
    final String threatType =
        isEngineResult ? (engine['threat_type']?.toString() ?? 'Unknown') : 'Unknown';

    final bool showThreatSummaryOpen = _riskScore >= 51;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _riskColor.withOpacity(0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Advanced Analysis',
                style: TextStyle(
                  fontSize: isSmall ? 17 : 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Detailed technical breakdown for analyst-level review.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildSummaryChip(
                    icon: Icons.warning_amber_rounded,
                    label: 'Threat Type',
                    value: threatType,
                  ),
                  _buildSummaryChip(
                    icon: Icons.psychology_alt_outlined,
                    label: 'ML Confidence',
                    value: mlConfidence,
                  ),
                  _buildSummaryChip(
                    icon: Icons.public_outlined,
                    label: 'External Sources',
                    value: externalSources.isNotEmpty
                        ? externalSources.join(', ')
                        : 'None',
                  ),
                  _buildSummaryChip(
                    icon: Icons.analytics_outlined,
                    label: 'External Score',
                    value: externalScore.toStringAsFixed(2),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        Text(
            'Analyst Summary',
            style: TextStyle(
              fontSize: isSmall ? 17 : 19,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Verdict', widget.verdict),
                _buildDetailRow('Risk Score', '${widget.score}%'),
                _buildDetailRow('Threat Type', threatType),
                _buildDetailRow('ML Confidence', mlConfidence),
                _buildDetailRow('External Score', externalScore.toStringAsFixed(2)),
                _buildDetailRow(
                  'Sources',
                  externalSources.isNotEmpty ? externalSources.join(', ') : 'None',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

        if (widget.reasons.isNotEmpty) ...[
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
        ],

        if (widget.recommendedActions.isNotEmpty) ...[
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
        ],

        if (_safetyTips.isNotEmpty) ...[
          Text(
            'Safety Tips',
            style: TextStyle(
              fontSize: isSmall ? 17 : 19,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 10),
          ..._safetyTips.map((tip) => _buildListCard(tip)),
          const SizedBox(height: 14),
        ],

        const Divider(height: 28, color: AppColors.divider),

        Text(
          'Technical Breakdown',
          style: TextStyle(
            fontSize: isSmall ? 17 : 19,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 10),

        
        _buildExpandableSection(
          title: 'Threat Summary',
          subtitle: 'Overall scan decision and core technical indicators',
          icon: Icons.summarize_outlined,
          isExpanded: showThreatSummaryOpen,
          allowToggle: false,
          onTap: () {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Verdict', widget.verdict),
              _buildDetailRow('Risk Level', _riskLevelText),
              _buildDetailRow('Risk Score', '${widget.score}%'),
              _buildDetailRow('Threat Type', threatType),
              _buildDetailRow('ML Confidence', mlConfidence),
              _buildDetailRow(
                'External Sources',
                externalSources.isNotEmpty ? externalSources.join(', ') : 'None',
              ),
              _buildDetailRow(
                'External Score',
                externalScore.toStringAsFixed(2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (isEngineResult) ...[
          _buildExpandableSection(
            title: 'Static Rules Fired',
            subtitle: 'Triggered rule-based checks and detections',
            icon: Icons.rule_folder_outlined,
            isExpanded: _showStaticRules,
            onTap: () => setState(() => _showStaticRules = !_showStaticRules),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: (engine['detailed_detected_threats'] as List? ?? [])
                      .isNotEmpty
                  ? (engine['detailed_detected_threats'] as List)
                      .map<Widget>(
                        (threat) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            '• [${threat['severity']?.toString().toUpperCase()}] ${threat['description']}',
                            style: const TextStyle(
                              color: AppColors.primaryText,
                              height: 1.4,
                            ),
                          ),
                        ),
                      )
                      .toList()
                  : [
                      const Text(
                        'No static rule details were returned for this scan.',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          height: 1.4,
                        ),
                      ),
                    ],
            ),
          ),
          const SizedBox(height: 12),

          _buildExpandableSection(
            title: 'Machine Learning Probabilities',
            subtitle: 'Model-level probabilities and ensemble output',
            icon: Icons.psychology_alt_outlined,
            isExpanded: _showMLDetails,
            onTap: () => setState(() => _showMLDetails = !_showMLDetails),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (engine['individual_model_probabilities'] != null)
                  ...(engine['individual_model_probabilities'] as Map)
                      .entries
                      .map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '• ${entry.key}: ${_formatProbList(entry.value)}',
                            style: const TextStyle(
                              color: AppColors.primaryText,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                if (engine['ensemble_probabilities'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Ensemble: ${_formatProbList(engine['ensemble_probabilities'])}',
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        height: 1.4,
                      ),
                    ),
                  ),
                if (engine['individual_model_probabilities'] == null &&
                    engine['ensemble_probabilities'] == null)
                  const Text(
                    'No model probability breakdown was returned for this scan.',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _buildExpandableSection(
            title: 'External Threat Intelligence',
            subtitle: 'Signals from external sources and intelligence providers',
            icon: Icons.public_outlined,
            isExpanded: _showExternalDetails,
            onTap: () =>
                setState(() => _showExternalDetails = !_showExternalDetails),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Sources: ${externalSources.isNotEmpty ? externalSources.join(', ') : 'None'}',
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      height: 1.4,
                    ),
                  ),
                ),
                if (engine['external_details'] != null)
                  ...(engine['external_details'] as Map).entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '• ${entry.key}: ${entry.value}',
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                if (engine['external_details'] == null)
                  const Text(
                    'No extra external detail was returned for this scan.',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        _buildExpandableSection(
          title: 'ML Breakdown',
          subtitle: 'Simplified view of how model signals contributed',
          icon: Icons.insights_outlined,
          isExpanded: _showThreatBreakdown,
          onTap: () =>
              setState(() => _showThreatBreakdown = !_showThreatBreakdown),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '• Logistic Regression: suspicious',
                style: TextStyle(
                  color: AppColors.primaryText,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '• Decision Tree: suspicious',
                style: TextStyle(
                  color: AppColors.primaryText,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '• Ensemble score contributed to final result',
                style: TextStyle(
                  color: AppColors.primaryText,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _buildExpandableSection(
          title: 'Blacklist Checks',
          subtitle: 'List-based reputation and blacklist screening results',
          icon: Icons.gpp_maybe_outlined,
          isExpanded: _showBlacklistChecks,
          onTap: () =>
              setState(() => _showBlacklistChecks = !_showBlacklistChecks),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '• Google Safe Browsing: no direct hit',
                style: TextStyle(
                  color: AppColors.primaryText,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '• CSA / SPF lists: no direct hit',
                style: TextStyle(
                  color: AppColors.primaryText,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '• Reputation signals still triggered warning',
                style: TextStyle(
                  color: AppColors.primaryText,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _buildExpandableSection(
          title: 'Script Behaviour',
          subtitle: 'Client-side behaviour and redirect-related concerns',
          icon: Icons.code_outlined,
          isExpanded: _showScriptAnalysis,
          onTap: () =>
              setState(() => _showScriptAnalysis = !_showScriptAnalysis),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '• Script behaviour appears unusual',
                style: TextStyle(
                  color: AppColors.primaryText,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '• Redirect pattern may require closer review',
                style: TextStyle(
                  color: AppColors.primaryText,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _buildExpandableSection(
          title: 'Ad / Tracker Analysis',
          subtitle: 'Advertising and tracking-related indicators',
          icon: Icons.ads_click_outlined,
          isExpanded: _showAdAnalysis,
          onTap: () => setState(() => _showAdAnalysis = !_showAdAnalysis),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '• Ad intensity: medium',
                style: TextStyle(
                  color: AppColors.primaryText,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '• Tracking behaviour detected',
                style: TextStyle(
                  color: AppColors.primaryText,
                  height: 1.4,
                ),
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
                  onPressed: () => Navigator.pop(context),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Export coming soon'),
                        backgroundColor: AppColors.primaryPurple,
                      ),
                    );
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

  Widget _buildSummaryChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryPurple),
          const SizedBox(width: 8),
          Flexible(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatProbList(dynamic probs) {
    if (probs is List) {
      return probs.map((p) => (p as double).toStringAsFixed(3)).join(', ');
    }
    return probs.toString();
  }

  Widget _buildInfoCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
    String? subtitle,
    IconData? icon,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget child,
    bool allowToggle = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: allowToggle ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 18,
                      color: AppColors.primaryPurple,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    allowToggle
                        ? (isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down)
                        : Icons.drag_handle_rounded,
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