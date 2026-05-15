import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';

// ─── Simple data holder for monthly bar charts ───────────────────────────────
class _MonthPoint {
  final String label; // e.g. "Jan 25"
  final int value;
  const _MonthPoint(this.label, this.value);
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class MonthlyAppHealthScreen extends StatefulWidget {
  const MonthlyAppHealthScreen({super.key});

  @override
  State<MonthlyAppHealthScreen> createState() => _MonthlyAppHealthScreenState();
}

class _MonthlyAppHealthScreenState extends State<MonthlyAppHealthScreen> {
  bool _loading = true;
  String? _error;

  List<_MonthPoint> _scanVolume = [];
  List<_MonthPoint> _newUsers = [];
  List<_MonthPoint> _falseReports = [];
  List<Map<String, dynamic>> _trainingJobs = [];
  List<Map<String, dynamic>> _modelVersions = [];
  Map<String, int> _apiHits = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Returns the first day of each of the past [n] months, oldest first.
  List<DateTime> _monthStarts(int n) {
    final now = DateTime.now();
    return List.generate(n, (i) {
      final offset = n - 1 - i;
      return DateTime(now.year, now.month - offset, 1);
    });
  }

  String _monthLabel(DateTime dt) => DateFormat('MMM yy').format(dt);

  String _monthKey(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}';

  String _tsKey(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    }
    return '';
  }

  List<_MonthPoint> _toPoints(List<DateTime> months, Map<String, int> counts) =>
      months.map((m) => _MonthPoint(_monthLabel(m), counts[_monthKey(m)] ?? 0)).toList();

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final months = _monthStarts(6);
      final sixMonthsAgo = Timestamp.fromDate(months.first);

      final results = await Future.wait([
        // 1. Scans in past 6 months
        FirebaseFirestore.instance
            .collectionGroup('scans')
            .where('scannedAt', isGreaterThanOrEqualTo: sixMonthsAgo)
            .get(),
        // 2. Users registered in past 6 months
        FirebaseFirestore.instance
            .collection('users')
            .where('createdAt', isGreaterThanOrEqualTo: sixMonthsAgo)
            .get(),
        // 3. False reports in past 6 months
        FirebaseFirestore.instance
            .collection('false_reports')
            .where('submittedAt', isGreaterThanOrEqualTo: sixMonthsAgo)
            .get(),
        // 4. Training jobs (latest 10)
        FirebaseFirestore.instance
            .collection('training_jobs')
            .orderBy('createdAt', descending: true)
            .limit(10)
            .get(),
        // 5. Active model versions
        FirebaseFirestore.instance
            .collection('model_versions')
            .where('status', isEqualTo: 'active')
            .get(),
        // 6. Recent 200 scans for API hit rate
        FirebaseFirestore.instance
            .collectionGroup('scans')
            .orderBy('scannedAt', descending: true)
            .limit(200)
            .get(),
      ]);

      final scansSnap       = results[0];
      final usersSnap       = results[1];
      final reportsSnap     = results[2];
      final jobsSnap        = results[3];
      final modelsSnap      = results[4];
      final recentScansSnap = results[5];

      // ── Monthly scan volume ──────────────────────────────────────────────────
      final scanCounts = <String, int>{};
      for (final doc in scansSnap.docs) {
        final key = _tsKey(doc.data()['scannedAt']);
        if (key.isNotEmpty) scanCounts[key] = (scanCounts[key] ?? 0) + 1;
      }

      // ── Monthly new users ────────────────────────────────────────────────────
      final userCounts = <String, int>{};
      for (final doc in usersSnap.docs) {
        final key = _tsKey(doc.data()['createdAt']);
        if (key.isNotEmpty) userCounts[key] = (userCounts[key] ?? 0) + 1;
      }

      // ── Monthly false reports ────────────────────────────────────────────────
      final reportCounts = <String, int>{};
      for (final doc in reportsSnap.docs) {
        final key = _tsKey(doc.data()['submittedAt']);
        if (key.isNotEmpty) reportCounts[key] = (reportCounts[key] ?? 0) + 1;
      }

      // ── Training jobs ────────────────────────────────────────────────────────
      final jobs = jobsSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

      // ── Active model versions ────────────────────────────────────────────────
      final models = modelsSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

      // ── External API hit rate ────────────────────────────────────────────────
      final apiHits = <String, int>{};
      for (final doc in recentScansSnap.docs) {
        final sources = doc.data()['externalSources'];
        if (sources is List) {
          for (final src in sources) {
            final s = src.toString();
            if (s.isNotEmpty) apiHits[s] = (apiHits[s] ?? 0) + 1;
          }
        }
      }
      final sortedApiHits = Map.fromEntries(
        apiHits.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
      );

      setState(() {
        _scanVolume   = _toPoints(months, scanCounts);
        _newUsers     = _toPoints(months, userCounts);
        _falseReports = _toPoints(months, reportCounts);
        _trainingJobs = jobs;
        _modelVersions = models;
        _apiHits      = sortedApiHits;
        _loading      = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

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
                        valueColor: AlwaysStoppedAnimation(AppColors.primaryPurple)),
                  ),
                )
              : _error != null
                  ? Center(
                      child: Column(children: [
                        const SizedBox(height: 80),
                        const Icon(Icons.error_outline, color: AppColors.highRisk, size: 40),
                        const SizedBox(height: 12),
                        Text('Failed to load: $_error',
                            style: const TextStyle(color: AppColors.highRisk)),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _loadData,
                          child: const Text('Retry',
                              style: TextStyle(color: AppColors.primaryPurple)),
                        ),
                      ]),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        // Row 1: scan volume + new users
                        LayoutBuilder(builder: (ctx, constraints) {
                          final isWide = constraints.maxWidth > 800;
                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildBarChart('Monthly Scan Volume',
                                    Icons.qr_code_scanner_rounded, _scanVolume,
                                    AppColors.primaryPurple)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildBarChart('New User Registrations',
                                    Icons.person_add_outlined, _newUsers,
                                    AppColors.safe)),
                              ],
                            );
                          }
                          return Column(children: [
                            _buildBarChart('Monthly Scan Volume',
                                Icons.qr_code_scanner_rounded, _scanVolume, AppColors.primaryPurple),
                            const SizedBox(height: 16),
                            _buildBarChart('New User Registrations',
                                Icons.person_add_outlined, _newUsers, AppColors.safe),
                          ]);
                        }),
                        const SizedBox(height: 16),
                        // Row 2: false reports + API hit rate
                        LayoutBuilder(builder: (ctx, constraints) {
                          final isWide = constraints.maxWidth > 800;
                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildBarChart('False Reports per Month',
                                    Icons.flag_outlined, _falseReports,
                                    AppColors.mediumRisk)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildApiHitRate()),
                              ],
                            );
                          }
                          return Column(children: [
                            _buildBarChart('False Reports per Month',
                                Icons.flag_outlined, _falseReports, AppColors.mediumRisk),
                            const SizedBox(height: 16),
                            _buildApiHitRate(),
                          ]);
                        }),
                        const SizedBox(height: 16),
                        // Row 3: models + training jobs
                        LayoutBuilder(builder: (ctx, constraints) {
                          final isWide = constraints.maxWidth > 800;
                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 4, child: _buildModelVersions()),
                                const SizedBox(width: 16),
                                Expanded(flex: 6, child: _buildTrainingJobs()),
                              ],
                            );
                          }
                          return Column(children: [
                            _buildModelVersions(),
                            const SizedBox(height: 16),
                            _buildTrainingJobs(),
                          ]);
                        }),
                      ],
                    ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('App Health & Logs',
                  style: TextStyle(color: AppColors.primaryText, fontSize: 20,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('Last 6 months — scan trends, model health, training jobs, API coverage',
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

  // ── Bar chart ────────────────────────────────────────────────────────────────

  Widget _buildBarChart(String title, IconData icon,
      List<_MonthPoint> points, Color color) {
    final maxVal = points.isEmpty ? 1
        : points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final effective = maxVal == 0 ? 1 : maxVal;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(
                color: AppColors.primaryText, fontSize: 15,
                fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: points.map((p) {
                final frac = p.value / effective;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (p.value > 0)
                          Text('${p.value}', style: TextStyle(
                              color: color, fontSize: 10,
                              fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6)),
                          child: Container(
                            height: frac * 110,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [color.withValues(alpha: 0.9),
                                  color.withValues(alpha: 0.5)],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: points.map((p) => Expanded(
              child: Text(p.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.secondaryText, fontSize: 10)),
            )).toList(),
          ),
        ],
      ),
    );
  }

  // ── External API hit rate ─────────────────────────────────────────────────────

  Widget _buildApiHitRate() {
    final total = _apiHits.values.fold(0, (a, b) => a + b);
    final effective = total == 0 ? 1 : total;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.cloud_outlined, color: AppColors.primaryPurple, size: 18),
            SizedBox(width: 8),
            Text('External API Coverage',
                style: TextStyle(color: AppColors.primaryText, fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          const Text('Based on last 200 scans — drop in hits may signal an API outage.',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 11)),
          const SizedBox(height: 16),
          if (_apiHits.isEmpty)
            const Text('No external source data yet.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 13))
          else
            ..._apiHits.entries.map((e) {
              final frac = e.value / effective;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(e.key, style: const TextStyle(
                          color: AppColors.primaryText, fontSize: 12,
                          fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text('${e.value}  (${(frac * 100).toStringAsFixed(1)}%)',
                          style: const TextStyle(
                              color: AppColors.secondaryText, fontSize: 11)),
                    ]),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: 8,
                        backgroundColor: AppColors.mainBackground,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primaryPurple),
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

  // ── Model versions ───────────────────────────────────────────────────────────

  Widget _buildModelVersions() {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.memory_rounded, color: AppColors.safe, size: 18),
            SizedBox(width: 8),
            Text('Active Model Versions',
                style: TextStyle(color: AppColors.primaryText, fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          if (_modelVersions.isEmpty)
            const Text('No active models found.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 13))
          else
            ..._modelVersions.map((m) {
              final modelType = m['modelType']?.toString() ?? '—';
              final version = m['version']?.toString() ?? '—';
              final accuracy = m['accuracy'];
              final deployedAt = m['deployedAt'] ?? m['trainedAt'];
              String deployedStr = '—';
              if (deployedAt is Timestamp) {
                deployedStr = DateFormat('dd MMM yyyy').format(deployedAt.toDate());
              }
              final accuracyStr = accuracy != null
                  ? '${(accuracy * 100).toStringAsFixed(1)}%'
                  : '—';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.mainBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.safe.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.safe.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(modelType.toUpperCase(),
                            style: const TextStyle(
                                color: AppColors.safe, fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                      const Spacer(),
                      Text('v$version',
                          style: const TextStyle(
                              color: AppColors.secondaryText, fontSize: 11)),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      _miniMetric('Accuracy', accuracyStr),
                      const SizedBox(width: 16),
                      _miniMetric('Deployed', deployedStr),
                    ]),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
            color: AppColors.secondaryText, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(
            color: AppColors.primaryText, fontSize: 13,
            fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ── Training jobs ────────────────────────────────────────────────────────────

  Widget _buildTrainingJobs() {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.model_training_rounded,
                color: AppColors.primaryPurple, size: 18),
            SizedBox(width: 8),
            Text('Training Job History',
                style: TextStyle(color: AppColors.primaryText, fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          if (_trainingJobs.isEmpty)
            const Text('No training jobs found.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 13))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _trainingJobs.length,
              separatorBuilder: (_, x) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final job = _trainingJobs[index];
                final status = job['status']?.toString() ?? 'unknown';
                final modelType = job['modelType']?.toString() ?? '—';
                final createdAt = job['createdAt'];
                String createdStr = '—';
                if (createdAt is Timestamp) {
                  createdStr = DateFormat('dd MMM yyyy, hh:mm a')
                      .format(createdAt.toDate());
                }

                Color statusColor;
                IconData statusIcon;
                switch (status.toLowerCase()) {
                  case 'completed':
                    statusColor = AppColors.safe;
                    statusIcon = Icons.check_circle_outline_rounded;
                    break;
                  case 'running':
                    statusColor = AppColors.primaryPurple;
                    statusIcon = Icons.sync_rounded;
                    break;
                  case 'failed':
                    statusColor = AppColors.highRisk;
                    statusIcon = Icons.cancel_outlined;
                    break;
                  default:
                    statusColor = AppColors.secondaryText;
                    statusIcon = Icons.schedule_rounded;
                }

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.mainBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(children: [
                    Icon(statusIcon, color: statusColor, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(modelType.toUpperCase(),
                              style: const TextStyle(
                                  color: AppColors.primaryText, fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(createdStr,
                              style: const TextStyle(
                                  color: AppColors.secondaryText, fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(status.toUpperCase(),
                          style: TextStyle(
                              color: statusColor, fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ─── Shared panel widget ──────────────────────────────────────────────────────
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
        border: Border.all(
            color: AppColors.primaryPurple.withValues(alpha: 0.35)),
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
