import 'package:flutter/material.dart';

// ============================================================================
// Color Palette
// ============================================================================
class _Colors {
  static const Color mainBackground = Color(0xFF151515);
  static const Color cardBackground = Color(0xFF1A1F2E);
  static const Color primaryText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFFB3B8C5);
  static const Color disabledText = Color(0xFF6B7280);
  static const Color divider = Color(0xFF2F3547);
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color highRisk = Color(0xFFEF4444);
  static const Color mediumRisk = Color(0xFFF59E0B);
  static const Color safe = Color(0xFF22C55E);
}

// ============================================================================
// Model: ScanResult
// ============================================================================
class ScanResult {
  final String url;
  final String scanDate;
  final String threatType;
  final double riskScore;
  final String explanation;
  final List<String> detectedThreats;
  final String mlConfidence;
  final double behaviorScore;
  final double aiScore;

  ScanResult({
    required this.url,
    required this.scanDate,
    required this.threatType,
    required this.riskScore,
    required this.explanation,
    required this.detectedThreats,
    required this.mlConfidence,
    required this.behaviorScore,
    required this.aiScore,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    double parseRiskScore(dynamic value) {
      if (value == null) return 0;
      final str = value.toString().replaceAll('%', '');
      return double.tryParse(str) ?? 0;
    }

    List<String> parseDetectedThreats(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
    }

    return ScanResult(
      url: json['url']?.toString() ?? '',
      scanDate: json['scan_date']?.toString() ?? '',
      threatType: json['threat_type']?.toString() ?? 'unknown',
      riskScore: parseRiskScore(json['risk_score']),
      explanation: json['explanation']?.toString() ?? '',
      detectedThreats: parseDetectedThreats(json['detected_threats']),
      mlConfidence: json['ml_confidence']?.toString() ?? 'low',
      behaviorScore: (json['behavior_score'] as num?)?.toDouble() ?? 0.0,
      aiScore: (json['ai_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ============================================================================
// Threat Category
// ============================================================================
class ThreatCategory {
  final String label;
  final IconData icon;
  final Color color;

  const ThreatCategory._(this.label, this.icon, this.color);

  static const double highRiskThreshold = 70;
  static const double mediumRiskThreshold = 40;

  static ThreatCategory fromScanResult(ScanResult result) {
    final type = result.threatType.toLowerCase();
    final score = result.riskScore;

    if (type.contains('malware') ||
        type.contains('phishing') ||
        type.contains('defacement') ||
        score >= highRiskThreshold) {
      return const ThreatCategory._('MALICIOUS', Icons.warning, _Colors.highRisk);
    }

    if (type.contains('suspicious') ||
        type.contains('ad_tracker') ||
        score >= mediumRiskThreshold) {
      return const ThreatCategory._('WARNING', Icons.warning_amber, _Colors.mediumRisk);
    }

    return const ThreatCategory._('SAFE', Icons.check_circle, _Colors.safe);
  }
}

// ============================================================================
// Screen
// ============================================================================
class ScanResultDetailsScreen extends StatefulWidget {
  final ScanResult scanResult;

  const ScanResultDetailsScreen({
    super.key,
    required this.scanResult,
  });

  @override
  State<ScanResultDetailsScreen> createState() =>
      _ScanResultDetailsScreenState();
}

class _ScanResultDetailsScreenState
    extends State<ScanResultDetailsScreen> {
  bool _showActions = false;

  @override
  Widget build(BuildContext context) {
    final category = ThreatCategory.fromScanResult(widget.scanResult);
    final scan = widget.scanResult;

    return Scaffold(
      backgroundColor: _Colors.mainBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Scan History Details',
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
            _buildMainCard(category, scan),
            const SizedBox(height: 20),
            _buildThreatAnalysis(scan, category),
            const SizedBox(height: 16),
            _buildActionsSection(),
            const SizedBox(height: 16),
            _buildDeleteButton(context),
            const SizedBox(height: 16),
            _buildCancelButton(),
          ],
        ),
      ),
    );
  }

  // ================= MAIN CARD =================
  Widget _buildMainCard(ThreatCategory category, ScanResult scan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: category.color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(category.icon, color: category.color, size: 16),
          const SizedBox(width: 6),
          Text(category.label,
              style: TextStyle(
                  color: category.color, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 16),
        Text(scan.url,
            style: const TextStyle(color: _Colors.primaryText)),
        const SizedBox(height: 8),
        Text('Scanned: ${scan.scanDate}',
            style: const TextStyle(color: _Colors.disabledText)),
      ]),
    );
  }

  // ================= THREAT ANALYSIS =================
  Widget _buildThreatAnalysis(
      ScanResult scan, ThreatCategory category) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          'THREAT ANALYSIS',
          style: TextStyle(
            color: _Colors.secondaryText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 16),

        // ✅ RISK METER ADDED HERE
        _buildRiskMeter(scan.riskScore),

        const SizedBox(height: 16),

        _buildInfoRow('Category', scan.threatType),
        const Divider(color: _Colors.divider),
        _buildInfoRow(
            'Risk Score', '${scan.riskScore.toStringAsFixed(0)}%'),
        const Divider(color: _Colors.divider),
        _buildInfoRow('Severity', category.label,
            valueColor: category.color),

        const SizedBox(height: 16),

        const Text(
          'Why it\'s unsafe:',
          style: TextStyle(color: _Colors.secondaryText),
        ),
        const SizedBox(height: 8),
        Text(scan.explanation,
            style: const TextStyle(color: _Colors.primaryText)),

        const SizedBox(height: 16),

        const Text(
          'Detected threats:',
          style: TextStyle(color: _Colors.secondaryText),
        ),
        const SizedBox(height: 8),
        ...scan.detectedThreats.map((t) => Row(children: [
              const Icon(Icons.warning, color: _Colors.highRisk, size: 16),
              const SizedBox(width: 8),
              Text(t,
                  style: const TextStyle(color: _Colors.primaryText))
            ]))
      ]),
    );
  }

  // ================= RISK METER =================
  Widget _buildRiskMeter(double score) {
    Color meterColor;

    if (score >= 70) {
      meterColor = _Colors.highRisk;
    } else if (score >= 40) {
      meterColor = _Colors.mediumRisk;
    } else {
      meterColor = _Colors.safe;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Risk Level',
                style: TextStyle(color: _Colors.secondaryText)),
            Text('${score.toStringAsFixed(0)}%',
                style: TextStyle(
                    color: meterColor, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),

        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 12,
            color: _Colors.divider,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  width: constraints.maxWidth * (score / 100),
                  color: meterColor,
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Safe',
                style: TextStyle(color: _Colors.safe, fontSize: 12)),
            Text('Warning',
                style:
                    TextStyle(color: _Colors.mediumRisk, fontSize: 12)),
            Text('Danger',
                style:
                    TextStyle(color: _Colors.highRisk, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  // ================= HELPERS =================
  Widget _buildInfoRow(String label, String value,
      {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: _Colors.secondaryText)),
        Text(value,
            style: TextStyle(
                color: valueColor ?? _Colors.primaryText,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildActionsSection() {
    return TextButton(
      onPressed: () => setState(() => _showActions = !_showActions),
      child: const Text('Take Action...',
          style: TextStyle(color: _Colors.primaryPurple)),
    );
  }

  Widget _buildDeleteButton(BuildContext context) {
    return TextButton(
      onPressed: () => _showDeleteDialog(context),
      child: const Text('Delete from History',
          style: TextStyle(color: _Colors.highRisk)),
    );
  }

  Widget _buildCancelButton() {
    return TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Cancel',
          style: TextStyle(color: _Colors.secondaryText)),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _Colors.cardBackground,
        title: const Text('Delete Scan',
            style: TextStyle(color: _Colors.primaryText)),
        content: const Text('Delete this scan?',
            style: TextStyle(color: _Colors.secondaryText)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Delete',
                  style: TextStyle(color: _Colors.highRisk))),
        ],
      ),
    );
  }
}