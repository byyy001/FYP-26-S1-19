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

  // Factory constructor from engine result – avoids redirecting constructor issues
  factory ResultScreen.fromEngineResult({
    required Map<String, dynamic> engineResult,
    required ScanSettings settings,
  }) {
    final String verdict = _mapVerdict(engineResult['severity'] ?? 'SAFE');
    final int score = (double.tryParse(engineResult['risk_score'] ?? '0') ?? 0).toInt();
    final List<String> reasons = List<String>.from(engineResult['detected_threats'] ?? []);
    final List<String> actions = List<String>.from(engineResult['actions'] ?? []);

    return ResultScreen(
      isRegistered: settings.isPremium,
      scanMode: settings.userLevel == 'advanced' ? ScanMode.advanced : ScanMode.defaultMode,
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

  Color get _verdictColor {
    final v = widget.verdict.toLowerCase();
    if (v == 'safe') return const Color(0xFF22C55E);
    if (v == 'suspicious') return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String get _simpleVerdictText {
    final v = widget.verdict.toLowerCase();
    if (v == 'safe') return 'Safe';
    if (v == 'suspicious') return 'Use Caution';
    return 'Unsafe';
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
        title: const Text('Scan Results', style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w600)),
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
        border: Border.all(color: _verdictColor.withAlpha(120), width: 1),
        boxShadow: [BoxShadow(color: _verdictColor.withAlpha(35), blurRadius: 14, offset: const Offset(0, 4))],
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
                  style: TextStyle(fontSize: isSmall ? 24 : 28, fontWeight: FontWeight.bold, color: AppColors.primaryText),
                ),
              ),
              if (widget.isRegistered)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: AppColors.premiumGradient),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${widget.score}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(widget.explanation, style: const TextStyle(color: AppColors.secondaryText, fontSize: 14)),
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 220,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.mainBackground,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.divider),
              ),
              child: Text(widget.url, style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w500), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
            ),
          ),
          const SizedBox(height: 16),
          const Align(alignment: Alignment.centerRight, child: Text('Scanned just now', style: TextStyle(color: AppColors.disabledText, fontSize: 11))),
        ],
      ),
    );
  }

  Widget _buildUnregisteredSection(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What this means', style: TextStyle(fontSize: isSmall ? 17 : 19, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
        const SizedBox(height: 10),
        _buildInfoCard(widget.verdict.toLowerCase() == 'safe' ? 'This link looks safe to open.' : 'This link may not be safe. Avoid opening it unless you trust the source.'),
        const SizedBox(height: 16),
        Text('What you should do', style: TextStyle(fontSize: isSmall ? 17 : 19, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
        const SizedBox(height: 10),
        _buildInfoCard(widget.verdict.toLowerCase() == 'safe' ? 'You may continue, but still stay alert.' : 'Do not enter personal information and avoid clicking further.'),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Go Back', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: Text('Sign up for more detailed scan results', style: TextStyle(color: AppColors.secondaryText, fontSize: 13))),
      ],
    );
  }

  Widget _buildRegisteredDefaultSection(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What we found', style: TextStyle(fontSize: isSmall ? 17 : 19, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
        const SizedBox(height: 10),
        ...widget.reasons.take(3).map((reason) => _buildListCard(reason)),
        const SizedBox(height: 14),
        Text('Recommended Actions', style: TextStyle(fontSize: isSmall ? 17 : 19, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
        const SizedBox(height: 10),
        ...widget.recommendedActions.take(3).map((action) => _buildListCard(action)),
        const SizedBox(height: 14),
        Text('Safety Tips', style: TextStyle(fontSize: isSmall ? 17 : 19, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
        const SizedBox(height: 10),
        _buildInfoCard(widget.verdict.toLowerCase() == 'safe' ? 'No major issues found. Continue checking links carefully.' : 'Check the sender, avoid shortened links, and confirm the website before entering any information.'),
        const SizedBox(height: 20),
        SizedBox(
          width: 160,
          height: 46,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisteredAdvancedSection(bool isSmall) {
    final engine = widget.engineResult;
    final isEngineResult = engine != null;

    final externalSources = isEngineResult ? List<String>.from(engine['external_sources'] ?? []) : <String>[];
    final externalScore = isEngineResult ? (engine['external_score'] as num?)?.toDouble() ?? 0.0 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Threat Summary', style: TextStyle(fontSize: isSmall ? 17 : 19, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
        const SizedBox(height: 10),
        _buildInfoCard(
          isEngineResult
              ? 'Risk Score: ${widget.score}%\nThreat Type: ${engine['threat_type']}\nML Confidence: ${engine['ml_confidence']}\nExternal Score: ${externalScore.toStringAsFixed(2)}\nExternal Sources: ${externalSources.isNotEmpty ? externalSources.join(', ') : 'None'}'
              : 'Confidence score: ${widget.score}%\nThis result includes deeper scan analysis for advanced users.',
        ),
        const SizedBox(height: 14),
        Text('Reasons', style: TextStyle(fontSize: isSmall ? 17 : 19, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
        const SizedBox(height: 10),
        ...widget.reasons.map((reason) => _buildListCard(reason)),
        const SizedBox(height: 14),
        Text('Recommended Actions', style: TextStyle(fontSize: isSmall ? 17 : 19, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
        const SizedBox(height: 10),
        ...widget.recommendedActions.map((action) => _buildListCard(action)),
        const SizedBox(height: 14),
        if (_safetyTips.isNotEmpty) ...[
          Text('Safety Tips', style: TextStyle(fontSize: isSmall ? 17 : 19, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
          const SizedBox(height: 10),
          ..._safetyTips.map((tip) => _buildListCard(tip)),
          const SizedBox(height: 14),
        ],

        if (isEngineResult) ...[
          _buildExpandableSection(
            title: 'Static Rules Fired',
            isExpanded: _showStaticRules,
            onTap: () => setState(() => _showStaticRules = !_showStaticRules),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: (engine['detailed_detected_threats'] as List? ?? [])
                  .map<Widget>((threat) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('• [${threat['severity']?.toString().toUpperCase()}] ${threat['description']}', style: const TextStyle(color: AppColors.primaryText)),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          _buildExpandableSection(
            title: 'Machine Learning Probabilities',
            isExpanded: _showMLDetails,
            onTap: () => setState(() => _showMLDetails = !_showMLDetails),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (engine['individual_model_probabilities'] != null)
                  ...(engine['individual_model_probabilities'] as Map).entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• ${entry.key}: ${_formatProbList(entry.value)}', style: const TextStyle(color: AppColors.primaryText)),
                      )),
                if (engine['ensemble_probabilities'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Ensemble: ${_formatProbList(engine['ensemble_probabilities'])}', style: const TextStyle(color: AppColors.primaryText)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildExpandableSection(
            title: 'External Threat Intelligence',
            isExpanded: _showExternalDetails,
            onTap: () => setState(() => _showExternalDetails = !_showExternalDetails),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (externalSources.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Sources: ${externalSources.join(', ')}', style: const TextStyle(color: AppColors.primaryText)),
                  ),
                if (engine['external_details'] != null)
                  ...(engine['external_details'] as Map).entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• ${entry.key}: ${entry.value}', style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                      )),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        _buildExpandableSection(
          title: 'ML Breakdown',
          isExpanded: _showThreatBreakdown,
          onTap: () => setState(() => _showThreatBreakdown = !_showThreatBreakdown),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('• Logistic Regression: suspicious', style: TextStyle(color: AppColors.primaryText)),
              SizedBox(height: 8),
              Text('• Decision Tree: suspicious', style: TextStyle(color: AppColors.primaryText)),
              SizedBox(height: 8),
              Text('• Ensemble score contributed to final result', style: TextStyle(color: AppColors.primaryText)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildExpandableSection(
          title: 'Blacklist Checks',
          isExpanded: _showBlacklistChecks,
          onTap: () => setState(() => _showBlacklistChecks = !_showBlacklistChecks),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('• Google Safe Browsing: no direct hit', style: TextStyle(color: AppColors.primaryText)),
              SizedBox(height: 8),
              Text('• CSA / SPF lists: no direct hit', style: TextStyle(color: AppColors.primaryText)),
              SizedBox(height: 8),
              Text('• Reputation signals still triggered warning', style: TextStyle(color: AppColors.primaryText)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildExpandableSection(
          title: 'Script Behaviour',
          isExpanded: _showScriptAnalysis,
          onTap: () => setState(() => _showScriptAnalysis = !_showScriptAnalysis),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('• Script behaviour appears unusual', style: TextStyle(color: AppColors.primaryText)),
              SizedBox(height: 8),
              Text('• Redirect pattern may require closer review', style: TextStyle(color: AppColors.primaryText)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildExpandableSection(
          title: 'Ad / Tracker Analysis',
          isExpanded: _showAdAnalysis,
          onTap: () => setState(() => _showAdAnalysis = !_showAdAnalysis),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('• Ad intensity: medium', style: TextStyle(color: AppColors.primaryText)),
              SizedBox(height: 8),
              Text('• Tracking behaviour detected', style: TextStyle(color: AppColors.primaryText)),
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
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.primaryPurple.withAlpha(180)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  icon: const Icon(Icons.download_outlined, color: AppColors.primaryText),
                  label: const Text('Export', style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatProbList(dynamic probs) {
    if (probs is List) return probs.map((p) => (p as double).toStringAsFixed(3)).join(', ');
    return probs.toString();
  }

  Widget _buildInfoCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: const TextStyle(color: AppColors.primaryText, fontSize: 14, height: 1.45)),
    );
  }

  Widget _buildListCard(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: const TextStyle(color: AppColors.primaryText, fontSize: 14)),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(color: AppColors.primaryText, fontSize: 14, fontWeight: FontWeight.w600))),
                  Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.primaryText),
                ],
              ),
            ),
          ),
          if (isExpanded) Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), child: child),
        ],
      ),
    );
  }
}