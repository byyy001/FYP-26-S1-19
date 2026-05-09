import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';

class ScanStatisticsScreen extends StatefulWidget {
  const ScanStatisticsScreen({super.key});

  @override
  State<ScanStatisticsScreen> createState() => _ScanStatisticsScreenState();
}

class _ScanStatisticsScreenState extends State<ScanStatisticsScreen> {
  String _selectedRange = 'Last 7 Days';
  final List<String> _dateRanges = ['Last 7 Days', 'Last 30 Days', 'Last 90 Days', 'All time'];

  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    setState(() {
      _statsFuture = _fetchStatistics();
    });
  }

  Future<Map<String, dynamic>> _fetchStatistics() async {
    try {
      DateTime startDate;
      int daysInRange;
      switch (_selectedRange) {
        case 'Last 7 Days':
          startDate = DateTime.now().subtract(const Duration(days: 7));
          daysInRange = 7;
          break;
        case 'Last 30 Days':
          startDate = DateTime.now().subtract(const Duration(days: 30));
          daysInRange = 30;
          break;
        case 'Last 90 Days':
          startDate = DateTime.now().subtract(const Duration(days: 90));
          daysInRange = 90;
          break;
        default:
          startDate = DateTime(2000);
          daysInRange = DateTime.now().difference(DateTime(2000)).inDays.clamp(1, 99999);
      }

      Query query = FirebaseFirestore.instance.collectionGroup('scans');
      if (_selectedRange != 'All time') {
        query = query.where('scannedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      final snapshot = await query.get();

      final scans = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

      int total = scans.length;
      int highRisk = 0;
      int mediumRisk = 0;
      int lowRisk = 0;
      Map<String, int> threatCounts = {};
      final Map<String, int> chartCounts = {};
      final List<String> chartLabels = [];
      String chartTitle;

      final now = DateTime.now();

      if (_selectedRange == 'Last 7 Days') {
        chartTitle = 'Daily Scans (Last 7 Days)';
        for (int i = 6; i >= 0; i--) {
          final day = now.subtract(Duration(days: i));
          final key = '${day.day}/${day.month}';
          chartCounts[key] = 0;
          chartLabels.add(key);
        }
      } else if (_selectedRange == 'Last 30 Days') {
        chartTitle = 'Weekly Scans (Last 30 Days)';
        for (int i = 3; i >= 0; i--) {
          final weekStart = now.subtract(Duration(days: (i + 1) * 7));
          final key = '${weekStart.day}/${weekStart.month}';
          chartCounts[key] = 0;
          chartLabels.add(key);
        }
      } else if (_selectedRange == 'Last 90 Days') {
        chartTitle = 'Monthly Scans (Last 90 Days)';
        for (int i = 2; i >= 0; i--) {
          final month = DateTime(now.year, now.month - i, 1);
          final key = _monthLabel(month.month);
          chartCounts[key] = 0;
          chartLabels.add(key);
        }
      } else {
        chartTitle = 'Monthly Scans (Last 12 Months)';
        for (int i = 11; i >= 0; i--) {
          final month = DateTime(now.year, now.month - i, 1);
          final key = _monthLabel(month.month);
          chartCounts[key] = 0;
          chartLabels.add(key);
        }
      }

      for (var scan in scans) {
        final risk = (scan['riskScore'] as num?)?.toDouble() ?? 0;
        if (risk >= 75) highRisk++;
        else if (risk >= 50) mediumRisk++;
        else lowRisk++;

        final threat = scan['threatType']?.toString().toLowerCase() ?? 'unknown';
        threatCounts[threat] = (threatCounts[threat] ?? 0) + 1;

        final timestamp = scan['scannedAt'] as Timestamp?;
        if (timestamp != null) {
          final date = timestamp.toDate();
          final String bucketKey;

          if (_selectedRange == 'Last 7 Days') {
            bucketKey = '${date.day}/${date.month}';
          } else if (_selectedRange == 'Last 30 Days') {
            final daysAgo = now.difference(date).inDays.clamp(0, 27);
            final weekIndex = (daysAgo / 7).floor();
            final weekStart = now.subtract(Duration(days: (weekIndex + 1) * 7));
            bucketKey = '${weekStart.day}/${weekStart.month}';
          } else {
            bucketKey = _monthLabel(date.month);
          }

          if (chartCounts.containsKey(bucketKey)) {
            chartCounts[bucketKey] = (chartCounts[bucketKey] ?? 0) + 1;
          }
        }
      }

      double avgPerDay = total / daysInRange;
      String peakPeriod = chartCounts.entries.isEmpty
          ? 'N/A'
          : chartCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      String mostCommonThreat = threatCounts.entries.isEmpty
          ? 'None'
          : threatCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

      final List<double> chartValues = chartLabels.map((k) => (chartCounts[k] ?? 0).toDouble()).toList();
      double maxChart = chartValues.isEmpty ? 1 : chartValues.reduce((a, b) => a > b ? a : b);
      final normalizedChart = chartValues.map((v) => maxChart > 0 ? (v / maxChart) * 200 : 0.0).toList();

      final List<Map<String, dynamic>> distribution = [];
      final sortedThreats = threatCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      for (var entry in sortedThreats.take(4)) {
        double percent = total > 0 ? (entry.value / total) * 100 : 0;
        distribution.add({
          'label': _formatThreatLabel(entry.key),
          'percent': percent,
          'widthFactor': percent / 100,
        });
      }

      return {
        'total': total,
        'highRisk': highRisk,
        'mediumRisk': mediumRisk,
        'lowRisk': lowRisk,
        'avgPerDay': avgPerDay,
        'peakDay': peakPeriod,
        'mostCommonThreat': _formatThreatLabel(mostCommonThreat),
        'dailyLabels': chartLabels,
        'dailyValues': normalizedChart,
        'chartTitle': chartTitle,
        'distribution': distribution,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  String _monthLabel(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _formatThreatLabel(String type) {
    switch (type) {
      case 'phishing': return 'Phishing';
      case 'malware': return 'Malware';
      case 'defacement': return 'Defacement';
      case 'benign': return 'Benign';
      default: return type[0].toUpperCase() + type.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateFilterCard(),
              const SizedBox(height: 20),
              FutureBuilder<Map<String, dynamic>>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple));
                  }
                  if (snapshot.hasError || (snapshot.data?.containsKey('error') ?? false)) {
                    return _buildErrorCard(snapshot.error?.toString() ?? 'Failed to load statistics');
                  }
                  final data = snapshot.data!;
                  return Column(
                    children: [
                      _buildSummaryStatsCard(data),
                      const SizedBox(height: 20),
                      _buildDailyScansCard(data),
                      const SizedBox(height: 20),
                      _buildThreatDistributionCard(data),
                      const SizedBox(height: 24),
                      _buildExportButton(data),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilterCard() {
    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          const Icon(Icons.date_range_outlined, color: AppColors.secondaryText),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Date Range', style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                const SizedBox(height: 4),
                DropdownButton<String>(
                  value: _selectedRange,
                  dropdownColor: AppColors.cardBackground,
                  underline: const SizedBox(),
                  style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w700, fontSize: 15),
                  items: _dateRanges.map((range) {
                    return DropdownMenuItem(value: range, child: Text(range));
                  }).toList(),
                  onChanged: (newRange) {
                    if (newRange != null) {
                      setState(() {
                        _selectedRange = newRange;
                        _loadStats();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return _Panel(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text('Error: $message', style: const TextStyle(color: AppColors.highRisk)),
        ),
      ),
    );
  }

  Widget _buildSummaryStatsCard(Map<String, dynamic> data) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Summary', style: TextStyle(color: AppColors.primaryText, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          _SummaryLine(label: 'Total Scans', value: '${data['total']}'),
          const SizedBox(height: 14),
          _SummaryLine(label: 'High Risk', value: '${data['highRisk']}'),
          const SizedBox(height: 14),
          _SummaryLine(label: 'Medium Risk', value: '${data['mediumRisk']}'),
          const SizedBox(height: 14),
          _SummaryLine(label: 'Low Risk', value: '${data['lowRisk']}'),
          const SizedBox(height: 14),
          _SummaryLine(label: 'Average Scans Per Day', value: data['avgPerDay'].toStringAsFixed(0)),
          const SizedBox(height: 14),
          _SummaryLine(label: 'Peak Scan Day', value: data['peakDay']),
          const SizedBox(height: 14),
          _SummaryLine(label: 'Most Common Threat Type', value: data['mostCommonThreat']),
        ],
      ),
    );
  }

  Widget _buildDailyScansCard(Map<String, dynamic> data) {
    final labels = data['dailyLabels'] as List<String>;
    final values = data['dailyValues'] as List<double>;
    final chartTitle = data['chartTitle'] as String? ?? 'Scan Activity';
    if (labels.isEmpty) return const SizedBox.shrink();
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(chartTitle, style: const TextStyle(color: AppColors.primaryText, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Container(
            height: 280,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryPurple.withValues(alpha: 0.35)),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(5, (index) => Container(height: 1, color: Colors.white10)),
                        ),
                      ),
                      Positioned.fill(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(values.length, (index) => _Bar(height: values[index])),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: labels.map((label) => SizedBox(
                    width: 40,
                    child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                  )).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreatDistributionCard(Map<String, dynamic> data) {
    final distribution = data['distribution'] as List<Map<String, dynamic>>;
    if (distribution.isEmpty) {
      return _Panel(
        child: const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No threat data available'))),
      );
    }
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Threat Type Distribution', style: TextStyle(color: AppColors.primaryText, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryPurple.withValues(alpha: 0.35)),
            ),
            child: Column(
              children: distribution.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _DistributionRow(
                    label: item['label'],
                    percent: '${item['percent'].toStringAsFixed(1)}%',
                    widthFactor: item['widthFactor'],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton(Map<String, dynamic> data) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: () {
          // Simple CSV export (you can integrate with file saver)
          final csv = _generateCSV(data);
          // ignore: avoid_print
          print(csv); // Replace with actual file save logic
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export feature - CSV generated (console)'), backgroundColor: AppColors.safe),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text('Export Report', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }

  String _generateCSV(Map<String, dynamic> data) {
    StringBuffer sb = StringBuffer();
    sb.writeln('Metric,Value');
    sb.writeln('Total Scans,${data['total']}');
    sb.writeln('High Risk,${data['highRisk']}');
    sb.writeln('Medium Risk,${data['mediumRisk']}');
    sb.writeln('Low Risk,${data['lowRisk']}');
    sb.writeln('Average Scans Per Day,${data['avgPerDay'].toStringAsFixed(0)}');
    sb.writeln('Peak Scan Day,${data['peakDay']}');
    sb.writeln('Most Common Threat Type,${data['mostCommonThreat']}');
    sb.writeln();
    sb.writeln('Threat Distribution');
    sb.writeln('Threat Type,Percentage');
    for (var item in data['distribution']) {
      sb.writeln('${item['label']},${item['percent'].toStringAsFixed(1)}%');
    }
    return sb.toString();
  }
}

// ---------- Reusable widgets (same as before) ----------
class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryLine({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 16, fontWeight: FontWeight.w500))),
        Text(value, style: const TextStyle(color: AppColors.primaryText, fontSize: 18, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _DistributionRow extends StatelessWidget {
  final String label;
  final String percent;
  final double widthFactor;
  const _DistributionRow({required this.label, required this.percent, required this.widthFactor});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w500))),
              Text(percent, style: const TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(height: 10, width: double.infinity, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(999))),
              Container(
                height: 10,
                width: constraints.maxWidth * widthFactor,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: AppColors.premiumGradient), borderRadius: BorderRadius.circular(999)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double height;
  const _Bar({required this.height});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: AppColors.premiumGradient),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _Panel({required this.child, this.padding});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryPurple.withValues(alpha: 0.35)),
        boxShadow: [BoxShadow(color: AppColors.primaryPurple.withValues(alpha: 0.14), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}