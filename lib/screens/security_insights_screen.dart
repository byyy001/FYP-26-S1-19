import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/ai_threat_analyzer.dart'; // Import the analyzer

// ============================================================================
// Color Palette (matches app_colors.dart)
// ============================================================================
class _Colors {
  static const Color mainBackground = Color(0xFF151515);
  static const Color cardBackground = Color(0xFF1A1F2E);
  static const Color primaryText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFFB3B8C5);
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color highRisk = Color(0xFFEF4444);
  static const Color mediumRisk = Color(0xFFF59E0B);
  static const Color safe = Color(0xFF22C55E);
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
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    try {
      // TODO: Replace with actual fetch of scan results from Firestore
      // For now, we'll simulate with an empty list (or you can provide mock data for testing)
      final List<ScanResult> mockScans = []; // Replace with real data later
      
      // If you want test data, you can create a few mock ScanResult objects here.
      
      final insights = AIThreatAnalyzer.analyze(
        'Jamie', // TODO: get actual user name from Firebase Auth
        mockScans,
        periodDays: 30,
      );
      
      setState(() {
        _insights = insights;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load insights: $e';
        _isLoading = false;
      });
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

          // Threat Distribution Chart (only if there are scans)
          if (insights.totalScans > 0) ...[
            _buildThreatChart(topThreats),
            const SizedBox(height: 24),
          ],

          // Top Threats
          const Text(
            'YOUR TOP THREATS',
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

  // --------------------------------------------------------------------------
  // Threat Distribution Bar Chart (Gradient)
  // --------------------------------------------------------------------------
  Widget _buildThreatChart(List<ThreatCount> topThreats) {
    // Map threat types to colors and ensure we have up to 3 bars
    final threatColors = {
      'phishing': _Colors.highRisk,
      'malware': _Colors.mediumRisk,
      'ad_tracker': _Colors.primaryBlue,
      'defacement': _Colors.primaryPurple, // fallback
    };

    // Create bar groups from top threats (up to 3)
    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < topThreats.length && i < 3; i++) {
      final threat = topThreats[i];
      final color = threatColors[threat.threatType] ?? _Colors.primaryPurple;
      barGroups.add(
        BarChartGroupData(x: i, barRods: [
          BarChartRodData(
            toY: threat.count.toDouble(),
            gradient: LinearGradient(
              colors: [color, _Colors.primaryPurple],
            ),
            width: 20,
            borderRadius: BorderRadius.circular(4),
          )
        ]),
      );
    }

    // If no threats, show placeholder
    if (barGroups.isEmpty) {
      return Container(
        height: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _Colors.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'No threat data available',
            style: TextStyle(color: _Colors.secondaryText),
          ),
        ),
      );
    }

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: topThreats.map((t) => t.count.toDouble()).reduce((a, b) => a > b ? a : b) + 2,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < topThreats.length) {
                    return Text(
                      topThreats[value.toInt()].threatType,
                      style: const TextStyle(
                        color: _Colors.secondaryText,
                        fontSize: 12,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
        ),
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
          'No threats detected in this period.',
          style: TextStyle(color: _Colors.secondaryText),
        ),
      );
    }

    // Map threat types to colors
    final threatColors = {
      'phishing': _Colors.highRisk,
      'malware': _Colors.mediumRisk,
      'ad_tracker': _Colors.primaryBlue,
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
            threat.threatType,
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
    } else if (top.threatType == 'ad_tracker') {
      return 'Ad trackers are frequent. Consider using a privacy-focused browser.';
    } else {
      return '${top.threatType} is your most common threat. Stay cautious.';
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