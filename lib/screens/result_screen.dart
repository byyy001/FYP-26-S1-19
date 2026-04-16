import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../constants/app_colors.dart';
import '../threat_engine/scan_settings.dart';

enum ScanMode {
  defaultMode,
  advanced,
}

class ResultScreen extends StatefulWidget {
  final bool isRegistered;
  final ScanMode scanMode;
  final String verdict;
  final String url;
  final String explanation;
  final int score;
  final List<String> reasons;
  final List<String> recommendedActions;
  final Map<String, dynamic>? engineResult;
  final ScanSettings? settings;

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
  bool _showStaticRules = false;
  bool _showMLDetails = false;
  bool _showExternalDetails = false;
  bool _showBehaviorAnalysis = false;
  bool _showModelMetrics = false;
  bool _showFusionDetails = false;

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

  // ======================== EXPORT METHODS ========================
  String _buildShareText() {
    final threatType = widget.engineResult?['threat_type'] ?? 'Unknown';
    return '''
LinkSentry Scan Report
URL: ${widget.url}
Risk Score: ${widget.score}%
Verdict: ${widget.verdict}
Threat Type: $threatType
Detected Issues: ${widget.reasons.isNotEmpty ? widget.reasons.join(', ') : 'None'}
External Sources: ${_externalSources.isNotEmpty ? _externalSources.join(', ') : 'None'}
Explanation: ${widget.explanation}
''';
  }

  Future<void> _shareResults() async {
    final text = _buildShareText();
    await Share.share(text, subject: 'LinkSentry Scan Result');
  }

  Future<void> _copyToClipboard() async {
    final text = _buildShareText();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to clipboard'), backgroundColor: AppColors.safe),
      );
    }
  }

  Future<void> _downloadPDF() async {
    try {
      final pdf = pw.Document();
      final threatType = widget.engineResult?['threat_type'] ?? 'Unknown';
      final mlConfidence = widget.engineResult?['ml_confidence'] ?? 'none';
      final externalScore = (widget.engineResult?['external_score'] as num?)?.toDouble() ?? 0.0;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Center(
              child: pw.Text(
                'LinkSentry Scan Report',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('URL: ${widget.url}'),
            pw.Text('Scan Date: ${DateTime.now().toLocal().toString()}'),
            pw.SizedBox(height: 10),
            pw.Text('Risk Score: ${widget.score}%', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Verdict: ${widget.verdict}'),
            pw.Text('Threat Type: $threatType'),
            pw.Text('ML Confidence: $mlConfidence'),
            pw.Text('External Score: ${externalScore.toStringAsFixed(2)}'),
            pw.Text('External Sources: ${_externalSources.isNotEmpty ? _externalSources.join(', ') : 'None'}'),
            pw.SizedBox(height: 10),
            pw.Text('Detected Issues:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ...widget.reasons.map((reason) => pw.Text('• $reason')),
            pw.SizedBox(height: 10),
            pw.Text('Recommended Actions:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ...widget.recommendedActions.map((action) => pw.Text('• $action')),
            if (_safetyTips.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text('Safety Tips:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ..._safetyTips.map((tip) => pw.Text('• $tip')),
            ],
            pw.SizedBox(height: 20),
            pw.Text('Explanation: ${widget.explanation}'),
          ],
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/linksentry_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], subject: 'LinkSentry Scan Report');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF generation failed: $e'), backgroundColor: AppColors.highRisk),
        );
      }
    }
  }

  // ======================== UI ========================
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
        actions: widget.isRegistered
            ? [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.primaryText),
                  onSelected: (value) async {
                    if (value == 'share') await _shareResults();
                    else if (value == 'copy') await _copyToClipboard();
                    else if (value == 'pdf') await _downloadPDF();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share), SizedBox(width: 12), Text('Share')])),
                    const PopupMenuItem(value: 'copy', child: Row(children: [Icon(Icons.copy), SizedBox(width: 12), Text('Copy to clipboard')])),
                    const PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf), SizedBox(width: 12), Text('Download PDF')])),
                  ],
                ),
              ]
            : null,
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

  // ======================== TOP CARD ========================
  Widget _buildTopCard(bool isSmall) {
    LinearGradient cardGradient;
    if (_riskScore >= 76) {
      cardGradient = LinearGradient(
        colors: [AppColors.highRisk.withOpacity(0.15), AppColors.cardBackground],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (_riskScore >= 51) {
      cardGradient = LinearGradient(
        colors: [AppColors.mediumRisk.withOpacity(0.15), AppColors.cardBackground],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (_riskScore >= 26) {
      cardGradient = LinearGradient(
        colors: [AppColors.mediumRisk.withOpacity(0.1), AppColors.cardBackground],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      cardGradient = LinearGradient(
        colors: [AppColors.safe.withOpacity(0.1), AppColors.cardBackground],
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
        boxShadow: [BoxShadow(color: _riskColor.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6))],
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _riskColor,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: _riskColor.withOpacity(0.4), blurRadius: 8)],
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
                  const Text('Risk Score', style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                  Text('${widget.score}%', style: TextStyle(color: _riskColor, fontWeight: FontWeight.bold)),
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
                  Text('Safe', style: TextStyle(color: AppColors.safe, fontSize: 11)),
                  Text('Low', style: TextStyle(color: AppColors.mediumRisk, fontSize: 11)),
                  Text('Medium', style: TextStyle(color: AppColors.mediumRisk, fontSize: 11)),
                  Text('High', style: TextStyle(color: AppColors.highRisk, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
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
              child: Text(
                widget.url,
                style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('Scanned just now', style: TextStyle(color: AppColors.disabledText, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // ---------- UNREGISTERED SECTION ----------
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
      whatThisMeans = 'This link is highly likely to be malicious. Do not proceed.';
      whatToDo = 'Close the page immediately. Do not enter any information. Report the link if possible.';
    } else if (_riskScore >= 51) {
      whatThisMeans = 'This link shows clear signs of suspicious activity. Proceed with extreme caution.';
      whatToDo = 'Avoid entering personal details. Consider verifying the link with another scanner.';
    } else if (_riskScore >= 26) {
      whatThisMeans = 'This link has a low but non-zero risk. It may be safe, but some indicators are unusual.';
      whatToDo = 'You can proceed, but avoid entering sensitive information. Double-check the URL.';
    } else {
      whatThisMeans = 'No security issues were detected. This link appears safe.';
      whatToDo = 'You may proceed, but always stay cautious. Keep your browser and antivirus updated.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (externalMsg.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _riskColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: _riskColor, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(externalMsg, style: const TextStyle(color: AppColors.primaryText, fontSize: 13))),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text('What this means', style: TextStyle(fontSize: isSmall ? 17 : 19, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
        const SizedBox(height: 10),
        _buildInfoCard(whatThisMeans),
        const SizedBox(height: 16),
        Text('What you should do', style: TextStyle(fontSize: isSmall ? 17 : 19, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Go Back', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: Text('Sign up for more detailed scan results', style: TextStyle(color: AppColors.secondaryText, fontSize: 13))),
      ],
    );
  }

  // ---------- BEGINNER REGISTERED SECTION ----------
  Widget _buildRegisteredDefaultSection(bool isSmall) {
    final engine = widget.engineResult;
    final threatType = engine?['threat_type'] ?? 'benign';
    final mlConfidence = engine?['ml_confidence'] ?? 'none';
    final externalScore = (engine?['external_score'] as num?)?.toDouble() ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Threat Summary', style: TextStyle(fontSize: isSmall ? 17 : 19, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
        const SizedBox(height: 10),
        _buildInfoCard(
          'Risk Score: ${widget.score}%\n'
          'Threat Type: $threatType\n'
          'ML Confidence: $mlConfidence\n'
          'External Score: ${externalScore.toStringAsFixed(2)}\n'
          'External Sources: ${_externalSources.isNotEmpty ? _externalSources.join(', ') : 'None'}',
        ),
        const SizedBox(height: 14),
        Text('Detected Issues', style: TextStyle(fontSize: isSmall ? 17 : 19, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
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

  // ---------- ADVANCED REGISTERED SECTION (with expandable technical details) ----------
  Widget _buildRegisteredAdvancedSection(bool isSmall) {
    final engine = widget.engineResult;
    final isEngineResult = engine != null;

    final threatType = isEngineResult ? (engine['threat_type'] ?? 'benign') : 'benign';
    final mlConfidence = isEngineResult ? (engine['ml_confidence'] ?? 'none') : 'none';
    final externalScore = isEngineResult ? (engine['external_score'] as num?)?.toDouble() ?? 0.0 : 0.0;

    // Extra metrics
    final behaviorPatterns = isEngineResult ? (engine['behavior_matched_patterns'] as List?) ?? [] : [];
    final behaviorCategories = isEngineResult ? (engine['behavior_categories'] as Map?) : null;
    final modelCount = isEngineResult ? (engine['model_count'] as int?) : null;
    final staticScore = isEngineResult ? (engine['static_score'] as num?)?.toDouble() : null;
    final mlRawScore = isEngineResult ? (engine['ml_score_raw'] as num?)?.toDouble() : null;
    final fusionWeights = isEngineResult ? (engine['fusion_weights'] as Map?) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Threat Summary', style: TextStyle(fontSize: isSmall ? 17 : 19, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
        const SizedBox(height: 10),
        _buildInfoCard(
          'Risk Score: ${widget.score}%\n'
          'Threat Type: $threatType\n'
          'ML Confidence: $mlConfidence\n'
          'External Score: ${externalScore.toStringAsFixed(2)}\n'
          'External Sources: ${_externalSources.isNotEmpty ? _externalSources.join(', ') : 'None'}',
        ),
        const SizedBox(height: 14),
        Text('Detected Issues', style: TextStyle(fontSize: isSmall ? 17 : 19, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
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

        // Expandable technical details (only for advanced)
        if (isEngineResult) ...[
          const Divider(height: 28, color: AppColors.divider),
          Text('Technical Breakdown', style: TextStyle(fontSize: isSmall ? 17 : 19, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
          const SizedBox(height: 10),

          // Static Rules Fired
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

          // Machine Learning Probabilities
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

          // External Threat Intelligence
          _buildExpandableSection(
            title: 'External Threat Intelligence',
            isExpanded: _showExternalDetails,
            onTap: () => setState(() => _showExternalDetails = !_showExternalDetails),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_externalSources.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Sources: ${_externalSources.join(', ')}', style: const TextStyle(color: AppColors.primaryText)),
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

          // Behavior Analysis
          if (behaviorPatterns.isNotEmpty || behaviorCategories != null)
            _buildExpandableSection(
              title: 'Behavior Analysis',
              isExpanded: _showBehaviorAnalysis,
              onTap: () => setState(() => _showBehaviorAnalysis = !_showBehaviorAnalysis),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (behaviorPatterns.isNotEmpty) ...[
                    const Text('Matched Patterns:', style: TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    ...behaviorPatterns.map((pattern) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $pattern', style: const TextStyle(color: AppColors.primaryText, fontSize: 13)),
                        )),
                    const SizedBox(height: 8),
                  ],
                  if (behaviorCategories != null) ...[
                    const Text('Categories:', style: TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    ...(behaviorCategories['categories'] as Map? ?? {}).entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('• ${entry.key}: ${(entry.value as List).join(', ')}', style: const TextStyle(color: AppColors.primaryText, fontSize: 13)),
                        )),
                    const SizedBox(height: 4),
                    if (behaviorCategories['summary'] != null)
                      Text('Summary: total=${behaviorCategories['summary']['total_patterns']}, categories=${behaviorCategories['summary']['categories_count']}, severity=${behaviorCategories['summary']['severity']}',
                          style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                  ],
                ],
              ),
            ),

          // Model Metrics
          if (modelCount != null || staticScore != null || mlRawScore != null)
            _buildExpandableSection(
              title: 'Model Metrics',
              isExpanded: _showModelMetrics,
              onTap: () => setState(() => _showModelMetrics = !_showModelMetrics),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (modelCount != null) _buildDetailRow('Model Count', modelCount.toString()),
                  if (staticScore != null) _buildDetailRow('Static Score', staticScore.toStringAsFixed(2)),
                  if (mlRawScore != null) _buildDetailRow('ML Raw Score', mlRawScore.toStringAsFixed(6)),
                ],
              ),
            ),

          // Fusion Details
          if (fusionWeights != null && fusionWeights.isNotEmpty)
            _buildExpandableSection(
              title: 'Fusion Details',
              isExpanded: _showFusionDetails,
              onTap: () => setState(() => _showFusionDetails = !_showFusionDetails),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: fusionWeights.entries.map((entry) => _buildDetailRow(entry.key, (entry.value as num).toStringAsFixed(3))).toList(),
              ),
            ),
        ],

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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.primaryText, fontSize: 13))),
        ],
      ),
    );
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