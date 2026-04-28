import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/app_colors.dart';
import '../services/ai_threat_analyzer.dart';

class SecurityInsightsScreen extends StatefulWidget {
  const SecurityInsightsScreen({super.key});

  @override
  State<SecurityInsightsScreen> createState() => _SecurityInsightsScreenState();
}

class _SecurityInsightsScreenState extends State<SecurityInsightsScreen>
    with SingleTickerProviderStateMixin {
  UserInsights? _insights;
  List<ScanResult> _scans = [];
  bool _isLoading = true;
  String? _error;
  int _periodDays = 30;
  late AnimationController _animationController;

  final List<int> _periodOptions = [7, 30, 90, 0];
  final Map<int, String> _periodLabels = {
    7: 'Last 7 days',
    30: 'Last 30 days',
    90: 'Last 90 days',
    0: 'All time',
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _loadInsights();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadInsights() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You need to be signed in to view security insights.');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userName = (userDoc.data()?['firstName']?.toString().trim().isNotEmpty ?? false)
          ? userDoc.data()!['firstName'].toString().trim()
          : (user.displayName?.trim().isNotEmpty ?? false)
              ? user.displayName!.trim()
              : 'User';

      Query query = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('scans')
          .orderBy('scannedAt', descending: true);

      if (_periodDays > 0) {
        final cutoff = DateTime.now().subtract(Duration(days: _periodDays));
        query = query.where('scannedAt', isGreaterThanOrEqualTo: cutoff);
      }

      final scansSnapshot = await query.get();

      final scans = scansSnapshot.docs
          .map((doc) => _scanResultFromFirestore(doc.data() as Map<String, dynamic>))
          .toList();

      final insights = AIThreatAnalyzer.analyze(
        userName,
        scans,
        periodDays: _periodDays,
      );

      if (!mounted) return;
      setState(() {
        _insights = insights;
        _scans = scans;
        _isLoading = false;
      });
      _animationController.forward(from: 0);
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
    if (value is num) return value.toDouble();
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

  // ================= NEW: PREDICTION CARD =================
  Widget _buildPredictionCard() {
    if (_scans.isEmpty) return const SizedBox.shrink();

    // Group scans by threat type and compute average gap between occurrences
    final Map<String, List<DateTime>> threatDates = {};
    for (final scan in _scans) {
      if (scan.threatType == 'benign') continue;
      threatDates.putIfAbsent(scan.threatType, () => []);
      threatDates[scan.threatType]!.add(scan.timestamp);
    }
    if (threatDates.isEmpty) return const SizedBox.shrink();

    // Find most frequent (or most recent) threat type
    String? mostCommonThreat;
    int maxCount = 0;
    for (final entry in threatDates.entries) {
      if (entry.value.length > maxCount) {
        maxCount = entry.value.length;
        mostCommonThreat = entry.key;
      }
    }
    if (mostCommonThreat == null) return const SizedBox.shrink();

    final dates = threatDates[mostCommonThreat]!..sort();
    if (dates.length < 2) return const SizedBox.shrink();

    // Calculate average days between occurrences
    int totalGap = 0;
    for (int i = 1; i < dates.length; i++) {
      totalGap += dates[i].difference(dates[i - 1]).inDays;
    }
    final avgGap = totalGap / (dates.length - 1);
    final lastDate = dates.last;
    final daysSinceLast = DateTime.now().difference(lastDate).inDays;
    int predictedDays = (avgGap - daysSinceLast).ceil();
    if (predictedDays < 1) predictedDays = 1;

    final threatLabel = _formatThreatLabel(mostCommonThreat);
    final predictionText = predictedDays <= 1
        ? 'Based on your history, you may encounter $threatLabel very soon (within 1 day).'
        : 'Based on your history, you may encounter $threatLabel in about $predictedDays days.';

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: AppColors.primaryPurple, size: 20),
              const SizedBox(width: 8),
              const Text('Risk Prediction',
                  style: TextStyle(color: AppColors.primaryText, fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Text(predictionText, style: const TextStyle(color: AppColors.secondaryText, fontSize: 14, height: 1.4)),
          const SizedBox(height: 8),
          Text('Stay vigilant – avoid clicking suspicious links.',
              style: TextStyle(color: AppColors.primaryPurple.withOpacity(0.7), fontSize: 12)),
        ],
      ),
    );
  }

  // ================= NEW: THREAT GROUPING BOTTOM SHEET =================
  void _showThreatGroupBottomSheet(String threatType) {
    // Find all scans of this threat type
    final groupedScans = _scans.where((scan) => scan.threatType == threatType).toList();
    if (groupedScans.isEmpty) return;

    // Group by domain (similarity reason)
    final Map<String, List<ScanResult>> byDomain = {};
    for (final scan in groupedScans) {
      final domain = _extractDomain(scan.url);
      byDomain.putIfAbsent(domain, () => []).add(scan);
    }

    String similarityReason;
    if (byDomain.keys.length == 1) {
      similarityReason = 'All these links share the same domain "$_extractDomain(groupedScans.first.url)".';
    } else {
      similarityReason = 'These links were all classified as $threatType by our threat engine.';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              width: 50,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatThreatLabel(threatType),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryText),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$similarityReason\nTap any link to view details.',
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: navigate to ViewHistoryScreen with filter
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('View All in History'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.divider),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: groupedScans.length,
                itemBuilder: (context, index) {
                  final scan = groupedScans[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    color: AppColors.mainBackground,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      title: Text(_extractDomain(scan.url),
                          style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w600)),
                      subtitle: Text(scan.url,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.secondaryText),
                      onTap: () {
                        // Navigate to scan details – you can push ScanResultDetailsScreen here
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Open scan details – feature coming soon')),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceAll(RegExp(r'^www\.'), '');
    } catch (_) {
      return url.split('/').first;
    }
  }

  // ================= EXISTING METHODS (modified for grouping) =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Security Insights', style: TextStyle(color: AppColors.primaryText)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.date_range, color: AppColors.primaryText),
            onSelected: (value) {
              setState(() {
                _periodDays = value;
                _loadInsights();
              });
            },
            itemBuilder: (context) => _periodOptions.map((days) {
              return PopupMenuItem(value: days, child: Text(_periodLabels[days]!));
            }).toList(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _scans.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadInsights,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildGreeting(),
                            const SizedBox(height: 16),
                            _buildStatsCard(),
                            const SizedBox(height: 24),
                            _buildRiskProfileCard(),
                            const SizedBox(height: 24),
                            _buildThreatPieSection(),
                            const SizedBox(height: 24),
                            _buildRiskOverTimeChart(),
                            const SizedBox(height: 24),
                            _buildPredictionCard(), // NEW
                            const SizedBox(height: 24),
                            _buildOldestSafeLinksSection(),
                            const SizedBox(height: 24),
                            _buildTopThreatsSection(), // modified to be tappable
                            const SizedBox(height: 24),
                            _buildTrendsSection(),
                            const SizedBox(height: 24),
                            _buildSmartTipsSection(),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppColors.highRisk, size: 48),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppColors.secondaryText), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadInsights, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: AppColors.secondaryText),
            const SizedBox(height: 16),
            const Text('No scans yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryText)),
            const SizedBox(height: 8),
            const Text('Scan your first link to see security insights.', style: TextStyle(color: AppColors.secondaryText), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Start Scanning'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final userName = _insights?.userName ?? 'User';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your Security Insights', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryText)),
        const SizedBox(height: 4),
        Text('Hi $userName! Based on your last ${_periodDays == 0 ? 'all scans' : '$_periodDays days'}', style: const TextStyle(fontSize: 16, color: AppColors.secondaryText)),
      ],
    );
  }

  Widget _buildStatsCard() {
    final totalScans = _insights?.totalScans ?? 0;
    double avgRisk = 0;
    if (_scans.isNotEmpty) {
      double sum = 0;
      for (final scan in _scans) sum += scan.riskScore;
      avgRisk = sum / _scans.length;
    }
    final maxRisk = _insights?.riskScoreMax ?? 0;
    return _buildCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Total Scans', totalScans.toString()),
          Container(width: 1, height: 40, color: AppColors.divider),
          _statItem('Avg Risk', '${avgRisk.toStringAsFixed(0)}%'),
          Container(width: 1, height: 40, color: AppColors.divider),
          _statItem('Highest Risk', '${maxRisk.toStringAsFixed(0)}%'),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryText)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
      ],
    );
  }

  Widget _buildRiskProfileCard() {
    final insights = _insights!;
    final profile = insights.riskProfile;
    final Color accentColor = switch (profile.level) {
      'critical' => AppColors.highRisk,
      'high' => AppColors.highRisk,
      'moderate' => AppColors.mediumRisk,
      _ => AppColors.safe,
    };
    return _buildCard(
      borderColor: accentColor.withOpacity(0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: accentColor),
              const SizedBox(width: 8),
              Text('Risk Profile', style: TextStyle(color: accentColor, fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${profile.score.toStringAsFixed(0)}%', style: TextStyle(color: accentColor, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Level: ${profile.level.toUpperCase()}', style: const TextStyle(color: AppColors.primaryText, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(profile.description, style: const TextStyle(color: AppColors.secondaryText, fontSize: 14, height: 1.4)),
          const SizedBox(height: 12),
          Text('Scans analyzed: ${insights.totalScans}', style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
        ],
      ),
    );
  }

  // MODIFIED PIE CHART: tap navigates to grouping
  Widget _buildThreatPieSection() {
    final threatPercentages = _buildThreatPie(_scans);
    if (threatPercentages.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('THREAT DISTRIBUTION', Icons.pie_chart),
        const SizedBox(height: 12),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: 'Pie chart showing threat type distribution. ${threatPercentages.map((t) => '${_formatThreatLabel(t.threatType)}: ${t.percentage.toStringAsFixed(0)} percent').join(', ')}',
                child: SizedBox(
                  height: 220,
                  child: FadeTransition(
                    opacity: _animationController,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 38,
                        sections: threatPercentages.map((threat) => PieChartSectionData(
                          color: _threatColor(threat.threatType),
                          value: threat.percentage,
                          radius: 54,
                          title: '${threat.percentage.toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        )).toList(),
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            if (event is FlTapUpEvent && pieTouchResponse != null) {
                              final touchedIndex = pieTouchResponse.touchedSection?.touchedSectionIndex;
                              if (touchedIndex != null && touchedIndex != -1) {
                                final threat = threatPercentages[touchedIndex];
                                _showThreatGroupBottomSheet(threat.threatType);
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...threatPercentages.map((threat) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: _threatColor(threat.threatType), shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_formatThreatLabel(threat.threatType), style: const TextStyle(color: AppColors.primaryText, fontSize: 14))),
                    Text('${threat.count} scans • ${threat.percentage.toStringAsFixed(1)}%', style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
                  ],
                ),
              )),
            ],
          ),
        ),
      ],
    );
  }

  // Risk over time chart (unchanged)
  Widget _buildRiskOverTimeChart() {
    if (_scans.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: _periodDays));
    final filteredScans = _scans.where((s) => s.timestamp.isAfter(cutoff)).toList();
    if (filteredScans.isEmpty) return const SizedBox.shrink();

    final oldest = filteredScans.map((s) => s.timestamp).reduce((a, b) => a.isBefore(b) ? a : b);
    final startDate = oldest.isBefore(cutoff) ? cutoff : oldest;
    final weeks = ((now.difference(startDate).inDays / 7).ceil()).clamp(1, 12);
    final Map<int, double> weeklyAvg = {};
    for (int i = 0; i < weeks; i++) {
      final weekStart = startDate.add(Duration(days: i * 7));
      final weekEnd = weekStart.add(const Duration(days: 7));
      final weekScans = filteredScans.where((s) => s.timestamp.isAfter(weekStart) && s.timestamp.isBefore(weekEnd)).toList();
      if (weekScans.isNotEmpty) {
        final avg = weekScans.map((s) => s.riskScore).reduce((a, b) => a + b) / weekScans.length;
        weeklyAvg[i] = avg;
      } else {
        weeklyAvg[i] = i > 0 ? weeklyAvg[i-1]! : 0;
      }
    }

    final spots = weeklyAvg.entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
    final maxY = weeklyAvg.values.reduce((a, b) => a > b ? a : b).ceilToDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('RISK TREND', Icons.trending_up),
        const SizedBox(height: 12),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Average risk score per week', style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) {
                      return FlLine(color: AppColors.divider.withOpacity(0.3), strokeWidth: 1);
                    }),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) => Text('${value.toInt()}%', style: const TextStyle(color: AppColors.secondaryText, fontSize: 10)),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final week = value.toInt();
                            if (week < 0 || week >= weeks) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('Week ${week+1}', style: const TextStyle(color: AppColors.secondaryText, fontSize: 10)),
                            );
                          },
                          reservedSize: 30,
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: AppColors.primaryPurple,
                        barWidth: 3,
                        belowBarData: BarAreaData(show: true, color: AppColors.primaryPurple.withOpacity(0.1)),
                        dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: AppColors.primaryPurple,
                            strokeWidth: 0,
                          );
                        }),
                      ),
                    ],
                    minY: 0,
                    maxY: maxY > 0 ? maxY : 100,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOldestSafeLinksSection() {
    final safeLinks = _oldestSafeLinksNotRescanned(_scans);
    if (safeLinks.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('OLDEST SAFE LINKS', Icons.history),
          const SizedBox(height: 12),
          _buildCard(
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('All your safe links are up to date. Great job!', style: TextStyle(color: AppColors.secondaryText)),
            ),
          ),
        ],
      );
    }
    final maxDays = safeLinks.map((scan) => DateTime.now().difference(scan.timestamp).inDays).reduce((a, b) => a > b ? a : b).toDouble() + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('OLDEST SAFE LINKS', Icons.history),
        const SizedBox(height: 12),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Safe links that have not been rescanned (older than 7 days)', style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
              const SizedBox(height: 16),
              Semantics(
                label: 'Bar chart showing days since last scan for each safe link.',
                child: SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxDays,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final days = rod.toY.toInt();
                            return BarTooltipItem('$days days\n${_shortUrlLabel(safeLinks[groupIndex].url)}', const TextStyle(color: Colors.white));
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= safeLinks.length) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: SizedBox(
                                  width: 90,
                                  child: Text(_shortUrlLabel(safeLinks[index].url), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: List.generate(safeLinks.length, (index) {
                        final days = DateTime.now().difference(safeLinks[index].timestamp).inDays;
                        return BarChartGroupData(
                          x: index,
                          barRods: [BarChartRodData(toY: days.toDouble(), width: 24, borderRadius: BorderRadius.circular(6), gradient: const LinearGradient(colors: [AppColors.safe, AppColors.primaryBlue]))],
                        );
                      }),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...safeLinks.map((scan) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${_shortUrlLabel(scan.url)} • ${DateTime.now().difference(scan.timestamp).inDays} days ago', style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
              )),
            ],
          ),
        ),
      ],
    );
  }

  // MODIFIED TOP THREATS: tappable
  Widget _buildTopThreatsSection() {
    final topThreats = _insights?.topThreats ?? [];
    if (topThreats.isEmpty) return const SizedBox.shrink();
    final totalScans = _insights?.totalScans ?? _scans.length;
    final threatColors = {
      'phishing': AppColors.highRisk,
      'malware': AppColors.highRisk,
      'ad_tracker': AppColors.primaryBlue,
      'benign': AppColors.safe,
      'suspicious': AppColors.mediumRisk,
      'defacement': AppColors.primaryPurple,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('TOP THREATS', Icons.warning),
        const SizedBox(height: 12),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...topThreats.map((threat) => GestureDetector(
                onTap: () => _showThreatGroupBottomSheet(threat.threatType),
                child: _buildThreatItem(
                  _formatThreatLabel(threat.threatType),
                  threat.count,
                  threatColors[threat.threatType] ?? AppColors.primaryPurple,
                ),
              )),
              const SizedBox(height: 16),
              Text(_getDynamicTopThreatSummary(topThreats.first, totalScans), style: const TextStyle(color: AppColors.secondaryText, fontSize: 14, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }

  String _getDynamicTopThreatSummary(ThreatCount top, int totalScans) {
    final percentage = (top.count / totalScans * 100).toStringAsFixed(1);
    final count = top.count;
    final threat = _formatThreatLabel(top.threatType);
    return '$threat appears $count time${count == 1 ? '' : 's'} (${percentage}% of scans). ${_getThreatAdvice(top.threatType)}';
  }

  String _getThreatAdvice(String threatType) {
    switch (threatType) {
      case 'phishing':
        return 'Always verify the sender before clicking links, even if they look legitimate.';
      case 'malware':
        return 'Avoid downloading files from untrusted sources and keep your antivirus updated.';
      case 'ad_tracker':
        return 'Consider using a privacy-focused browser or an ad-blocker extension.';
      case 'benign':
        return 'Keep up the good habits, but stay vigilant – threats evolve quickly.';
      case 'suspicious':
        return 'Double-check URLs before clicking and avoid entering personal info on unfamiliar sites.';
      default:
        return 'Stay cautious and verify links before interacting.';
    }
  }

  Widget _buildTrendsSection() {
    final trends = _insights?.trends ?? [];
    if (trends.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('SENTRY INSIGHTS', Icons.trending_up),
        const SizedBox(height: 12),
        _buildCard(
          child: Column(
            children: trends.map((trend) {
              if (trend.threatType == 'benign') return const SizedBox.shrink();
              final icon = trend.direction == 'up' ? Icons.arrow_upward : Icons.arrow_downward;
              final color = trend.direction == 'up' ? AppColors.highRisk : AppColors.safe;
              final change = trend.changePercent.toStringAsFixed(0);
              final threatLabel = _formatThreatLabel(trend.threatType);
              final text = trend.direction == 'up'
                  ? '$threatLabel increased by $change% compared to last period'
                  : '$threatLabel decreased by $change% compared to last period';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildInsightItem(icon: icon, iconColor: color, text: text),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSmartTipsSection() {
    final tips = _insights?.smartTips ?? [];
    if (tips.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('SMART TIPS', Icons.lightbulb),
        const SizedBox(height: 12),
        _buildCard(
          child: Column(
            children: tips.map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildTipItem(text: tip.message),
            )).toList(),
          ),
        ),
      ],
    );
  }

  // Helper widgets (unchanged)
  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryPurple, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.secondaryText, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildCard({required Widget child, Color? borderColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? AppColors.divider.withOpacity(0.3), width: 1),
        boxShadow: [BoxShadow(color: AppColors.primaryPurple.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  Widget _buildThreatItem(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.primaryText, fontSize: 16))),
          Text('· $count time${count == 1 ? '' : 's'}', style: const TextStyle(color: AppColors.secondaryText, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildInsightItem({required IconData icon, required Color iconColor, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(color: AppColors.primaryText, fontSize: 14, height: 1.4))),
      ],
    );
  }

  Widget _buildTipItem({required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lightbulb_outline, color: AppColors.primaryPurple, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(color: AppColors.primaryText, fontSize: 14, height: 1.4))),
      ],
    );
  }

  List<ThreatCount> _buildThreatPie(List<ScanResult> scans) {
    if (scans.isEmpty) return [];
    final counts = <String, int>{'safe': 0, 'suspicious': 0, 'malicious': 0};
    for (final scan in scans) {
      final key = _pieChartCategory(scan.threatType);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final total = scans.length;
    final entries = counts.entries.toList()..removeWhere((entry) => entry.value == 0)..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((entry) => ThreatCount(threatType: entry.key, count: entry.value, percentage: (entry.value / total) * 100)).toList();
  }

  List<ScanResult> _oldestSafeLinksNotRescanned(List<ScanResult> scans) {
    final occurrences = <String, int>{};
    for (final scan in scans) {
      final url = scan.url.trim();
      if (url.isEmpty) continue;
      occurrences[url] = (occurrences[url] ?? 0) + 1;
    }
    final now = DateTime.now();
    final safeLinks = scans.where((scan) =>
        scan.threatType == 'benign' &&
        scan.url.trim().isNotEmpty &&
        occurrences[scan.url.trim()] == 1 &&
        now.difference(scan.timestamp).inDays > 7
    ).toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return safeLinks.take(3).toList();
  }

  String _shortUrlLabel(String url) {
    final uri = Uri.tryParse(url);
    String host = uri?.host ?? url;
    host = host.replaceAll(RegExp(r'^www\.'), '');
    return host;
  }

  Color _threatColor(String threatType) {
    switch (threatType) {
      case 'safe': return AppColors.safe;
      case 'suspicious': return AppColors.mediumRisk;
      case 'malicious': return AppColors.highRisk;
      case 'phishing': return AppColors.highRisk;
      case 'malware': return AppColors.highRisk;
      case 'ad_tracker': return AppColors.primaryBlue;
      case 'benign': return AppColors.safe;
      default: return AppColors.primaryPurple;
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
      case 'defacement':
      default:
        return 'suspicious';
    }
  }

  String _formatThreatLabel(String threatType) {
    switch (threatType) {
      case 'safe': return 'Safe';
      case 'suspicious': return 'Suspicious';
      case 'malicious': return 'Malicious';
      case 'phishing': return 'Phishing';
      case 'malware': return 'Malware';
      case 'ad_tracker': return 'Ad Tracker';
      case 'benign': return 'Safe';
      default: return threatType.isEmpty ? 'Unknown' : threatType[0].toUpperCase() + threatType.substring(1);
    }
  }
}