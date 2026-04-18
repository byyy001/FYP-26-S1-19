import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/app_colors.dart';
import '../services/ai_threat_analyzer.dart';

// ============================================================================
// Color Palette (matches app_colors.dart)
// ============================================================================
class _Colors {
  static const Color mainBackground = AppColors.mainBackground;
  static const Color cardBackground = AppColors.cardBackground;
  static const Color primaryText = AppColors.primaryText;
  static const Color secondaryText = AppColors.secondaryText;
  static const Color primaryPurple = AppColors.primaryPurple;
  static const Color primaryBlue = AppColors.primaryBlue;
  static const Color highRisk = AppColors.highRisk;
  static const Color mediumRisk = AppColors.mediumRisk;
  static const Color safe = AppColors.safe;
}

// ============================================================================
// Security Insights Screen (Stateful)
// ============================================================================
class SecurityInsightsScreen extends StatefulWidget {
  const SecurityInsightsScreen({super.key});

  @override
  State<SecurityInsightsScreen> createState() => _SecurityInsightsScreenState();
}

class _SecurityInsightsScreenState extends State<SecurityInsightsScreen> {
  UserInsights? _insights;
  List<ScanResult> _scans = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You need to be signed in to view security insights.');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userName = (userDoc.data()?['firstName']?.toString().trim().isNotEmpty ??
              false)
          ? userDoc.data()!['firstName'].toString().trim()
          : (user.displayName?.trim().isNotEmpty ?? false)
              ? user.displayName!.trim()
              : 'User';

      final scansSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('scans')
          .orderBy('scannedAt', descending: true)
          .get();

      final scans = scansSnapshot.docs
          .map((doc) => _scanResultFromFirestore(doc.data()))
          .toList();

      final insights = AIThreatAnalyzer.analyze(
        userName,
        scans,
        periodDays: 30,
      );

      if (!mounted) return;
      setState(() {
        _insights = insights;
        _scans = scans;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load insights: $e';
        _isLoading = false;
      });
    }
  }

  ScanResult _scanResultFromFirestore(Map<String, dynamic> data) {
    DateTime timestamp = DateTime.now();
    final scannedAt = data['scannedAt'];
    if (scannedAt is Timestamp) {
      timestamp = scannedAt.toDate();
    } else if (scannedAt is String) {
      timestamp = DateTime.tryParse(scannedAt) ?? DateTime.now();
    }

    double riskScore = 0;
    final rawRisk = data['riskScore'] ?? data['risk_score'];
    if (rawRisk is num) {
      riskScore = rawRisk.toDouble();
    } else if (rawRisk != null) {
      riskScore = double.tryParse(rawRisk.toString()) ?? 0;
    }

    List<String> detectedThreats = [];
    final rawThreats = data['detectedThreats'] ?? data['detected_threats'];
    if (rawThreats is List) {
      detectedThreats = rawThreats.map((e) => e.toString()).toList();
    }

    final rawThreatType =
        (data['threatType'] ?? data['threat_type'] ?? data['result'] ?? data['verdict'] ?? 'unknown')
            .toString()
            .toLowerCase();

    return ScanResult(
      url: data['url']?.toString() ?? '',
      timestamp: timestamp,
      threatType: _normalizeThreatType(rawThreatType),
      riskScore: riskScore,
      explanation: data['explanation']?.toString() ?? '',
      detectedThreats: detectedThreats,
      mlConfidence: data['ml_confidence']?.toString() ?? 'low',
      behaviorScore: _toDouble(data['behavior_score']),
      aiScore: _toDouble(data['ai_score']),
      source: data['source']?.toString() ?? 'manual',
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _normalizeThreatType(String value) {
    switch (value) {
      case 'unsafe':
      case 'malicious':
      case 'high risk':
        return 'malware';
      case 'suspicious':
      case 'medium risk':
      case 'low risk':
        return 'phishing';
      case 'safe':
      case 'benign':
        return 'benign';
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Colors.mainBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Security Insights',
          style: TextStyle(color: _Colors.primaryText),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _Colors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: _Colors.highRisk, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(color: _Colors.secondaryText),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadInsights,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final insights = _insights!;
    final topThreats = insights.topThreats;
    final trends = insights.trends;
    final tips = insights.smartTips;
    final threatPercentages = _buildThreatPie(_scans);
    final oldestSafeLinks = _oldestSafeLinksNotRescanned(_scans);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          Text(
            'Your Security Insights',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _Colors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hi ${insights.userName}! Based on your last ${insights.periodDays} days',
            style: const TextStyle(
              fontSize: 16,
              color: _Colors.secondaryText,
            ),
          ),
          const SizedBox(height: 24),
          _buildRiskProfileCard(insights),
          const SizedBox(height: 24),

          if (threatPercentages.isNotEmpty) ...[
            _buildThreatPieChart(threatPercentages),
            const SizedBox(height: 24),
          ],

          if (oldestSafeLinks.isNotEmpty) ...[
            _buildOldestSafeLinksChart(oldestSafeLinks),
            const SizedBox(height: 24),
          ],

          // Top Threats
          const Text(
            'TOP THREATS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _Colors.secondaryText,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildThreatList(topThreats),
          const SizedBox(height: 24),

          // Sentry Insights (Trends)
          if (trends.isNotEmpty) ...[
            const Text(
              'SENTRY INSIGHTS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _Colors.secondaryText,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            _buildSentryInsights(trends),
            const SizedBox(height: 24),
          ],

          // Smart Tips
          const Text(
            'SMART TIPS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _Colors.secondaryText,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildSmartTips(tips),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  List<ThreatCount> _buildThreatPie(List<ScanResult> scans) {
    if (scans.isEmpty) {
      return [];
    }

    final counts = <String, int>{
      'safe': 0,
      'suspicious': 0,
      'malicious': 0,
    };

    for (final scan in scans) {
      final key = _pieChartCategory(scan.threatType);
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final total = scans.length;
    final entries = counts.entries.toList()
      ..removeWhere((entry) => entry.value == 0)
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries
        .map(
          (entry) => ThreatCount(
            threatType: entry.key,
            count: entry.value,
            percentage: (entry.value / total) * 100,
          ),
        )
        .toList();
  }

  List<ScanResult> _oldestSafeLinksNotRescanned(List<ScanResult> scans) {
    final occurrences = <String, int>{};
    for (final scan in scans) {
      final url = scan.url.trim();
      if (url.isEmpty) continue;
      occurrences[url] = (occurrences[url] ?? 0) + 1;
    }

    final safeLinks = scans
        .where(
          (scan) =>
              scan.threatType == 'benign' &&
              scan.url.trim().isNotEmpty &&
              occurrences[scan.url.trim()] == 1,
        )
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return safeLinks.take(3).toList();
  }

  Color _threatColor(String threatType) {
    switch (threatType) {
      case 'safe':
        return _Colors.safe;
      case 'suspicious':
        return _Colors.mediumRisk;
      case 'malicious':
        return _Colors.highRisk;
      case 'phishing':
        return _Colors.highRisk;
      case 'malware':
        return _Colors.mediumRisk;
      case 'ad_tracker':
        return _Colors.primaryBlue;
      case 'benign':
        return _Colors.safe;
      default:
        return _Colors.primaryPurple;
    }
  }

  String _pieChartCategory(String threatType) {
    switch (threatType.toLowerCase()) {
      case 'benign':
      case 'safe':
        return 'safe';
      case 'malware':
      case 'malicious':
      case 'unsafe':
        return 'malicious';
      case 'phishing':
      case 'suspicious':
      case 'ad_tracker':
      default:
        return 'suspicious';
    }
  }

  Widget _buildThreatPieChart(List<ThreatCount> threatPercentages) {
    return Container(
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
            'THREAT TYPE PERCENTAGE',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _Colors.secondaryText,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 38,
                sections: threatPercentages
                    .map(
                      (threat) => PieChartSectionData(
                        color: _threatColor(threat.threatType),
                        value: threat.percentage,
                        radius: 54,
                        title: '${threat.percentage.toStringAsFixed(0)}%',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...threatPercentages.map(
            (threat) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _threatColor(threat.threatType),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _formatThreatLabel(threat.threatType),
                      style: const TextStyle(
                        color: _Colors.primaryText,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '${threat.count} scans • ${threat.percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: _Colors.secondaryText,
                      fontSize: 13,
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

  Widget _buildOldestSafeLinksChart(List<ScanResult> safeLinks) {
    final maxDays = safeLinks
            .map((scan) => DateTime.now().difference(scan.timestamp).inDays)
            .reduce((a, b) => a > b ? a : b)
            .toDouble() +
        1;

    return Container(
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
            'OLDEST SAFE LINKS NOT RESCANNED',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _Colors.secondaryText,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Based on safe links with only one recorded scan.',
            style: TextStyle(
              color: _Colors.secondaryText,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxDays,
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          color: _Colors.secondaryText,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= safeLinks.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: 90,
                            child: Text(
                              _shortUrlLabel(safeLinks[index].url),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _Colors.secondaryText,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(safeLinks.length, (index) {
                  final days =
                      DateTime.now().difference(safeLinks[index].timestamp).inDays;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: days.toDouble(),
                        width: 24,
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          colors: [_Colors.safe, _Colors.primaryBlue],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...safeLinks.map(
            (scan) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${_shortUrlLabel(scan.url)} • ${DateTime.now().difference(scan.timestamp).inDays} days since last safe scan',
                style: const TextStyle(
                  color: _Colors.secondaryText,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shortUrlLabel(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host;
    if (host != null && host.isNotEmpty) {
      return host;
    }
    return url;
  }

  Widget _buildRiskProfileCard(UserInsights insights) {
    final profile = insights.riskProfile;
    final Color accentColor = switch (profile.level) {
      'high' => _Colors.highRisk,
      'moderate' => _Colors.mediumRisk,
      _ => _Colors.safe,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _Colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withAlpha(90),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: accentColor),
              const SizedBox(width: 8),
              Text(
                'Risk Profile',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${profile.score.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Level: ${profile.level.toUpperCase()}',
            style: const TextStyle(
              color: _Colors.primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            profile.description,
            style: const TextStyle(
              color: _Colors.secondaryText,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Scans analyzed: ${insights.totalScans}',
            style: const TextStyle(
              color: _Colors.secondaryText,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Top Threats List
  // --------------------------------------------------------------------------
  Widget _buildThreatList(List<ThreatCount> topThreats) {
    if (topThreats.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _Colors.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'No threat patterns detected in this period. Most recent scans look safe.',
          style: TextStyle(color: _Colors.secondaryText),
        ),
      );
    }

    // Map threat types to colors
    final threatColors = {
      'phishing': _Colors.highRisk,
      'malware': _Colors.mediumRisk,
      'ad_tracker': _Colors.primaryBlue,
      'benign': _Colors.safe,
      'defacement': _Colors.primaryPurple,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ...topThreats.map((threat) => _buildThreatItem(
            _formatThreatLabel(threat.threatType),
            threat.count,
            threatColors[threat.threatType] ?? _Colors.primaryPurple,
          )),
          if (topThreats.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Generate a summary sentence based on top threat
            Text(
              _getTopThreatSummary(topThreats.first),
              style: const TextStyle(
                color: _Colors.secondaryText,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getTopThreatSummary(ThreatCount top) {
    if (top.threatType == 'phishing') {
      return 'Phishing is your most common risk. Most of these URLs are fake login pages.';
    } else if (top.threatType == 'malware') {
      return 'Malware is your top threat. Avoid downloading files from untrusted sources.';
    } else if (top.threatType == 'benign') {
      return 'Most of your recent scans were safe. Keep up those careful browsing habits.';
    } else if (top.threatType == 'ad_tracker') {
      return 'Ad trackers are frequent. Consider using a privacy-focused browser.';
    } else {
      return '${_formatThreatLabel(top.threatType)} is your most common threat. Stay cautious.';
    }
  }

  String _formatThreatLabel(String threatType) {
    switch (threatType) {
      case 'safe':
        return 'Safe';
      case 'suspicious':
        return 'Suspicious';
      case 'malicious':
        return 'Malicious';
      case 'ad_tracker':
        return 'Ad Tracker';
      case 'benign':
        return 'Safe';
      default:
        if (threatType.isEmpty) {
          return 'Unknown';
        }
        return threatType[0].toUpperCase() + threatType.substring(1);
    }
  }

  Widget _buildThreatItem(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _Colors.primaryText,
                fontSize: 16,
              ),
            ),
          ),
          Text(
            '· $count times',
            style: const TextStyle(
              color: _Colors.secondaryText,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Sentry Insights (Trends)
  // --------------------------------------------------------------------------
  Widget _buildSentryInsights(List<ThreatTrend> trends) {
    if (trends.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: trends.map((trend) {
          final icon = trend.direction == 'up' ? Icons.arrow_upward : Icons.arrow_downward;
          final color = trend.direction == 'up' ? _Colors.highRisk : _Colors.safe;
          final change = trend.changePercent.toStringAsFixed(0);
          final text = trend.direction == 'up'
              ? '${trend.threatType} is up $change% compared to last period'
              : '${trend.threatType} is down $change% compared to last period';
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildInsightItem(icon: icon, iconColor: color, text: text),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInsightItem({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _Colors.primaryText,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Smart Tips
  // --------------------------------------------------------------------------
  Widget _buildSmartTips(List<SmartTip> tips) {
    if (tips.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _Colors.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'No tips available.',
          style: TextStyle(color: _Colors.secondaryText),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: tips.map((tip) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildTipItem(text: tip.message),
        )).toList(),
      ),
    );
  }

  Widget _buildTipItem({required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lightbulb_outline, color: _Colors.primaryPurple, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _Colors.primaryText,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
