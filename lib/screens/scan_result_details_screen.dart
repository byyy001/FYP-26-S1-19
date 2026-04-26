import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import '../threat_engine/scan_settings.dart';
import '../threat_engine/layer5_facade/threat_engine.dart';
import 'result_screen.dart';

// ============================================================================
// Extended ScanResult Model
// ============================================================================
class ScanResult {
  final String url;
  final String scanDate;
  final String threatType;
  final double riskScore;
  final String explanation;
  final List<String> detectedThreats;
  final String mlConfidence;
  final double mlScore;
  final double aiScore;
  final double behaviorScore;
  final double externalScore;
  final List<String> externalSources;
  final List<String> recommendedActions;
  final List<String> safetyTips;

  ScanResult({
    required this.url,
    required this.scanDate,
    required this.threatType,
    required this.riskScore,
    required this.explanation,
    required this.detectedThreats,
    required this.mlConfidence,
    required this.mlScore,
    required this.aiScore,
    required this.behaviorScore,
    required this.externalScore,
    required this.externalSources,
    required this.recommendedActions,
    required this.safetyTips,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    List<String> parseStringList(dynamic value) {
      if (value is List) return value.map((e) => e.toString()).toList();
      return [];
    }

    return ScanResult(
      url: json['url']?.toString() ?? '',
      scanDate: json['scan_date']?.toString() ?? '',
      threatType: json['threat_type']?.toString() ?? 'unknown',
      riskScore: parseDouble(json['risk_score']),
      explanation: json['explanation']?.toString() ?? '',
      detectedThreats: parseStringList(json['detected_threats']),
      mlConfidence: json['ml_confidence']?.toString() ?? 'low',
      mlScore: parseDouble(json['ml_score']),
      aiScore: parseDouble(json['ai_score']),
      behaviorScore: parseDouble(json['behavior_score']),
      externalScore: parseDouble(json['external_score']),
      externalSources: parseStringList(json['external_sources']),
      recommendedActions: parseStringList(json['actions']),
      safetyTips: parseStringList(json['safety_tips']),
    );
  }
}

// ============================================================================
// Scan Result Details Screen (with improved report dialog)
// ============================================================================
class ScanResultDetailsScreen extends StatefulWidget {
  final ScanResult scanResult;
  final VoidCallback onDelete;
  final VoidCallback onRescan;

  const ScanResultDetailsScreen({
    super.key,
    required this.scanResult,
    required this.onDelete,
    required this.onRescan,
  });

  @override
  State<ScanResultDetailsScreen> createState() => _ScanResultDetailsScreenState();
}

class _ScanResultDetailsScreenState extends State<ScanResultDetailsScreen> {
  bool _isRescanning = false;

  String _getVerdict(double score) {
    if (score >= 76) return 'Malicious';
    if (score >= 51) return 'Suspicious';
    if (score >= 26) return 'Low Risk';
    return 'Safe';
  }

  Color _getRiskColor(double score) {
    if (score >= 76) return AppColors.highRisk;
    if (score >= 51) return AppColors.mediumRisk;
    if (score >= 26) return AppColors.mediumRisk;
    return AppColors.safe;
  }

  String _getRiskLevel(double score) {
    if (score >= 76) return 'High Risk';
    if (score >= 51) return 'Medium Risk';
    if (score >= 26) return 'Low Risk';
    return 'Safe';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // ======================== IMPROVED REPORT FALSE POSITIVE ========================
  Future<void> _reportFalsePositive() async {
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
                  // Scan summary
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.mainBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.scanResult.url, style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Scanned: ${widget.scanResult.scanDate}', style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                        Text('Detected as: ${widget.scanResult.threatType}', style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                        Text('Risk Score: ${widget.scanResult.riskScore}%', style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
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
        'url': widget.scanResult.url,
        'scanResult': {
          'risk_score': widget.scanResult.riskScore,
          'verdict': _getVerdict(widget.scanResult.riskScore),
          'threat_type': widget.scanResult.threatType,
          'explanation': widget.scanResult.explanation,
          'detected_threats': widget.scanResult.detectedThreats,
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

  @override
  Widget build(BuildContext context) {
    final scan = widget.scanResult;
    final riskScore = scan.riskScore;
    final verdict = _getVerdict(riskScore);
    final riskColor = _getRiskColor(riskScore);
    final riskLevel = _getRiskLevel(riskScore);

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Scan Details', style: TextStyle(color: AppColors.primaryText)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isRescanning
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopCard(scan, verdict, riskColor, riskLevel),
                  const SizedBox(height: 24),
                  _buildDivider(),
                  const SizedBox(height: 24),
                  _buildThreatSummaryCard(scan),
                  const SizedBox(height: 24),
                  _buildDivider(),
                  const SizedBox(height: 24),
                  _buildDetectedIssues(scan),
                  const SizedBox(height: 24),
                  _buildDivider(),
                  const SizedBox(height: 24),
                  _buildRecommendedActions(scan),
                  const SizedBox(height: 24),
                  if (scan.safetyTips.isNotEmpty) ...[
                    _buildDivider(),
                    const SizedBox(height: 24),
                    _buildSafetyTips(scan),
                    const SizedBox(height: 24),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _showDeleteDialog(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.highRisk,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Delete from History'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppColors.primaryPurple, Color(0xFFA855F7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton(
                            onPressed: () => _rescanUrl(scan.url),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Rescan URL'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _reportFalsePositive,
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
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // ================= TOP CARD =================
  Widget _buildTopCard(ScanResult scan, String verdict, Color riskColor, String riskLevel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [riskColor.withOpacity(0.15), AppColors.cardBackground], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: riskColor.withOpacity(0.3), width: 1),
        boxShadow: [BoxShadow(color: riskColor.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6))],
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
                    Text(verdict, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primaryText)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: riskColor, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(riskLevel, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: riskColor)),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 100, height: 100, child: _RiskGauge(score: scan.riskScore / 100, color: riskColor)),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.mainBackground.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider.withOpacity(0.2)),
            ),
            child: Text(scan.explanation, style: const TextStyle(color: AppColors.secondaryText, fontSize: 14, height: 1.5)),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.mainBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                  child: Text(scan.url, style: const TextStyle(color: AppColors.primaryText, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy, size: 20, color: AppColors.primaryPurple),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: scan.url));
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL copied'), backgroundColor: AppColors.safe));
                },
                tooltip: 'Copy URL',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: Text('Scanned at ${scan.scanDate}', style: const TextStyle(color: AppColors.disabledText, fontSize: 11))),
        ],
      ),
    );
  }

  // ================= THREAT SUMMARY CARD =================
  Widget _buildThreatSummaryCard(ScanResult scan) {
    String _formatScore(double value) {
      if (value == 0.0) return '—';
      return value.toStringAsFixed(value < 1 ? 4 : 2);
    }

    final rows = [
      {'label': 'Threat Type', 'value': scan.threatType},
      {'label': 'ML Confidence', 'value': scan.mlConfidence},
      {'label': 'ML Score', 'value': _formatScore(scan.mlScore)},
      {'label': 'AI Score', 'value': _formatScore(scan.aiScore)},
      {'label': 'Behavior Score', 'value': _formatScore(scan.behaviorScore)},
      {'label': 'External Score', 'value': _formatScore(scan.externalScore)},
      {'label': 'External Sources', 'value': scan.externalSources.isNotEmpty ? scan.externalSources.join(', ') : 'None'},
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
            Row(children: [Icon(Icons.summarize, color: AppColors.primaryPurple, size: 20), const SizedBox(width: 8), const Text('Threat Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primaryText))]),
            const SizedBox(height: 16),
            ...rows.map((row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 120, child: Text(row['label']!, style: const TextStyle(color: AppColors.secondaryText, fontSize: 13, fontWeight: FontWeight.w500))),
                  Expanded(child: Text(row['value']!, style: const TextStyle(color: AppColors.primaryText, fontSize: 13), softWrap: true)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  // ================= DETECTED ISSUES =================
  Widget _buildDetectedIssues(ScanResult scan) {
    if (scan.detectedThreats.isEmpty) return _buildEmptyMessage('No specific threats detected.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('DETECTED ISSUES', Icons.bug_report),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: scan.detectedThreats.map((issue) => _buildIssueChip(issue)).toList()),
      ],
    );
  }

  // ================= RECOMMENDED ACTIONS =================
  Widget _buildRecommendedActions(ScanResult scan) {
    List<String> actions = scan.recommendedActions.isNotEmpty ? scan.recommendedActions : _generateDefaultActions(scan.threatType, scan.riskScore);
    int riskIndex = -1;
    for (int i = 0; i < actions.length; i++) {
      final lower = actions[i].toLowerCase();
      if (lower.contains('high risk') || lower.contains('medium risk') || lower.contains('low risk') || lower.contains('safe')) {
        riskIndex = i;
        break;
      }
    }
    if (riskIndex > 0) {
      final riskAction = actions.removeAt(riskIndex);
      actions.insert(0, riskAction);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('RECOMMENDED ACTIONS', Icons.gavel),
        const SizedBox(height: 12),
        Card(
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
                final bool isRiskAction = index == 0 && (action.toLowerCase().contains('high risk') || action.toLowerCase().contains('medium risk') || action.toLowerCase().contains('low risk') || action.toLowerCase().contains('safe'));
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
                    children: [Icon(icon, color: iconColor, size: 18), const SizedBox(width: 8), Expanded(child: Text(action, style: const TextStyle(color: AppColors.primaryText, fontSize: 14)))],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ================= SAFETY TIPS =================
  Widget _buildSafetyTips(ScanResult scan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('SAFETY TIPS', Icons.lightbulb),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: AppColors.cardBackground,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: scan.safetyTips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [const Icon(Icons.lightbulb_outline, color: AppColors.primaryPurple, size: 18), const SizedBox(width: 8), Expanded(child: Text(tip, style: const TextStyle(color: AppColors.primaryText, fontSize: 14)))],
                ),
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ================= HELPER WIDGETS =================
  Widget _buildDivider() => Divider(height: 1, thickness: 1, color: AppColors.divider.withOpacity(0.3));
  Widget _buildSectionHeader(String title, IconData icon) => Row(children: [Icon(icon, color: AppColors.primaryPurple, size: 22), const SizedBox(width: 10), Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primaryText, letterSpacing: 0.5))]);
  Widget _buildIssueChip(String text) {
    Color chipColor;
    IconData icon;
    if (text.toLowerCase().contains('malicious') || text.toLowerCase().contains('phish')) {
      chipColor = AppColors.highRisk;
      icon = Icons.warning;
    } else if (text.toLowerCase().contains('suspicious')) {
      chipColor = AppColors.mediumRisk;
      icon = Icons.error_outline;
    } else {
      chipColor = AppColors.primaryPurple;
      icon = Icons.info_outline;
    }
    return Chip(
      backgroundColor: chipColor.withOpacity(0.15),
      avatar: Icon(icon, size: 16, color: chipColor),
      label: Text(text, style: TextStyle(color: chipColor, fontSize: 13)),
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
  Widget _buildEmptyMessage(String message) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider.withOpacity(0.3))),
    child: Row(children: [Icon(Icons.info_outline, color: AppColors.secondaryText, size: 18), const SizedBox(width: 12), Expanded(child: Text(message, style: const TextStyle(color: AppColors.secondaryText, fontStyle: FontStyle.italic)))]),
  );

  // ================= UTILITIES =================
  List<String> _generateDefaultActions(String threatType, double riskScore) {
    final actions = <String>[];
    if (riskScore >= 76) actions.add('High risk – do not proceed under any circumstances');
    else if (riskScore >= 51) actions.add('Medium risk – avoid entering personal information');
    else if (riskScore >= 26) actions.add('Low risk – proceed with caution, but avoid sensitive actions');
    else actions.add('Safe – no significant threats detected');

    final lowerType = threatType.toLowerCase();
    if (lowerType.contains('malware') || lowerType.contains('malicious')) {
      actions.addAll(['Do NOT download any files from this site', 'Do NOT run any scripts or allow browser notifications', 'Close this page and run a full antivirus / anti-malware scan on your device']);
    } else if (lowerType.contains('phishing')) {
      actions.addAll(['Do NOT enter any password, credit card, or personal information', 'Close this page immediately', 'Report this URL to Google Safe Browsing or OpenPhish']);
    } else if (lowerType.contains('ad_tracker')) {
      actions.add('Consider using an ad blocker or privacy-focused browser');
    } else {
      actions.add('Proceed with caution – stay alert');
    }
    return actions.toSet().toList();
  }

  Future<void> _rescanUrl(String url) async {
    setState(() => _isRescanning = true);
    try {
      final settings = ScanSettings.defaultSettings();
      final engine = await ThreatEngine.getInstance();
      final result = await engine.analyze(url, settings: settings);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen.fromEngineResult(engineResult: result['scan_result'], settings: settings),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rescan failed: $e'), backgroundColor: AppColors.highRisk));
    } finally {
      if (mounted) setState(() => _isRescanning = false);
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Delete Scan', style: TextStyle(color: AppColors.primaryText)),
        content: const Text('Are you sure you want to delete this scan?', style: TextStyle(color: AppColors.secondaryText)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.highRisk)),
          ),
        ],
      ),
    );
  }
}

// ================= CIRCULAR GAUGE =================
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
      ..color = AppColors.divider.withOpacity(0.5)
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