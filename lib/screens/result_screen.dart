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
    final int score = (double.tryParse(engineResult['risk_score']?.toString() ?? '0') ?? 0).toInt();
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
  bool _showExternalApiResults = false;

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

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
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
      final externalScore = _toDouble(widget.engineResult?['external_score']);

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
    final externalScore = _toDouble(engine?['external_score']);

    final summaryItems = [
      {'icon': Icons.shield, 'label': 'Risk Score', 'value': '${widget.score}%'},
      {'icon': Icons.warning_amber, 'label': 'Threat Type', 'value': threatType},
      {'icon': Icons.psychology_alt, 'label': 'ML Confidence', 'value': mlConfidence},
      {'icon': Icons.analytics, 'label': 'ML Score', 'value': _toDouble(engine?['ml_score']).toStringAsFixed(4)},
      {'icon': Icons.psychology_alt, 'label': 'AI Score', 'value': _toDouble(engine?['ai_score']).toStringAsFixed(2)},
      {'icon': Icons.track_changes, 'label': 'Behavior Score', 'value': _toDouble(engine?['behavior_score']).toStringAsFixed(2)},
      {'icon': Icons.cloud, 'label': 'External Score', 'value': externalScore.toStringAsFixed(2)},
      {'icon': Icons.list_alt, 'label': 'External Sources', 'value': _externalSources.isNotEmpty ? _externalSources.join(', ') : 'None'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMainHeader('THREAT SUMMARY', Icons.summarize),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: _cardDecoration(),
          child: Column(
            children: summaryItems.map((item) => _buildSummaryRow(item['icon'] as IconData, item['label'] as String, item['value'] as String)).toList(),
          ),
        ),
        const SizedBox(height: 24),
        _buildMainHeader('DETECTED ISSUES', Icons.bug_report),
        const SizedBox(height: 8),
        ...widget.reasons.map((reason) => _buildListItem(reason, Icons.warning, AppColors.mediumRisk)),
        const SizedBox(height: 24),
        _buildMainHeader('RECOMMENDED ACTIONS', Icons.gavel),
        const SizedBox(height: 8),
        ...widget.recommendedActions.map((action) => _buildListItem(action, Icons.check_circle, AppColors.safe)),
        const SizedBox(height: 24),
        if (_safetyTips.isNotEmpty) ...[
          _buildMainHeader('SAFETY TIPS', Icons.lightbulb),
          const SizedBox(height: 8),
          ..._safetyTips.map((tip) => _buildListItem(tip, Icons.info, AppColors.primaryPurple)),
          const SizedBox(height: 24),
        ],
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

  // ---------- ADVANCED REGISTERED SECTION (with improved tables and spacing) ----------
  Widget _buildRegisteredAdvancedSection(bool isSmall) {
    final engine = widget.engineResult;
    final isEngineResult = engine != null;

    final threatType = isEngineResult ? (engine['threat_type'] ?? 'benign') : 'benign';
    final mlConfidence = isEngineResult ? (engine['ml_confidence'] ?? 'none') : 'none';
    final externalScore = _toDouble(engine?['external_score']);

    final behaviorPatterns = isEngineResult ? (engine['behavior_matched_patterns'] as List?) ?? [] : [];
    final behaviorCategories = isEngineResult ? (engine['behavior_categories'] as Map?) : null;
    final modelCount = isEngineResult ? _toInt(engine['model_count']) : null;
    final staticScore = isEngineResult ? _toDouble(engine['static_score']) : null;
    final mlRawScore = isEngineResult ? _toDouble(engine['ml_score_raw']) : null;
    final fusionWeights = isEngineResult ? (engine['fusion_weights'] as Map<String, dynamic>?) : null;

    final externalDetails = isEngineResult ? (engine['external_details'] as Map?) : null;
    String virusTotalMsg = '';
    if (externalDetails != null && externalDetails.containsKey('virustotal')) {
      final vt = externalDetails['virustotal'];
      if (vt is Map) {
        final malicious = vt['malicious'] ?? 0;
        final suspicious = vt['suspicious'] ?? 0;
        final total = vt['total'] ?? 0;
        virusTotalMsg = 'VirusTotal: Threat found! $malicious engines detected malicious, $suspicious suspicious (out of $total)';
      } else if (vt is num) {
        virusTotalMsg = 'VirusTotal: score ${vt.toStringAsFixed(2)}';
      }
    } else {
      virusTotalMsg = _externalSources.contains('VirusTotal')
          ? 'VirusTotal: Threat found! (details not available)'
          : 'VirusTotal: No threat found.';
    }

    String openPhishMsg = 'OpenPhish: URL not found';
    if (externalDetails != null && externalDetails.containsKey('openphish')) {
      final op = externalDetails['openphish'];
      if (op is Map && op['source'] != null) openPhishMsg = 'OpenPhish: URL found in feed';
    }

    String whoisMsg = 'WhoisAPI: No createdDate for domain';
    if (externalDetails != null && externalDetails.containsKey('whois')) {
      final whois = externalDetails['whois'];
      if (whois is Map && whois['age_days'] != null) {
        final age = whois['age_days'];
        whoisMsg = 'WhoisAPI: Domain age $age days (${age < 30 ? 'new' : 'established'})';
        if (whois['warning'] != null) whoisMsg += ' - ${whois['warning']}';
      }
    }

    String ipqsMsg = '';
    if (externalDetails != null && externalDetails.containsKey('ipqualityscore')) {
      final ipqs = externalDetails['ipqualityscore'];
      if (ipqs is Map) {
        ipqsMsg = 'IPQualityScore: risk_score ${ipqs['risk_score'] ?? 'N/A'}';
      } else if (ipqs is num) {
        ipqsMsg = 'IPQualityScore: score ${ipqs.toStringAsFixed(2)}';
      }
    }

    String googleSafebrowsingMsg = _externalSources.contains('Google Safe Browsing')
        ? 'GoogleSafeBrowsing: Threat found!'
        : 'GoogleSafeBrowsing: No threat found.';

    final summaryItems = [
      {'icon': Icons.shield, 'label': 'Risk Score', 'value': '${widget.score}%'},
      {'icon': Icons.warning_amber, 'label': 'Threat Type', 'value': threatType},
      {'icon': Icons.psychology_alt, 'label': 'ML Confidence', 'value': mlConfidence},
      {'icon': Icons.analytics, 'label': 'ML Score', 'value': _toDouble(engine?['ml_score']).toStringAsFixed(4)},
      {'icon': Icons.psychology_alt, 'label': 'AI Score', 'value': _toDouble(engine?['ai_score']).toStringAsFixed(2)},
      {'icon': Icons.track_changes, 'label': 'Behavior Score', 'value': _toDouble(engine?['behavior_score']).toStringAsFixed(2)},
      {'icon': Icons.cloud, 'label': 'External Score', 'value': externalScore.toStringAsFixed(2)},
      {'icon': Icons.list_alt, 'label': 'External Sources', 'value': _externalSources.isNotEmpty ? _externalSources.join(', ') : 'None'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMainHeader('THREAT SUMMARY', Icons.summarize),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: _cardDecoration(),
          child: Column(
            children: summaryItems.map((item) => _buildSummaryRow(item['icon'] as IconData, item['label'] as String, item['value'] as String)).toList(),
          ),
        ),
        const SizedBox(height: 24),
        _buildMainHeader('DETECTED ISSUES', Icons.bug_report),
        const SizedBox(height: 8),
        ...widget.reasons.map((reason) => _buildListItem(reason, Icons.warning, AppColors.mediumRisk)),
        const SizedBox(height: 24),
        _buildMainHeader('RECOMMENDED ACTIONS', Icons.gavel),
        const SizedBox(height: 8),
        ...widget.recommendedActions.map((action) => _buildListItem(action, Icons.check_circle, AppColors.safe)),
        const SizedBox(height: 24),
        if (_safetyTips.isNotEmpty) ...[
          _buildMainHeader('SAFETY TIPS', Icons.lightbulb),
          const SizedBox(height: 8),
          ..._safetyTips.map((tip) => _buildListItem(tip, Icons.info, AppColors.primaryPurple)),
          const SizedBox(height: 24),
        ],

        if (isEngineResult) ...[
          const Divider(height: 32, thickness: 1, color: AppColors.divider),
          _buildMainHeader('TECHNICAL BREAKDOWN', Icons.code),
          const SizedBox(height: 16),

          // External API Results
          _buildExpandableSection(
            title: 'External API Results',
            icon: Icons.api,
            isExpanded: _showExternalApiResults,
            onTap: () => setState(() => _showExternalApiResults = !_showExternalApiResults),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoLine(googleSafebrowsingMsg, Icons.security),
                _buildInfoLine(virusTotalMsg, Icons.bug_report),
                _buildInfoLine(openPhishMsg, Icons.link),
                _buildInfoLine(whoisMsg, Icons.date_range),
                if (ipqsMsg.isNotEmpty) _buildInfoLine(ipqsMsg, Icons.verified),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Static Rules Fired
          _buildExpandableSection(
            title: 'Static Rules Fired',
            icon: Icons.rule,
            isExpanded: _showStaticRules,
            onTap: () => setState(() => _showStaticRules = !_showStaticRules),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: (engine['detailed_detected_threats'] as List? ?? [])
                  .map<Widget>((threat) => _buildInfoLine(
                        '[${threat['severity']?.toString().toUpperCase()}] ${threat['description']}',
                        Icons.circle,
                        iconColor: AppColors.secondaryText,
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Machine Learning Probabilities (displayed as a table) – FIXED TYPE ERROR
          _buildExpandableSection(
            title: 'Machine Learning Probabilities',
            icon: Icons.show_chart,
            isExpanded: _showMLDetails,
            onTap: () => setState(() => _showMLDetails = !_showMLDetails),
            child: _buildMLProbabilitiesTable(engine),
          ),
          const SizedBox(height: 12),

          // External Threat Intelligence (Raw)
          _buildExpandableSection(
            title: 'External Threat Intelligence (Raw)',
            icon: Icons.cloud_queue,
            isExpanded: _showExternalDetails,
            onTap: () => setState(() => _showExternalDetails = !_showExternalDetails),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_externalSources.isNotEmpty)
                  _buildInfoLine('Sources: ${_externalSources.join(', ')}', Icons.source),
                if (externalDetails != null)
                  ...externalDetails.entries.map<Widget>((entry) {
                    final valueStr = entry.value.toString();
                    return _buildInfoLine('${entry.key}: $valueStr', Icons.data_usage, iconColor: AppColors.secondaryText);
                  }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Behavior Analysis
          if (behaviorPatterns.isNotEmpty || behaviorCategories != null)
            _buildExpandableSection(
              title: 'Behavior Analysis',
              icon: Icons.insights,
              isExpanded: _showBehaviorAnalysis,
              onTap: () => setState(() => _showBehaviorAnalysis = !_showBehaviorAnalysis),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (behaviorPatterns.isNotEmpty) ...[
                    const Text('Matched Patterns:', style: TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    ...behaviorPatterns.map((pattern) => _buildInfoLine(pattern, Icons.pattern)),
                    const SizedBox(height: 8),
                  ],
                  if (behaviorCategories != null) ...[
                    const Text('Categories:', style: TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    ...(behaviorCategories['categories'] as Map? ?? {}).entries.map((entry) => _buildInfoLine('${entry.key}: ${(entry.value as List).join(', ')}', Icons.category)),
                    const SizedBox(height: 4),
                    if (behaviorCategories['summary'] != null)
                      Text(
                        'Summary: total=${behaviorCategories['summary']['total_patterns']}, categories=${behaviorCategories['summary']['categories_count']}, severity=${behaviorCategories['summary']['severity']}',
                        style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                      ),
                  ],
                ],
              ),
            ),

          // Model Metrics (table)
          if (modelCount != null || staticScore != null || mlRawScore != null)
            _buildExpandableSection(
              title: 'Model Metrics',
              icon: Icons.memory,
              isExpanded: _showModelMetrics,
              onTap: () => setState(() => _showModelMetrics = !_showModelMetrics),
              child: _buildMetricsTable(modelCount, staticScore, mlRawScore),
            ),
          const SizedBox(height: 12),

          // Fusion Details (table)
          if (fusionWeights != null && fusionWeights.isNotEmpty)
            _buildExpandableSection(
              title: 'Fusion Details',
              icon: Icons.merge_type,
              isExpanded: _showFusionDetails,
              onTap: () => setState(() => _showFusionDetails = !_showFusionDetails),
              child: _buildFusionDetailsTable(fusionWeights),
            ),
          const SizedBox(height: 12),
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

  // ======================== NEW HELPER TABLES ========================
  Widget _buildMLProbabilitiesTable(Map<String, dynamic>? engine) {
    final rows = <TableRow>[];
    // Header row
    rows.add(
      TableRow(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider.withOpacity(0.5))),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Model', style: TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Probabilities [benign, defacement, phishing, malware]', style: TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (engine?['individual_model_probabilities'] != null) {
      final probs = engine!['individual_model_probabilities'] as Map<dynamic, dynamic>;
      probs.forEach((modelName, values) {
        final formatted = _formatProbList(values);
        rows.add(
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(modelName.toString(), style: const TextStyle(color: AppColors.primaryText)),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(formatted, style: const TextStyle(color: AppColors.primaryText)),
              ),
            ],
          ),
        );
      });
    }

    if (engine?['ensemble_probabilities'] != null) {
      final ensembleFormatted = _formatProbList(engine!['ensemble_probabilities']);
      rows.add(
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Ensemble', style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w500)),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(ensembleFormatted, style: const TextStyle(color: AppColors.primaryText)),
            ),
          ],
        ),
      );
    }

    if (rows.length == 1) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Text('No probability data available.', style: TextStyle(color: AppColors.secondaryText)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Table(
        columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(2)},
        children: rows,
      ),
    );
  }

  Widget _buildFusionDetailsTable(Map<String, dynamic> fusionWeights) {
    final rows = <TableRow>[];
    // Header
    rows.add(
      TableRow(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider.withOpacity(0.5))),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Weight', style: TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Value', style: TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    fusionWeights.forEach((key, value) {
      final val = _toDouble(value).toStringAsFixed(3);
      rows.add(
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(key, style: const TextStyle(color: AppColors.primaryText)),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(val, style: const TextStyle(color: AppColors.primaryText)),
            ),
          ],
        ),
      );
    });

    return Container(
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Table(
        columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1)},
        children: rows,
      ),
    );
  }

  Widget _buildMetricsTable(int? modelCount, double? staticScore, double? mlRawScore) {
    final List<Map<String, String>> rows = [];
    if (modelCount != null) rows.add({'Metric': 'Model Count', 'Value': modelCount.toString()});
    if (staticScore != null) rows.add({'Metric': 'Static Score', 'Value': staticScore.toStringAsFixed(2)});
    if (mlRawScore != null) rows.add({'Metric': 'ML Raw Score', 'Value': mlRawScore.toStringAsFixed(6)});

    return Container(
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Table(
        columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(2)},
        children: rows.map((row) {
          return TableRow(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider.withOpacity(0.5))),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(row['Metric']!, style: const TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w500)),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(row['Value']!, style: const TextStyle(color: AppColors.primaryText)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ======================== EXISTING UI HELPERS ========================
  Widget _buildMainHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryPurple, size: 22),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryText,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider.withOpacity(0.3)),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryPurple),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.primaryText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(String text, IconData icon, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.primaryText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoLine(String text, IconData icon, {Color iconColor = AppColors.primaryPurple}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.primaryText, fontSize: 13)),
          ),
        ],
      ),
    );
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

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: AppColors.primaryPurple),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(color: AppColors.primaryText, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.primaryText,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
        ],
      ),
    );
  }

  String _formatProbList(dynamic probs) {
    if (probs is List) return probs.map((p) => _toDouble(p).toStringAsFixed(3)).join(', ');
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
}