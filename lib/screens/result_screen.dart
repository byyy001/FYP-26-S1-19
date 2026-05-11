import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import '../threat_engine/scan_settings.dart';
import '../threat_engine/layer5_facade/threat_engine.dart';
import '../services/notification_service.dart';

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

    if (widget.isRegistered) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _triggerNotification();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _triggerNotification() async {
    await NotificationService.instance.triggerScanNotification(
      url: widget.url,
      score: widget.score,
      verdict: widget.verdict,
      threatType: widget.engineResult?['threat_type'] ?? 'benign',
      mlConfidence: widget.engineResult?['ml_confidence']?.toString() ?? 'none',
    );
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

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

  // ======================== REPORT FALSE POSITIVE ========================
  Future<void> _showReportDialog(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to report.')),
      );
      return;
    }

    bool wrongCategory = false;
    bool wrongAnalysis = false;
    bool others = false;
    final additionalController = TextEditingController();

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          return AlertDialog(
            backgroundColor: AppColors.cardBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Report False Positive Detection',
              style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.mainBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.url, style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Scanned: ${_formatDate(widget.scanTime)}', style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                        Text('Detected as: ${widget.engineResult?['threat_type'] ?? 'Unknown'}', style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                        Text('Risk Score: ${widget.score}%', style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('What did we get wrong?', style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Wrong risk category', style: TextStyle(color: AppColors.primaryText)),
                    value: wrongCategory,
                    onChanged: (val) => setStateDialog(() => wrongCategory = val ?? false),
                    activeColor: AppColors.primaryPurple,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Wrong risk analysis result', style: TextStyle(color: AppColors.primaryText)),
                    value: wrongAnalysis,
                    onChanged: (val) => setStateDialog(() => wrongAnalysis = val ?? false),
                    activeColor: AppColors.primaryPurple,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Others', style: TextStyle(color: AppColors.primaryText)),
                    value: others,
                    onChanged: (val) => setStateDialog(() => others = val ?? false),
                    activeColor: AppColors.primaryPurple,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 12),
                  const Text('Additional details (Optional)', style: TextStyle(color: AppColors.primaryText)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: additionalController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Please fill in this text box....',
                      hintStyle: const TextStyle(color: AppColors.disabledText),
                      filled: true,
                      fillColor: AppColors.mainBackground,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    style: const TextStyle(color: AppColors.primaryText),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Screenshot attachment coming soon')),
                      );
                    },
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text('Attach Screenshot'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryPurple),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('CANCEL', style: TextStyle(color: AppColors.secondaryText)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
                child: const Text('SAVE CHANGES'),
              ),
            ],
          );
        },
      ),
    );

    if (shouldSubmit != true) return;

    final List<String> reasonsList = [];
    if (wrongCategory) reasonsList.add('Wrong risk category');
    if (wrongAnalysis) reasonsList.add('Wrong risk analysis result');
    if (others) reasonsList.add('Others');
    String finalReason = reasonsList.join(', ');
    if (additionalController.text.trim().isNotEmpty) {
      finalReason = finalReason.isEmpty
          ? additionalController.text.trim()
          : '$finalReason - ${additionalController.text.trim()}';
    }

    try {
      await FirebaseFirestore.instance.collection('false_reports').add({
        'userId': user.uid,
        'userEmail': user.email,
        'url': widget.url,
        'scanResult': {
          'risk_score': widget.score,
          'verdict': widget.verdict,
          'threat_type': widget.engineResult?['threat_type'],
          'explanation': widget.explanation,
          'detected_threats': widget.reasons,
        },
        'reason': finalReason,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you! Report submitted for review.'),
          backgroundColor: AppColors.safe,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit report: $e'), backgroundColor: AppColors.highRisk),
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

  // ---------- REGISTERED DEFAULT SECTION ----------
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
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showReportDialog(context),
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: const Text('Report as False Positive'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.secondaryText),
              foregroundColor: AppColors.secondaryText,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 16),
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

  // ---------- ADVANCED REGISTERED SECTION ----------
  Widget _buildRegisteredAdvancedSection(bool isSmall) {
    final engine = widget.engineResult;
    final isEngineResult = engine != null;

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
          DefaultTabController(
            length: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 16),
                SizedBox(
                  height: 550, // Enough for individual models + ensemble
                  child: TabBarView(
                    children: [
                      _buildTechnicalDetailsTab(engine!),
                      _buildExternalDataTab(engine),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showReportDialog(context),
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: const Text('Report as False Positive'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.secondaryText),
              foregroundColor: AppColors.secondaryText,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 16),
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

  // ======================== HELPER WIDGETS ========================
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
    if (cleanText.toLowerCase().contains('unencrypted http')) {
      chipColor = AppColors.mediumRisk;
      icon = Icons.lock_open;
    } else if (cleanText.toLowerCase().contains('malicious') || cleanText.toLowerCase().contains('phish')) {
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

  // ======================== TECHNICAL DETAILS TAB (with individual & ensemble) ========================
  Widget _buildTechnicalDetailsTab(Map<String, dynamic> engine) {
    final staticThreats = engine['detailed_detected_threats'] as List? ?? [];
    final behaviorPatterns = engine['behavior_matched_patterns'] as List? ?? [];
    final behaviorCategories = engine['behavior_categories'] ?? {};

    // Get individual model probabilities and ensemble probabilities
    final individualModels = engine['individual_model_probabilities'] as Map<String, dynamic>?;
    final ensembleProbs = (engine['ensemble_probabilities'] as List?) ?? [];

    // List of class names
    const classNames = ['Benign', 'Defacement', 'Phishing', 'Malware'];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Static Rules Fired
          _buildExpandableSection(
            title: 'Static Rules Fired',
            icon: Icons.rule,
            isExpanded: _showStaticRules,
            onTap: () => setState(() => _showStaticRules = !_showStaticRules),
            child: staticThreats.isEmpty
                ? _buildEmptyMessage('No static rules fired')
                : Column(
                    children: staticThreats.map<Widget>((threat) {
                      final type = threat['type'] ?? 'unknown';
                      final severity = threat['severity'] ?? 'low';
                      final desc = threat['description'] ?? '';
                      Color severityColor;
                      switch (severity) {
                        case 'high':
                          severityColor = AppColors.highRisk;
                          break;
                        case 'medium':
                          severityColor = AppColors.mediumRisk;
                          break;
                        default:
                          severityColor = AppColors.safe;
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning, size: 16, color: severityColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    type.toUpperCase(),
                                    style: TextStyle(
                                      color: severityColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    desc,
                                    style: const TextStyle(color: AppColors.primaryText, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 16),

          // Machine Learning Probabilities – Individual Models + Ensemble
          _buildExpandableSection(
            title: 'Machine Learning Probabilities',
            icon: Icons.show_chart,
            isExpanded: _showMLDetails,
            onTap: () => setState(() => _showMLDetails = !_showMLDetails),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Individual models (if available)
                if (individualModels != null && individualModels.isNotEmpty) ...[
                  const Text(
                    'Individual Model Probabilities',
                    style: TextStyle(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...individualModels.entries.map((entry) {
                    final modelName = entry.key;
                    final probs = entry.value as List?;
                    if (probs == null || probs.length != 4) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Text(
                            modelName.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...classNames.asMap().entries.map((classEntry) {
                          final idx = classEntry.key;
                          final label = classEntry.value;
                          final prob = (probs[idx] as num).toDouble();
                          Color barColor;
                          switch (idx) {
                            case 2: // Phishing
                              barColor = AppColors.highRisk;
                              break;
                            case 3: // Malware
                              barColor = AppColors.mediumRisk;
                              break;
                            default:
                              barColor = AppColors.safe;
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(label, style: const TextStyle(color: AppColors.primaryText, fontSize: 12)),
                                    const Spacer(),
                                    Text('${(prob * 100).toStringAsFixed(1)}%',
                                        style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: prob,
                                    backgroundColor: AppColors.divider,
                                    color: barColor,
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 12),
                      ],
                    );
                  }).toList(),
                  const Divider(color: AppColors.divider, height: 24),
                  const SizedBox(height: 8),
                ],

                // Ensemble probabilities
                if (ensembleProbs.isNotEmpty) ...[
                  const Text(
                    'Ensemble (Final) Probabilities',
                    style: TextStyle(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...classNames.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final label = entry.value;
                    final prob = idx < ensembleProbs.length ? ensembleProbs[idx] : 0.0;
                    Color barColor;
                    switch (idx) {
                      case 2:
                        barColor = AppColors.highRisk;
                        break;
                      case 3:
                        barColor = AppColors.mediumRisk;
                        break;
                      default:
                        barColor = AppColors.safe;
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(label, style: const TextStyle(color: AppColors.primaryText, fontSize: 12)),
                              const Spacer(),
                              Text('${(prob * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: prob,
                              backgroundColor: AppColors.divider,
                              color: barColor,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],

                if (individualModels == null && ensembleProbs.isEmpty)
                  _buildEmptyMessage('No probability data available.'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Behavior Analysis
          _buildExpandableSection(
            title: 'Behavior Analysis',
            icon: Icons.insights,
            isExpanded: _showBehaviorAnalysis,
            onTap: () => setState(() => _showBehaviorAnalysis = !_showBehaviorAnalysis),
            child: behaviorPatterns.isEmpty
                ? _buildEmptyMessage('No suspicious behavior patterns identified.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (behaviorCategories.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Categories: ${(behaviorCategories['categories'] as Map? ?? {}).keys.join(', ')}',
                            style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                          ),
                        ),
                      ...behaviorPatterns.map((pattern) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _buildInfoLine(pattern.toString(), Icons.code,
                                iconColor: AppColors.mediumRisk),
                          )),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ======================== EXTERNAL DATA TAB ========================
  Widget _buildExternalDataTab(Map<String, dynamic> engine) {
    final externalSources = List<String>.from(engine['external_sources'] ?? []);
    final externalScore = _toDouble(engine['external_score']);
    final externalDetails = engine['external_details'] as Map<String, dynamic>?;

    Map<String, dynamic>? whoisDetails;
    if (externalDetails != null && externalDetails.containsKey('whois')) {
      whoisDetails = externalDetails['whois'] as Map<String, dynamic>?;
    }

    List<MapEntry<String, dynamic>> otherDetails = [];
    if (externalDetails != null) {
      for (final entry in externalDetails.entries) {
        if (entry.key != 'whois') {
          otherDetails.add(entry);
        }
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildExpandableSection(
            title: 'External API Results',
            icon: Icons.api,
            isExpanded: _showExternalApiResults,
            onTap: () => setState(() => _showExternalApiResults = !_showExternalApiResults),
            child: externalSources.isEmpty && otherDetails.isEmpty
                ? _buildEmptyMessage('No external API data available.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (externalSources.isNotEmpty) ...[
                        _buildInfoLine('External Score: ${(externalScore * 100).toStringAsFixed(0)}%',
                            Icons.score, iconColor: AppColors.primaryPurple),
                        _buildInfoLine('Sources: ${externalSources.join(', ')}', Icons.source,
                            iconColor: AppColors.primaryPurple),
                      ],
                      if (otherDetails.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Other Details:',
                          style: TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        ...otherDetails.map((entry) {
                          final key = entry.key;
                          final value = entry.value;
                          String displayValue;
                          if (value is Map) {
                            displayValue = value.toString();
                          } else {
                            displayValue = value.toString();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _buildInfoLine('$key: $displayValue', Icons.info_outline,
                                iconColor: AppColors.secondaryText),
                          );
                        }),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          _buildExpandableSection(
            title: 'Whois Domain Information',
            icon: Icons.info_outline,
            isExpanded: _showExternalDetails,
            onTap: () => setState(() => _showExternalDetails = !_showExternalDetails),
            child: whoisDetails == null
                ? _buildEmptyMessage(
                    'Domain info not obtained.\nPossible reasons: no WHOIS record, API limit, or domain registration hidden.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (whoisDetails.containsKey('age_days'))
                        _buildInfoLine('Age: ${whoisDetails['age_days']} days', Icons.calendar_today,
                            iconColor: AppColors.primaryPurple),
                      if (whoisDetails.containsKey('warning') && whoisDetails['warning'] != null)
                        _buildInfoLine('Warning: ${whoisDetails['warning']}', Icons.warning,
                            iconColor: AppColors.highRisk),
                      for (final entry in whoisDetails.entries)
                        if (entry.key != 'age_days' && entry.key != 'warning')
                          _buildInfoLine('${entry.key}: ${entry.value}', Icons.info,
                              iconColor: AppColors.secondaryText),
                    ],
                  ),
          ),
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
}

// ======================== CIRCULAR GAUGE ========================
class _RiskGauge extends StatelessWidget {
  final double score;
  final Color color;
  const _RiskGauge({required this.score, required this.color});
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _SemiCircularGaugePainter(score: score, color: color), child: const Center(child: Text('')));
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
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - 6), startAngle, sweepAngle, false, backgroundPaint);
    final progressAngle = sweepAngle * score;
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - 6), startAngle, progressAngle, false, progressPaint);
    final textSpan = TextSpan(text: '${(score * 100).toInt()}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white));
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    textPainter.layout();
    final textOffset = Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height - 4);
    textPainter.paint(canvas, textOffset);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}