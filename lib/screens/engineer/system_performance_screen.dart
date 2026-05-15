import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';

class SystemPerformanceScreen extends StatefulWidget {
  const SystemPerformanceScreen({super.key});

  @override
  State<SystemPerformanceScreen> createState() => _SystemPerformanceScreenState();
}

class _SystemPerformanceScreenState extends State<SystemPerformanceScreen> {
  bool _loading = true;
  String? _error;

  // Summary stats
  int _scansToday = 0;
  int _threatsToday = 0;
  int _activeUsersToday = 0;
  int _pendingFalseReports = 0;

  // Verdict breakdown
  final Map<String, int> _verdictCounts = {
    'Safe': 0,
    'Low Risk': 0,
    'Suspicious': 0,
    'Malicious': 0,
  };

  // Top active users: uid -> scan count
  List<MapEntry<String, int>> _topUsers = [];

  // Recent scans feed
  List<Map<String, dynamic>> _recentScans = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayStartTs = Timestamp.fromDate(todayStart);

      // Run all queries in parallel
      final results = await Future.wait([
        // Today's scans (collectionGroup)
        FirebaseFirestore.instance
            .collectionGroup('scans')
            .where('scannedAt', isGreaterThanOrEqualTo: todayStartTs)
            .get(),
        // Recent 30 scans
        FirebaseFirestore.instance
            .collectionGroup('scans')
            .orderBy('scannedAt', descending: true)
            .limit(30)
            .get(),
        // Pending false reports
        FirebaseFirestore.instance
            .collection('false_reports')
            .where('status', isEqualTo: 'pending')
            .get(),
      ]);

      final todaySnap = results[0];
      final recentSnap = results[1];
      final falseReportsSnap = results[2];

      // Aggregate today's stats
      int threats = 0;
      final activeUsers = <String>{};
      final verdicts = <String, int>{'Safe': 0, 'Low Risk': 0, 'Suspicious': 0, 'Malicious': 0};
      final userScanCounts = <String, int>{};

      for (final doc in todaySnap.docs) {
        final data = doc.data();
        final verdict = data['verdict']?.toString() ?? 'Safe';
        final uid = doc.reference.parent.parent?.id ?? '';

        if (verdict == 'Malicious' || verdict == 'Suspicious') threats++;
        if (uid.isNotEmpty) activeUsers.add(uid);
        verdicts[verdict] = (verdicts[verdict] ?? 0) + 1;
        if (uid.isNotEmpty) userScanCounts[uid] = (userScanCounts[uid] ?? 0) + 1;
      }

      // Top 5 users by scan count today, sorted descending
      final topUsers = userScanCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Recent scans feed
      final recentScans = recentSnap.docs.map((doc) {
        final data = doc.data();
        final uid = doc.reference.parent.parent?.id ?? '';
        return {
          'url': data['url']?.toString() ?? '—',
          'verdict': data['verdict']?.toString() ?? '—',
          'riskScore': (data['riskScore'] as num?)?.toDouble() ?? 0.0,
          'scannedAt': data['scannedAt'],
          'uid': uid,
        };
      }).toList();

      setState(() {
        _scansToday = todaySnap.docs.length;
        _threatsToday = threats;
        _activeUsersToday = activeUsers.length;
        _pendingFalseReports = falseReportsSnap.docs.length;
        _verdictCounts.addAll(verdicts);
        _topUsers = topUsers.take(5).toList();
        _recentScans = recentScans;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _formatTs(dynamic ts) {
    if (ts is Timestamp) return DateFormat('hh:mm a').format(ts.toDate());
    return '—';
  }

  Color _verdictColor(String verdict) {
    switch (verdict) {
      case 'Malicious': return AppColors.highRisk;
      case 'Suspicious': return AppColors.mediumRisk;
      case 'Low Risk': return Colors.orangeAccent;
      default: return AppColors.safe;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1380),
          child: _loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppColors.primaryPurple),
                    ),
                  ),
                )
              : _error != null
                  ? Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 80),
                          Icon(Icons.error_outline, color: AppColors.highRisk, size: 40),
                          const SizedBox(height: 12),
                          Text('Failed to load data: $_error',
                              style: const TextStyle(color: AppColors.highRisk)),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _loadData,
                            child: const Text('Retry', style: TextStyle(color: AppColors.primaryPurple)),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        _buildSummaryRow(),
                        const SizedBox(height: 18),
                        _buildVerdictBreakdown(),
                        const SizedBox(height: 18),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 900;
                            if (isWide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 5, child: _buildTopUsersPanel()),
                                  const SizedBox(width: 16),
                                  Expanded(flex: 7, child: _buildRecentFeed()),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                _buildTopUsersPanel(),
                                const SizedBox(height: 16),
                                _buildRecentFeed(),
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

  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('System Activity Monitor',
                  style: TextStyle(color: AppColors.primaryText, fontSize: 20, fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('Live data — today\'s scan activity and threat detection',
                  style: TextStyle(color: AppColors.secondaryText, fontSize: 13)),
            ],
          ),
        ),
        IconButton(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh_rounded, color: AppColors.secondaryText),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildSummaryRow() {
    return Row(
      children: [
        _statCard(Icons.qr_code_scanner_rounded, 'Scans Today', '$_scansToday', AppColors.primaryPurple),
        const SizedBox(width: 12),
        _statCard(Icons.warning_amber_rounded, 'Threats Detected', '$_threatsToday',
            _threatsToday > 0 ? AppColors.highRisk : AppColors.safe),
        const SizedBox(width: 12),
        _statCard(Icons.people_outline_rounded, 'Active Users', '$_activeUsersToday', AppColors.safe),
        const SizedBox(width: 12),
        _statCard(Icons.flag_outlined, 'Pending Reports', '$_pendingFalseReports',
            _pendingFalseReports > 0 ? AppColors.mediumRisk : AppColors.secondaryText),
      ],
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: const TextStyle(
                          color: AppColors.primaryText, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerdictBreakdown() {
    final total = _verdictCounts.values.fold(0, (a, b) => a + b);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Verdict Breakdown — Today',
              style: TextStyle(color: AppColors.primaryText, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ..._verdictCounts.entries.map((entry) {
            final frac = total > 0 ? entry.value / total : 0.0;
            final color = _verdictColor(entry.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(entry.key,
                          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('${entry.value}  (${(frac * 100).toStringAsFixed(1)}%)',
                          style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: frac,
                      minHeight: 8,
                      backgroundColor: AppColors.mainBackground,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTopUsersPanel() {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Active Users — Today',
              style: TextStyle(color: AppColors.primaryText, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('High scan counts may indicate automated or abnormal usage.',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
          const SizedBox(height: 16),
          if (_topUsers.isEmpty)
            const Text('No scan activity today.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 13))
          else
            ..._topUsers.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final uid = entry.value.key;
              final count = entry.value.value;
              final isAnomalous = count >= 20;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.mainBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isAnomalous
                        ? AppColors.highRisk.withValues(alpha: 0.4)
                        : AppColors.divider.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Text('#$rank',
                          style: const TextStyle(
                              color: AppColors.primaryPurple, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(uid,
                          style: const TextStyle(
                              color: AppColors.primaryText, fontSize: 12, fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    if (isAnomalous)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(Icons.warning_amber_rounded, color: AppColors.highRisk, size: 16),
                      ),
                    Text('$count scans',
                        style: TextStyle(
                            color: isAnomalous ? AppColors.highRisk : AppColors.secondaryText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRecentFeed() {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Scan Activity',
              style: TextStyle(color: AppColors.primaryText, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (_recentScans.isEmpty)
            const Text('No scans yet.', style: TextStyle(color: AppColors.secondaryText, fontSize: 13))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentScans.length,
              separatorBuilder: (_, i) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final scan = _recentScans[index];
                final verdict = scan['verdict'] as String;
                final color = _verdictColor(verdict);
                final score = (scan['riskScore'] as double).toStringAsFixed(1);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.mainBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(scan['url'] as String,
                            style: const TextStyle(color: AppColors.primaryText, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withValues(alpha: 0.4)),
                        ),
                        child: Text(verdict,
                            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 38,
                        child: Text(score,
                            textAlign: TextAlign.right,
                            style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: Text(_formatTs(scan['scannedAt']),
                            textAlign: TextAlign.right,
                            style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryPurple.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
