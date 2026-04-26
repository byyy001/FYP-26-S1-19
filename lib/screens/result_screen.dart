import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../constants/app_colors.dart';
import '../threat_engine/scan_settings.dart';
import '../threat_engine/layer5_facade/threat_engine.dart';

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
  final DateTime scanTime;

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
    required this.scanTime,
  });

  factory ResultScreen.fromEngineResult({
    required Map<String, dynamic> engineResult,
    required ScanSettings settings,
  }) {
    final int score = (double.tryParse(engineResult['risk_score']?.toString() ?? '0') ?? 0).toInt();
    final String verdict = _getVerdictFromScore(score);
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
      scanTime: DateTime.now(),
    );
  }

  static String _getVerdictFromScore(int score) {
    if (score >= 76) return 'Malicious';
    if (score >= 51) return 'Suspicious';
    if (score >= 26) return 'Low Risk';
    return 'Safe';
  }

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  bool _showStaticRules = false;
  bool _showMLDetails = false;
  bool _showBehaviorAnalysis = false;
  bool _showModelMetrics = false;
  bool _showFusionDetails = false;
  bool _showExternalApiResults = false;
  bool _showExternalDetails = false;

  late final ScrollController _scrollController;
  bool _showScrollTop = false;

  // Ad‑intensity threshold (could be moved to ScanSettings for premium users)
  static const double adIntensityThreshold = 0.3;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.offset > 300 && !_showScrollTop) {
        setState(() => _showScrollTop = true);
      } else if (_scrollController.offset <= 300 && _showScrollTop) {
        setState(() => _showScrollTop = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _cleanText(String text) {
    return text.replaceAll(RegExp(r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F900}-\u{1F9FF}]', unicode: true), '');
  }

  List<String> get _safetyTips {
    final raw = widget.engineResult?['safety_tips'] as List?;
    return raw?.cast<String>().map(_cleanText).toList() ?? [];
  }

  List<String> get _externalSources {
    final raw = widget.engineResult?['external_sources'] as List?;
    return raw?.cast<String>() ?? [];
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
    if (_riskScore >= 76) return 'Malicious';
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

  // Helper: build ad‑intensity warning widget (reused)
  Widget _buildAdIntensityWarning() {
    final adDensity = widget.engineResult?['ad_density'];
    final bool isAdIntensive = (adDensity is double && adDensity > adIntensityThreshold);
    if (!isAdIntensive) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.ad_units, color: Colors.orange, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '⚠️ This site may contain excessive ads or intrusive pop-ups.',
                  style: TextStyle(color: AppColors.primaryText, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Consider using an ad blocker or avoid clicking on pop-ups.',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
          ),
        ],
      ),
    );
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
Detected Issues: ${widget.reasons.isNotEmpty ? widget.reasons.map(_cleanText).join(', ') : 'None'}
External Sources: ${_externalSources.isNotEmpty ? _externalSources.join(', ') : 'None'}
Explanation: ${_cleanText(widget.explanation)}
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
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

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
            pw.Text('Scan Date: ${widget.scanTime.toLocal().toString()}'),
            pw.SizedBox(height: 10),
            pw.Text('Risk Score: ${widget.score}%',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Verdict: ${widget.verdict}'),
            pw.Text('Threat Type: $threatType'),
            pw.Text('ML Confidence: $mlConfidence'),
            pw.Text('External Score: ${externalScore.toStringAsFixed(2)}'),
            pw.Text(
                'External Sources: ${_externalSources.isNotEmpty ? _externalSources.join(', ') : 'None'}'),
            pw.SizedBox(height: 10),
            pw.Text('Detected Issues:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ...widget.reasons.map((reason) => pw.Text('• ${_cleanText(reason)}')),
            if (widget.reasons.isEmpty) pw.Text('• None'),
            pw.SizedBox(height: 10),
            pw.Text('Recommended Actions:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ...widget.recommendedActions.map((action) => pw.Text('• ${_cleanText(action)}')),
            if (widget.recommendedActions.isEmpty) pw.Text('• None'),
            if (_safetyTips.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text('Safety Tips:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ..._safetyTips.map((tip) => pw.Text('• $tip')),
            ],
            pw.SizedBox(height: 20),
            pw.Text('Explanation: ${_cleanText(widget.explanation)}'),
          ],
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File(
          '${output.path}/linksentry_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      if (mounted) Navigator.pop(context);
      await Share.shareXFiles([XFile(file.path)], subject: 'LinkSentry Scan Report');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF generation failed: $e'),
              backgroundColor: AppColors.highRisk),
        );
      }
    }
  }

  // ======================== RESCAN ========================
  Future<void> _rescanUrl() async {
    if (widget.settings == null || widget.url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to re-scan this URL'),
          backgroundColor: AppColors.highRisk,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Re-scanning...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final engine = await ThreatEngine.getInstance();
      final result = await engine.analyze(widget.url, settings: widget.settings!);

      if (!mounted) return;
      Navigator.pop(context);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen.fromEngineResult(
            engineResult: result['scan_result'],
            settings: widget.settings!,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Re-scan failed: $e'),
          backgroundColor: AppColors.highRisk,
        ),
      );
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
        title: const Text('Scan Results',
            style: TextStyle(
                color: AppColors.primaryText, fontWeight: FontWeight.w600)),
        actions: widget.isRegistered
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.primaryText),
                  onPressed: _rescanUrl,
                  tooltip: 'Re-scan this URL',
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.primaryText),
                  onSelected: (value) async {
                    if (value == 'share') await _shareResults();
                    else if (value == 'copy') await _copyToClipboard();
                    else if (value == 'pdf') await _downloadPDF();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'share',
                        child: Row(children: [Icon(Icons.share), SizedBox(width: 12), Text('Share')])),
                    const PopupMenuItem(value: 'copy',
                        child: Row(children: [Icon(Icons.copy), SizedBox(width: 12), Text('Copy to clipboard')])),
                    const PopupMenuItem(value: 'pdf',
                        child: Row(children: [Icon(Icons.picture_as_pdf), SizedBox(width: 12), Text('Download PDF')])),
                  ],
                ),
              ]
            : null,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopCard(isSmall),
                  const SizedBox(height: 24),
                  _buildDivider(),
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
          if (_showScrollTop)
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton.small(
                onPressed: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
                child: const Icon(Icons.arrow_upward),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.divider.withValues(alpha: 0.3),
    );
  }

  // ======================== TOP CARD ========================
  Widget _buildTopCard(bool isSmall) {
    return Semantics(
      label: 'Risk score ${widget.score} percent, $_riskLevelText',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_riskColor.withValues(alpha: 0.15), AppColors.cardBackground],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _riskColor.withValues(alpha: 0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: _riskColor.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.isRegistered ? widget.verdict : _getSimpleVerdict(),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _riskColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _riskLevelText,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _riskColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 100,
                  height: 100,
                  child: _RiskGauge(score: _riskScore / 100, color: _riskColor),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.mainBackground.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider.withValues(alpha: 0.2)),
              ),
              child: Text(
                _cleanText(widget.explanation),
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.mainBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(
                      widget.url,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20, color: AppColors.primaryPurple),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: widget.url));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('URL copied'), backgroundColor: AppColors.safe),
                      );
                    }
                  },
                  tooltip: 'Copy URL',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Scanned at ${_formatTime(widget.scanTime)}',
                style: const TextStyle(color: AppColors.disabledText, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (time.day == now.day && time.month == now.month && time.year == now.year) {
      return 'Today ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.day}/${time.month}/${time.year} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  // ---------- UNREGISTERED SECTION (with ad warning) ----------
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

    // Threat type display
    String? threatTypeRaw = widget.engineResult?['threat_type'];
    String threatDisplay = '';
    IconData? threatIcon;
    Color? threatColor;
    if (threatTypeRaw != null && threatTypeRaw != 'benign') {
      switch (threatTypeRaw) {
        case 'phishing':
          threatDisplay = '⚠️ Phishing site detected';
          threatIcon = Icons.phishing;
          threatColor = AppColors.highRisk;
          break;
        case 'malware':
          threatDisplay = '⚠️ Malware risk detected';
          threatIcon = Icons.bug_report;
          threatColor = AppColors.highRisk;
          break;
        case 'defacement':
          threatDisplay = '⚠️ Website may have been defaced';
          threatIcon = Icons.flag;
          threatColor = AppColors.mediumRisk;
          break;
        default:
          threatDisplay = '⚠️ Suspicious: $threatTypeRaw';
          threatIcon = Icons.warning;
          threatColor = AppColors.mediumRisk;
      }
    }

    // Insecure scripts hint
    final behaviorPatterns = (widget.engineResult?['behavior_matched_patterns'] as List?) ?? [];
    bool hasInsecureScripts = behaviorPatterns.any((pattern) =>
        pattern.toString().toLowerCase().contains('eval') ||
        pattern.toString().toLowerCase().contains('document.write') ||
        pattern.toString().toLowerCase().contains('javascript:'));

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
        if (threatDisplay.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: (threatColor ?? _riskColor).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: (threatColor ?? _riskColor).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(threatIcon ?? Icons.warning, color: threatColor ?? _riskColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    threatDisplay,
                    style: const TextStyle(color: AppColors.primaryText, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        _buildAdIntensityWarning(),
        if (hasInsecureScripts)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.mediumRisk.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.mediumRisk.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.code, color: AppColors.mediumRisk, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '⚠️ Insecure or obfuscated scripts detected.',
                    style: TextStyle(color: AppColors.primaryText, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        if (externalMsg.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _riskColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: _riskColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(externalMsg,
                        style: const TextStyle(color: AppColors.primaryText, fontSize: 13))),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        Text('What this means',
            style: TextStyle(
                fontSize: isSmall ? 18 : 20,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText)),
        const SizedBox(height: 12),
        _buildInfoCard(whatThisMeans),
        const SizedBox(height: 24),
        Text('What you should do',
            style: TextStyle(
                fontSize: isSmall ? 18 : 20,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText)),
        const SizedBox(height: 12),
        _buildInfoCard(whatToDo),
        const SizedBox(height: 24),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'TECHNICAL BREAKDOWN (Premium)',
                        style: TextStyle(
                          color: AppColors.primaryPurple,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '• External API Results (VirusTotal, Google Safe Browsing...)',
                        style: TextStyle(color: AppColors.primaryText),
                      ),
                      Text(
                        '• Static Rules Fired',
                        style: TextStyle(color: AppColors.primaryText),
                      ),
                      Text(
                        '• Machine Learning Probabilities',
                        style: TextStyle(color: AppColors.primaryText),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Align(
                    alignment: Alignment.center,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Upgrade to see full report')),
                        );
                      },
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Unlock Full Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
      ],
    );
  }

  // ---------- REGISTERED DEFAULT SECTION (with ad warning) ----------
  Widget _buildRegisteredDefaultSection(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildThreatSummaryCard(),
        const SizedBox(height: 16),
        _buildAdIntensityWarning(),
        const SizedBox(height: 24),
        _buildDivider(),
        const SizedBox(height: 24),
        _buildSectionHeader('DETECTED ISSUES', Icons.bug_report),
        const SizedBox(height: 12),
        widget.reasons.isNotEmpty
            ? Wrap(
                spacing: 10,
                runSpacing: 10,
                children: widget.reasons.map((reason) => _buildIssueChip(reason)).toList(),
              )
            : _buildEmptyMessage('No specific threats detected'),
        const SizedBox(height: 32),
        _buildDivider(),
        const SizedBox(height: 24),
        _buildSectionHeader('RECOMMENDED ACTIONS', Icons.gavel),
        const SizedBox(height: 12),
        _buildActionsCard(),
        const SizedBox(height: 32),
        if (_safetyTips.isNotEmpty) ...[
          _buildDivider(),
          const SizedBox(height: 24),
          _buildSectionHeader('SAFETY TIPS', Icons.lightbulb),
          const SizedBox(height: 12),
          _buildSafetyTipsCard(),
          const SizedBox(height: 32),
        ],
        Center(
          child: SizedBox(
            width: 160,
            height: 46,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- ADVANCED REGISTERED SECTION (same as before, unchanged) ----------
  Widget _buildRegisteredAdvancedSection(bool isSmall) {
    final engine = widget.engineResult;
    final isEngineResult = engine != null;

    if (isEngineResult) {
      debugPrint('=== Behavior Analysis Debug ===');
      debugPrint('behavior_matched_patterns: ${engine['behavior_matched_patterns']}');
      debugPrint('behavior_categories: ${engine['behavior_categories']}');
      debugPrint('behavior_score: ${engine['behavior_score']}');
      debugPrint('================================');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildThreatSummaryCard(),
        const SizedBox(height: 16),
        _buildAdIntensityWarning(),
        const SizedBox(height: 24),
        _buildDivider(),
        const SizedBox(height: 24),
        _buildSectionHeader('DETECTED ISSUES', Icons.bug_report),
        const SizedBox(height: 12),
        widget.reasons.isNotEmpty
            ? Wrap(
                spacing: 10,
                runSpacing: 10,
                children: widget.reasons.map((reason) => _buildIssueChip(reason)).toList(),
              )
            : _buildEmptyMessage('No specific threats detected'),
        const SizedBox(height: 32),
        _buildDivider(),
        const SizedBox(height: 24),
        _buildSectionHeader('RECOMMENDED ACTIONS', Icons.gavel),
        const SizedBox(height: 12),
        _buildActionsCard(),
        const SizedBox(height: 32),
        if (_safetyTips.isNotEmpty) ...[
          _buildDivider(),
          const SizedBox(height: 24),
          _buildSectionHeader('SAFETY TIPS', Icons.lightbulb),
          const SizedBox(height: 12),
          _buildSafetyTipsCard(),
          const SizedBox(height: 32),
        ],
        if (isEngineResult) ...[
          _buildDivider(),
          const SizedBox(height: 24),
          _buildSectionHeader('TECHNICAL ANALYSIS', Icons.code),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 600),
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    indicatorColor: AppColors.primaryPurple,
                    labelColor: AppColors.primaryPurple,
                    unselectedLabelColor: AppColors.secondaryText,
                    tabs: [
                      Tab(text: 'Technical Details', icon: Icon(Icons.memory)),
                      Tab(text: 'External Data', icon: Icon(Icons.cloud_queue)),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.only(top: 16),
                          child: _buildTechnicalDetailsTab(engine!),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.only(top: 16),
                          child: _buildExternalDataTab(engine),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        Center(
          child: SizedBox(
            width: 160,
            height: 46,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    );
  }

  // ======================== THREAT SUMMARY CARD ========================
  Widget _buildThreatSummaryCard() {
    final engine = widget.engineResult;
    final rawThreatType = engine?['threat_type'] ?? 'benign';
    final threatType = _formatThreatType(rawThreatType);
    final mlConfidence = engine != null ? _cleanText(engine['ml_confidence'] ?? 'none') : 'none';
    final mlScore = _toDouble(engine?['ml_score']);
    final aiScore = _toDouble(engine?['ai_score']);
    final behaviorScore = _toDouble(engine?['behavior_score']);
    final externalScore = _toDouble(engine?['external_score']);
    final externalSources = _externalSources.isNotEmpty ? _externalSources.join(', ') : 'None';

    final rows = [
      {'label': 'Threat Type', 'value': threatType},
      {'label': 'ML Confidence', 'value': mlConfidence},
      {'label': 'ML Score', 'value': mlScore.toStringAsFixed(4)},
      {'label': 'AI Score', 'value': aiScore.toStringAsFixed(2)},
      {'label': 'Behavior Score', 'value': behaviorScore.toStringAsFixed(2)},
      {'label': 'External Score', 'value': externalScore.toStringAsFixed(2)},
      {'label': 'External Sources', 'value': externalSources},
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: AppColors.primaryPurple, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Threat Summary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primaryText),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...rows.map((row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      row['label']!,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row['value']!,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 13,
                      ),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  String _formatThreatType(String type) {
    switch (type.toLowerCase()) {
      case 'benign':
        return 'Benign';
      case 'defacement':
        return 'Defacement';
      case 'phishing':
        return 'Phishing';
      case 'malware':
        return 'Malware';
      default:
        return type[0].toUpperCase() + type.substring(1);
    }
  }

  // ======================== HELPER WIDGETS (unchanged from earlier, just kept) ========================
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryPurple, size: 22),
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

  Widget _buildIssueChip(String text) {
    final cleanText = _cleanText(text);
    Color chipColor;
    IconData icon;
    if (cleanText.toLowerCase().contains('malicious') || cleanText.toLowerCase().contains('phish')) {
      chipColor = AppColors.highRisk;
      icon = Icons.warning;
    } else if (cleanText.toLowerCase().contains('suspicious')) {
      chipColor = AppColors.mediumRisk;
      icon = Icons.error_outline;
    } else {
      chipColor = AppColors.primaryPurple;
      icon = Icons.info_outline;
    }
    return Chip(
      backgroundColor: chipColor.withValues(alpha: 0.15),
      avatar: Icon(icon, size: 16, color: chipColor),
      label: Text(
        cleanText,
        style: TextStyle(color: chipColor, fontSize: 13),
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildActionsCard() {
    List<String> actions = List.from(widget.recommendedActions);
    actions = actions.map((a) => _cleanText(a)).toList();

    int riskIndex = -1;
    for (int i = 0; i < actions.length; i++) {
      final lower = actions[i].toLowerCase();
      if (lower.contains('high risk') || lower.contains('medium risk') || lower.contains('low risk') || lower.contains('safe – no significant')) {
        riskIndex = i;
        break;
      }
    }

    if (riskIndex > 0) {
      final riskAction = actions.removeAt(riskIndex);
      actions.insert(0, riskAction);
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: actions.asMap().entries.map((entry) {
            final index = entry.key;
            final action = entry.value;
            final bool isRiskAction = index == 0 && (action.toLowerCase().contains('high risk') ||
                action.toLowerCase().contains('medium risk') ||
                action.toLowerCase().contains('low risk') ||
                action.toLowerCase().contains('safe – no significant'));
            IconData icon;
            Color iconColor;
            if (isRiskAction) {
              if (action.toLowerCase().contains('high risk')) {
                icon = Icons.warning_amber;
                iconColor = AppColors.highRisk;
              } else if (action.toLowerCase().contains('medium risk')) {
                icon = Icons.warning;
                iconColor = AppColors.mediumRisk;
              } else if (action.toLowerCase().contains('low risk')) {
                icon = Icons.info_outline;
                iconColor = AppColors.mediumRisk;
              } else {
                icon = Icons.check_circle;
                iconColor = AppColors.safe;
              }
            } else {
              icon = Icons.check_circle;
              iconColor = AppColors.safe;
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: iconColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      action,
                      style: const TextStyle(color: AppColors.primaryText, fontSize: 14),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSafetyTipsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _safetyTips.map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, color: AppColors.primaryPurple, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tip,
                    style: const TextStyle(color: AppColors.primaryText, fontSize: 14),
                  ),
                ),
              ],
            ),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyMessage(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.secondaryText, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: AppColors.secondaryText, fontStyle: FontStyle.italic)),
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
              style: const TextStyle(color: AppColors.primaryText, fontSize: 13),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
          color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
      child: Text(text,
          style: const TextStyle(color: AppColors.primaryText, fontSize: 14, height: 1.45),
          softWrap: true),
    );
  }

  // Technical Details Tab Content
  Widget _buildTechnicalDetailsTab(Map<String, dynamic> engine) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildExpandableSection(
          title: 'Static Rules Fired',
          icon: Icons.rule,
          isExpanded: _showStaticRules,
          onTap: () => setState(() => _showStaticRules = !_showStaticRules),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: (engine['detailed_detected_threats'] as List? ?? []).isEmpty
                ? [_buildEmptyMessage('No static rules fired')]
                : (engine['detailed_detected_threats'] as List)
                    .map<Widget>((threat) => _buildInfoLine(
                          '[${threat['severity']?.toString().toUpperCase()}] ${_cleanText(threat['description'])}',
                          Icons.circle,
                          iconColor: AppColors.secondaryText,
                        ))
                    .toList(),
          ),
        ),
        const SizedBox(height: 16),
        _buildExpandableSection(
          title: 'Machine Learning Probabilities',
          icon: Icons.show_chart,
          isExpanded: _showMLDetails,
          onTap: () => setState(() => _showMLDetails = !_showMLDetails),
          child: _buildMLProbabilitiesTable(engine),
        ),
        const SizedBox(height: 16),
        _buildExpandableSection(
          title: 'Behavior Analysis',
          icon: Icons.insights,
          isExpanded: _showBehaviorAnalysis,
          onTap: () => setState(() => _showBehaviorAnalysis = !_showBehaviorAnalysis),
          child: _buildBehaviorAnalysis(engine),
        ),
        const SizedBox(height: 16),
        if (engine['model_count'] != null ||
            engine['static_score'] != null ||
            engine['ml_score_raw'] != null)
          _buildExpandableSection(
            title: 'Model Metrics',
            icon: Icons.memory,
            isExpanded: _showModelMetrics,
            onTap: () => setState(() => _showModelMetrics = !_showModelMetrics),
            child: _buildMetricsTable(engine),
          ),
        const SizedBox(height: 16),
        if (engine['fusion_weights'] != null)
          _buildExpandableSection(
            title: 'Fusion Details',
            icon: Icons.merge_type,
            isExpanded: _showFusionDetails,
            onTap: () => setState(() => _showFusionDetails = !_showFusionDetails),
            child: _buildFusionDetailsTable(engine['fusion_weights']),
          ),
      ],
    );
  }

  // External Data Tab Content
  Widget _buildExternalDataTab(Map<String, dynamic> engine) {
    final externalDetails = engine['external_details'] as Map?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildExpandableSection(
          title: 'External API Results',
          icon: Icons.api,
          isExpanded: _showExternalApiResults,
          onTap: () => setState(() => _showExternalApiResults = !_showExternalApiResults),
          child: _buildExternalApiResults(engine),
        ),
        const SizedBox(height: 16),
        _buildExpandableSection(
          title: 'Raw Threat Intelligence',
          icon: Icons.cloud_queue,
          isExpanded: _showExternalDetails,
          onTap: () => setState(() => _showExternalDetails = !_showExternalDetails),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_externalSources.isNotEmpty)
                _buildInfoLine('Sources: ${_externalSources.join(', ')}', Icons.source),
              if (externalDetails != null && externalDetails.isNotEmpty)
                ...externalDetails.entries.map<Widget>((entry) {
                  final valueStr = entry.value.toString();
                  return _buildInfoLine('${entry.key}: $valueStr', Icons.data_usage,
                      iconColor: AppColors.secondaryText);
                }).toList(),
              if (externalDetails == null || externalDetails.isEmpty)
                _buildEmptyMessage('No external intelligence data'),
            ],
          ),
        ),
      ],
    );
  }

  // Helper for expandable sections
  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
      ),
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
                      style: const TextStyle(
                          color: AppColors.primaryText, fontSize: 16, fontWeight: FontWeight.w500),
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
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: child,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ML probabilities table
  Widget _buildMLProbabilitiesTable(Map<String, dynamic> engine) {
    final probsMap = engine['individual_model_probabilities'] as Map<dynamic, dynamic>?;
    final ensembleProbs = engine['ensemble_probabilities'];

    if ((probsMap == null || probsMap.isEmpty) && ensembleProbs == null) {
      return _buildEmptyMessage('No probability data available.');
    }

    final List<Widget> rows = [];

    Widget probBar(double value, Color color) {
      return Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: AppColors.divider,
            color: color,
            minHeight: 8,
          ),
        ),
      );
    }

    Widget probRow(List<double> probs) {
      const labels = ['Benign', 'Deface', 'Phish', 'Malware'];
      const colors = [Colors.green, Colors.orange, Colors.orange, Colors.red];
      return Column(
        children: List.generate(probs.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(labels[i], style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                ),
                probBar(probs[i], colors[i]),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text('${(probs[i] * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 12, color: AppColors.primaryText)),
                ),
              ],
            ),
          );
        }),
      );
    }

    if (probsMap != null) {
      probsMap.forEach((modelName, values) {
        final probsList = (values as List).map((v) => _toDouble(v)).toList();
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(modelName.toString(),
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryText)),
                const SizedBox(height: 8),
                probRow(probsList),
              ],
            ),
          ),
        );
      });
    }

    if (ensembleProbs != null) {
      final ensembleList = (ensembleProbs as List).map((v) => _toDouble(v)).toList();
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ensemble',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryPurple)),
              const SizedBox(height: 8),
              probRow(ensembleList),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(children: rows),
    );
  }

  Widget _buildFusionDetailsTable(Map<String, dynamic>? fusionWeights) {
    if (fusionWeights == null || fusionWeights.isEmpty) {
      return _buildEmptyMessage('No fusion weights available');
    }
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: const [
            Expanded(
              child: Text('Weight',
                  style: TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Text('Value',
                  style: TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    ];
    fusionWeights.forEach((key, value) {
      final val = _toDouble(value).toStringAsFixed(3);
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Expanded(child: Text(key, style: const TextStyle(color: AppColors.primaryText))),
              Expanded(child: Text(val, style: const TextStyle(color: AppColors.primaryText))),
            ],
          ),
        ),
      );
    });
    return Container(
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildMetricsTable(Map<String, dynamic> engine) {
    final children = <Widget>[];
    if (engine['model_count'] != null) {
      children.add(_buildMetricRow('Model Count', engine['model_count'].toString()));
    }
    if (engine['static_score'] != null) {
      children.add(_buildMetricRow('Static Score', _toDouble(engine['static_score']).toStringAsFixed(2)));
    }
    if (engine['ml_score_raw'] != null) {
      children.add(_buildMetricRow('ML Raw Score', _toDouble(engine['ml_score_raw']).toStringAsFixed(6)));
    }
    if (children.isEmpty) return _buildEmptyMessage('No metrics available');
    return Container(
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(children: children),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.primaryText))),
        ],
      ),
    );
  }

  Widget _buildBehaviorAnalysis(Map<String, dynamic> engine) {
    final behaviorPatterns = (engine['behavior_matched_patterns'] as List?) ?? [];
    final behaviorCategories = engine['behavior_categories'] as Map?;

    if (behaviorPatterns.isEmpty && behaviorCategories == null) {
      return _buildEmptyMessage('No suspicious behavior patterns were identified for this URL.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (behaviorPatterns.isNotEmpty) ...[
          const Text('Matched Patterns:',
              style: TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ...behaviorPatterns.map((pattern) => _buildInfoLine(_cleanText(pattern.toString()), Icons.pattern)),
          const SizedBox(height: 12),
        ],
        if (behaviorCategories != null) ...[
          const Text('Categories:',
              style: TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ...(behaviorCategories['categories'] as Map? ?? {})
              .entries
              .map((entry) => _buildInfoLine(
                  '${entry.key}: ${(entry.value as List).join(', ')}', Icons.category)),
          const SizedBox(height: 4),
          if (behaviorCategories['summary'] != null)
            Text(
              'Summary: total=${behaviorCategories['summary']['total_patterns']}, categories=${behaviorCategories['summary']['categories_count']}, severity=${behaviorCategories['summary']['severity']}',
              style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
            ),
        ],
      ],
    );
  }

  Widget _buildExternalApiResults(Map<String, dynamic> engine) {
    final externalDetails = engine['external_details'] as Map?;
    String googleMsg = _externalSources.contains('Google Safe Browsing')
        ? 'Google Safe Browsing: Threat found!'
        : 'Google Safe Browsing: No threat found.';
    String vtMsg = '';
    if (externalDetails != null && externalDetails.containsKey('virustotal')) {
      final vt = externalDetails['virustotal'];
      if (vt is Map) {
        final malicious = vt['malicious'] ?? 0;
        final suspicious = vt['suspicious'] ?? 0;
        final total = vt['total'] ?? 0;
        vtMsg = 'VirusTotal: $malicious engines malicious, $suspicious suspicious (out of $total)';
      } else if (vt is num) {
        vtMsg = 'VirusTotal: score ${vt.toStringAsFixed(2)}';
      }
    } else {
      vtMsg = _externalSources.contains('VirusTotal')
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoLine(googleMsg, Icons.security),
        _buildInfoLine(vtMsg, Icons.bug_report),
        _buildInfoLine(openPhishMsg, Icons.link),
        _buildInfoLine(whoisMsg, Icons.date_range),
        if (ipqsMsg.isNotEmpty) _buildInfoLine(ipqsMsg, Icons.verified),
      ],
    );
  }
}

// ======================== CIRCULAR GAUGE CUSTOM PAINTER ========================
class _RiskGauge extends StatelessWidget {
  final double score;
  final Color color;

  const _RiskGauge({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SemiCircularGaugePainter(score: score, color: color),
      child: const Center(child: Text('')),
    );
  }
}

class _SemiCircularGaugePainter extends CustomPainter {
  final double score;
  final Color color;

  _SemiCircularGaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;
    final startAngle = -pi;
    final sweepAngle = pi;
    final backgroundPaint = Paint()
      ..color = AppColors.divider.withValues(alpha: 0.5)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      startAngle,
      sweepAngle,
      false,
      backgroundPaint,
    );

    final progressAngle = sweepAngle * score;
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      startAngle,
      progressAngle,
      false,
      progressPaint,
    );

    final textSpan = TextSpan(
      text: '${(score * 100).toInt()}%',
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final textOffset = Offset(
      center.dx - textPainter.width / 2,
      center.dy - textPainter.height - 4,
    );
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}