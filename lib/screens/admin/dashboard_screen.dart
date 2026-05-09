import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../login_screen.dart';
import 'user_management_screen.dart';
import 'flagged_reviews_screen.dart';
import 'scan_statistics_screen.dart';
import 'security_management_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;   // <-- RESTORED

// ============================================================================
// Dashboard Content (fully restored – same as before)
// ============================================================================
class _DashboardContent extends StatefulWidget {
  const _DashboardContent();

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  late Future<int> _totalUsers;
  late Future<int> _scansToday;
  late Future<int> _highRiskDetected;
  late Future<int> _flaggedReports;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().first.then((user) {
      if (user != null && mounted) {
        setState(() {
          _totalUsers = _getTotalUsers();
          _scansToday = _getScansToday();
          _highRiskDetected = _getHighRiskDetected();
          _flaggedReports = _getFlaggedReports();
        });
      }
    });
    _totalUsers = Future.value(0);
    _scansToday = Future.value(0);
    _highRiskDetected = Future.value(0);
    _flaggedReports = Future.value(0);
  }

  Future<int> _getTotalUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      return snapshot.size;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getScansToday() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('scans')
          .where('scannedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
      return snapshot.size;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getHighRiskDetected() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('scans')
          .where('riskScore', isGreaterThanOrEqualTo: 50)
          .get();
      return snapshot.size;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getFlaggedReports() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('false_reports')
          .where('status', isEqualTo: 'pending')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1380),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth > 1050;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(flex: 5, child: _AdminProfileCard()),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 7,
                          child: GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 2.5,
                            children: [
                              _StatCard(title: 'Total Users', value: _totalUsers, icon: Icons.people_outline),
                              _StatCard(title: 'Scans Today', value: _scansToday, icon: Icons.qr_code_scanner_outlined),
                              _StatCard(title: 'High Risk Detected', value: _highRiskDetected, icon: Icons.warning_amber_rounded),
                              _StatCard(title: 'Flagged Reports', value: _flaggedReports, icon: Icons.flag_outlined),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      const _AdminProfileCard(),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 2.4,
                        children: [
                          _StatCard(title: 'Total Users', value: _totalUsers, icon: Icons.people_outline),
                          _StatCard(title: 'Scans Today', value: _scansToday, icon: Icons.qr_code_scanner_outlined),
                          _StatCard(title: 'High Risk Detected', value: _highRiskDetected, icon: Icons.warning_amber_rounded),
                          _StatCard(title: 'Flagged Reports', value: _flaggedReports, icon: Icons.flag_outlined),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth > 1050;
                  if (isWide) {
                    return const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 8, child: _DynamicScanActivityPanel()),
                        SizedBox(width: 16),
                        Expanded(flex: 5, child: _SystemStatusPanel()),
                      ],
                    );
                  }
                  return const Column(
                    children: [
                      _DynamicScanActivityPanel(),
                      SizedBox(height: 16),
                      _SystemStatusPanel(),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth > 1050;
                  if (isWide) {
                    return const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 8, child: _DynamicFlaggedReportsPanel()),
                        SizedBox(width: 16),
                        Expanded(flex: 5, child: _RecentSystemActivityPanel()),
                      ],
                    );
                  }
                  return const Column(
                    children: [
                      _DynamicFlaggedReportsPanel(),
                      SizedBox(height: 16),
                      _RecentSystemActivityPanel(),
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
}

// ============================================================================
// Stat Card (unchanged)
// ============================================================================
class _StatCardPlaceholder extends StatelessWidget {
  final String title;
  final IconData icon;
  const _StatCardPlaceholder({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.secondaryText, size: 28),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
              const SizedBox(height: 6),
              const SizedBox(width: 40, height: 10, child: LinearProgressIndicator()),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final Future<int> value;
  final IconData icon;
  const _StatCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: value,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _StatCardPlaceholder(title: title, icon: icon);
        }
        if (snapshot.hasError) {
          return _StatCardPlaceholder(title: title, icon: icon);
        }
        return _Panel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primaryPurple, size: 28),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    snapshot.data?.toString() ?? '0',
                    style: const TextStyle(color: AppColors.primaryText, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// Admin Profile Card (unchanged)
// ============================================================================
class _AdminProfileCard extends StatelessWidget {
  const _AdminProfileCard();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'Admin User';
    final email = user?.email ?? '';
    String lastLogin = 'Unknown';
    if (user?.metadata.lastSignInTime != null) {
      final dt = user!.metadata.lastSignInTime!.toLocal();
      final now = DateTime.now();
      final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      lastLogin = '${isToday ? 'Today' : '${dt.day}/${dt.month}/${dt.year}'}, $hour:$minute';
    }
    return _Panel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Admin Overview', style: TextStyle(color: AppColors.primaryText, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Row(
            children: [
              const CircleAvatar(radius: 28, backgroundColor: Colors.white24, child: Icon(Icons.person_outline, color: Colors.white, size: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: const TextStyle(color: AppColors.primaryText, fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(email, style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
                    const SizedBox(height: 8),
                    const Text('Role: System Administrator', style: TextStyle(color: AppColors.secondaryText, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: AppColors.mainBackground, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Last Login', style: TextStyle(color: AppColors.secondaryText, fontSize: 12.5)),
                Text(lastLogin, style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Dynamic Scan Activity Panel (unchanged)
// ============================================================================
class _DynamicScanActivityPanel extends StatefulWidget {
  const _DynamicScanActivityPanel();

  @override
  State<_DynamicScanActivityPanel> createState() => _DynamicScanActivityPanelState();
}

class _DynamicScanActivityPanelState extends State<_DynamicScanActivityPanel> {
  late Future<List<double>> _dailyScanCounts;
  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _dailyScanCounts = _fetchDailyScanCounts();
  }

  Future<List<double>> _fetchDailyScanCounts() async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final List<double> counts = List.filled(7, 0.0);

      for (int i = 0; i < 7; i++) {
        final dayStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + i);
        final dayEnd = dayStart.add(const Duration(days: 1));
        final snapshot = await FirebaseFirestore.instance
            .collectionGroup('scans')
            .where('scannedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
            .where('scannedAt', isLessThan: Timestamp.fromDate(dayEnd))
            .get();
        counts[i] = snapshot.docs.length.toDouble();
      }
      return counts;
    } catch (e) {
      return [0, 0, 0, 0, 0, 0, 0];
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Scan Activity (Last 7 Days)', style: TextStyle(color: AppColors.primaryText, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          FutureBuilder<List<double>>(
            future: _dailyScanCounts,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SizedBox(
                  height: 290,
                  child: const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple)),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return SizedBox(
                  height: 290,
                  child: Center(child: Text('Failed to load scan data', style: TextStyle(color: AppColors.secondaryText))),
                );
              }
              final values = snapshot.data!;
              double maxVal = 0.0;
              for (final v in values) {
                if (v > maxVal) maxVal = v;
              }
              final List<double> normalized = [];
              for (final v in values) {
                if (maxVal > 0) {
                  normalized.add((v / maxVal) * 200.0);
                } else {
                  normalized.add(0.0);
                }
              }
              return Container(
                height: 290,
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
                              children: List.generate(
                                values.length,
                                (index) => _Bar(height: normalized[index]),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: _days.map((day) => SizedBox(
                        width: 32,
                        child: Text(day, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                      )).toList(),
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

// ============================================================================
// System Status Panel (unchanged)
// ============================================================================
class _SystemStatusPanel extends StatefulWidget {
  const _SystemStatusPanel();

  @override
  State<_SystemStatusPanel> createState() => _SystemStatusPanelState();
}

class _SystemStatusPanelState extends State<_SystemStatusPanel> {
  late Future<Map<String, dynamic>> _statusFuture;

  @override
  void initState() {
    super.initState();
    _statusFuture = _fetchSystemStatus();
  }

  Future<Map<String, dynamic>> _fetchSystemStatus() async {
    late bool dbOk;
    late int flagCount;
    late bool threatEngineOk;
    late bool apiGatewayOk;

    await Future.wait([
      () async {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 6));
          dbOk = true;
        } catch (_) {
          dbOk = false;
        }
      }(),
      () async {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('false_reports')
              .where('status', isEqualTo: 'pending')
              .get()
              .timeout(const Duration(seconds: 6));
          flagCount = snap.docs.length;
        } catch (_) {
          flagCount = -1;
        }
      }(),
      () async {
        try {
          final now = DateTime.now();
          final startOfDay = DateTime(now.year, now.month, now.day);
          final snap = await FirebaseFirestore.instance
              .collectionGroup('scans')
              .where('scannedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 6));
          threatEngineOk = snap.docs.isNotEmpty;
        } catch (_) {
          threatEngineOk = true;
        }
      }(),
      () async {
        try {
          final res = await http.get(Uri.parse('https://dns.google/resolve?name=virustotal.com')).timeout(const Duration(seconds: 6));
          apiGatewayOk = res.statusCode == 200;
        } catch (_) {
          apiGatewayOk = false;
        }
      }(),
    ]);

    return {
      'threatEngine': {'status': threatEngineOk ? 'Active' : 'Idle', 'good': true},
      'database': {'status': dbOk ? 'Connected' : 'Disconnected', 'good': dbOk},
      'apiGateway': {'status': apiGatewayOk ? 'Healthy' : 'Unreachable', 'good': apiGatewayOk},
      'flagQueue': {
        'status': flagCount >= 0 ? '$flagCount Pending' : 'Unknown',
        'good': flagCount == 0,
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('System Status', style: TextStyle(color: AppColors.primaryText, fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.secondaryText, size: 18),
                onPressed: () => setState(() => _statusFuture = _fetchSystemStatus()),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: _statusFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Column(
                  children: [
                    _StatusRowLoading(label: 'Threat Engine'),
                    _StatusRowLoading(label: 'Database'),
                    _StatusRowLoading(label: 'API Gateway'),
                    _StatusRowLoading(label: 'Flag Queue'),
                  ],
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Failed to load status', style: TextStyle(color: AppColors.secondaryText)),
                  ),
                );
              }
              final d = snapshot.data!;
              return Column(
                children: [
                  _StatusRow(label: 'Threat Engine', status: d['threatEngine']['status'], good: d['threatEngine']['good']),
                  _StatusRow(label: 'Database', status: d['database']['status'], good: d['database']['good']),
                  _StatusRow(label: 'API Gateway', status: d['apiGateway']['status'], good: d['apiGateway']['good']),
                  _StatusRow(label: 'Flag Queue', status: d['flagQueue']['status'], good: d['flagQueue']['good']),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatusRowLoading extends StatelessWidget {
  final String label;
  const _StatusRowLoading({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(color: AppColors.mainBackground, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryPurple),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w500))),
          const Text('Checking...', style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String status;
  final bool good;
  const _StatusRow({required this.label, required this.status, required this.good});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(color: AppColors.mainBackground, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: good ? Colors.greenAccent : Colors.orangeAccent, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w500))),
          Text(status, style: const TextStyle(color: AppColors.secondaryText)),
        ],
      ),
    );
  }
}

// ============================================================================
// Dynamic Flagged Reports Panel (unchanged – with mounted checks)
// ============================================================================
class _DynamicFlaggedReportsPanel extends StatelessWidget {
  const _DynamicFlaggedReportsPanel();

  Future<void> _updateReportStatus(BuildContext context, String docId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('false_reports').doc(docId).update({'status': newStatus});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report marked as $newStatus'), backgroundColor: AppColors.safe),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating report: $e'), backgroundColor: AppColors.highRisk),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Flagged Reports', style: TextStyle(color: AppColors.primaryText, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('false_reports')
                .where('status', isEqualTo: 'pending')
                .orderBy('submittedAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Text('No pending flagged reports', style: TextStyle(color: AppColors.secondaryText)),
                );
              }
              final reports = snapshot.data!.docs;
              return Container(
                decoration: BoxDecoration(color: AppColors.mainBackground, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: reports.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final url = data['url'] ?? 'Unknown URL';
                    final risk = data['scanResult']?['verdict'] ?? 'Pending';
                    final date = data['submittedAt'] != null
                        ? (data['submittedAt'] as Timestamp).toDate()
                        : DateTime.now();
                    final formattedDate = _formatDate(date);
                    return _ReportRow(
                      url: url,
                      risk: risk,
                      date: formattedDate,
                      onReview: () => _updateReportStatus(context, doc.id, 'reviewed'),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final isToday = date.day == now.day && date.month == now.month && date.year == now.year;
    if (isToday) {
      return 'Today, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _ReportRow extends StatelessWidget {
  final String url;
  final String risk;
  final String date;
  final VoidCallback onReview;

  const _ReportRow({
    required this.url,
    required this.risk,
    required this.date,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    switch (risk.toLowerCase()) {
      case 'malicious':
        badgeColor = AppColors.highRisk;
        break;
      case 'suspicious':
        badgeColor = AppColors.mediumRisk;
        break;
      case 'safe':
        badgeColor = AppColors.safe;
        break;
      default:
        badgeColor = AppColors.primaryPurple;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(url, style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(date, style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
            ),
            child: Text(risk, style: TextStyle(color: badgeColor, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          const SizedBox(width: 14),
          TextButton(
            onPressed: onReview,
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryPurple),
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Recent System Activity Panel (unchanged)
// ============================================================================
class _ActivityItem {
  final String title;
  final String subtitle;
  final DateTime time;
  final IconData icon;
  final Color iconColor;

  _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.iconColor,
  });
}

class _RecentSystemActivityPanel extends StatefulWidget {
  const _RecentSystemActivityPanel();

  @override
  State<_RecentSystemActivityPanel> createState() => _RecentSystemActivityPanelState();
}

class _RecentSystemActivityPanelState extends State<_RecentSystemActivityPanel> {
  late Future<List<_ActivityItem>> _activityFuture;

  @override
  void initState() {
    super.initState();
    _activityFuture = _fetchActivity();
  }

  Future<List<_ActivityItem>> _fetchActivity() async {
    final items = <_ActivityItem>[];

    await Future.wait([
      () async {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('false_reports')
              .orderBy('submittedAt', descending: true)
              .limit(5)
              .get();
          for (final doc in snap.docs) {
            final data = doc.data();
            final time = (data['submittedAt'] as Timestamp?)?.toDate();
            if (time == null) continue;
            final url = data['url'] as String? ?? 'Unknown URL';
            final domain = _extractDomain(url);
            final status = data['status'] ?? 'pending';
            if (status == 'reviewed') {
              items.add(_ActivityItem(
                title: 'Flagged report reviewed',
                subtitle: 'Admin resolved report for $domain',
                time: time,
                icon: Icons.check_circle_outline,
                iconColor: AppColors.safe,
              ));
            } else {
              final verdict = data['scanResult']?['verdict'] as String? ?? 'unknown';
              items.add(_ActivityItem(
                title: 'Flagged report submitted',
                subtitle: '$domain flagged as $verdict',
                time: time,
                icon: Icons.flag_outlined,
                iconColor: AppColors.mediumRisk,
              ));
            }
          }
        } catch (_) {}
      }(),

      () async {
        try {
          final snap = await FirebaseFirestore.instance
              .collectionGroup('scans')
              .where('riskScore', isGreaterThanOrEqualTo: 50)
              .limit(10)
              .get();
          final docs = snap.docs
              .map((d) => d.data())
              .where((d) => d['scannedAt'] != null)
              .toList()
            ..sort((a, b) {
              final ta = (a['scannedAt'] as Timestamp).toDate();
              final tb = (b['scannedAt'] as Timestamp).toDate();
              return tb.compareTo(ta);
            });
          for (final data in docs.take(4)) {
            final time = (data['scannedAt'] as Timestamp).toDate();
            final domain = _extractDomain(data['url'] as String? ?? '');
            final threat = _formatThreat(data['threatType'] as String? ?? 'unknown');
            items.add(_ActivityItem(
              title: 'High-risk URL detected',
              subtitle: '$domain — $threat',
              time: time,
              icon: Icons.warning_amber_rounded,
              iconColor: AppColors.highRisk,
            ));
          }
        } catch (_) {}
      }(),

      () async {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .orderBy('createdAt', descending: true)
              .limit(4)
              .get();
          for (final doc in snap.docs) {
            final data = doc.data();
            final time = (data['createdAt'] as Timestamp?)?.toDate();
            if (time == null) continue;
            final firstName = data['firstName'] as String? ?? '';
            final lastName = data['lastName'] as String? ?? '';
            final name = '$firstName $lastName'.trim();
            items.add(_ActivityItem(
              title: 'New user registered',
              subtitle: name.isEmpty ? 'A new user joined the platform' : '$name joined the platform',
              time: time,
              icon: Icons.person_add_outlined,
              iconColor: AppColors.primaryPurple,
            ));
          }
        } catch (_) {}
      }(),
    ]);

    items.sort((a, b) => b.time.compareTo(a.time));
    return items.take(5).toList();
  }

  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
      return uri.host.replaceAll('www.', '');
    } catch (_) {
      return url.length > 30 ? '${url.substring(0, 30)}...' : url;
    }
  }

  String _formatThreat(String type) {
    switch (type.toLowerCase()) {
      case 'phishing': return 'Phishing';
      case 'malware': return 'Malware';
      case 'malicious': return 'Malicious';
      case 'defacement': return 'Defacement';
      case 'benign': return 'Benign';
      default: return type.isEmpty ? 'Unknown' : type[0].toUpperCase() + type.substring(1);
    }
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min${diff.inMinutes == 1 ? '' : 's'} ago';
    if (diff.inHours < 24) return '${diff.inHours} hr${diff.inHours == 1 ? '' : 's'} ago';
    final now = DateTime.now();
    final isToday = time.day == now.day && time.month == now.month && time.year == now.year;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = time.day == yesterday.day && time.month == yesterday.month && time.year == yesterday.year;
    if (isToday) return 'Today, ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    if (isYesterday) return 'Yesterday';
    return '${time.day}/${time.month}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Recent System Activity', style: TextStyle(color: AppColors.primaryText, fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.secondaryText, size: 18),
                onPressed: () => setState(() => _activityFuture = _fetchActivity()),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<_ActivityItem>>(
            future: _activityFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(color: AppColors.primaryPurple),
                  ),
                );
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: const Text('No recent activity', style: TextStyle(color: AppColors.secondaryText)),
                );
              }
              return Column(
                children: items.asMap().entries.map((entry) {
                  final isLast = entry.key == items.length - 1;
                  return Column(
                    children: [
                      _MiniActivityTile(
                        title: entry.value.title,
                        subtitle: entry.value.subtitle,
                        timeLabel: _timeAgo(entry.value.time),
                        icon: entry.value.icon,
                        iconColor: entry.value.iconColor,
                      ),
                      if (!isLast) const SizedBox(height: 10),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MiniActivityTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? timeLabel;
  final IconData? icon;
  final Color? iconColor;

  const _MiniActivityTile({
    required this.title,
    required this.subtitle,
    this.timeLabel,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.mainBackground, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primaryPurple).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor ?? AppColors.primaryPurple, size: 16),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    if (timeLabel != null)
                      Text(timeLabel!, style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Shared Panel widget (unchanged)
// ============================================================================
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

// ============================================================================
// Main AdminDashboardScreen with Security Management added
// ============================================================================
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;

  final List<Widget> _screens = [
    const _DashboardContent(),
    const UserManagementScreen(),
    const FlaggedReviewsScreen(),
    const SecurityManagementScreen(),
    const ScanStatisticsScreen(),
  ];

  final List<String> _titles = [
    'Dashboard',
    'User Management',
    'Flagged Reviews',
    'Security Management',
    'Scan Statistics',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: SafeArea(
        child: Row(
          children: [
            // Animated Sidebar
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: _isSidebarCollapsed ? 72 : 280,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: AppColors.mainBackground,
                border: Border(right: BorderSide(color: AppColors.divider.withValues(alpha: 0.3), width: 1)),
              ),
              child: Column(
                crossAxisAlignment: _isSidebarCollapsed ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  if (_isSidebarCollapsed)
                    Center(
                      child: IconButton(
                        icon: const Icon(Icons.menu_open, color: AppColors.secondaryText),
                        onPressed: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                        tooltip: 'Expand sidebar',
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Image.asset('assets/images/LinkSentryLogoTop.png', height: 48, fit: BoxFit.contain),
                          IconButton(
                            icon: const Icon(Icons.menu, color: AppColors.secondaryText),
                            onPressed: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                            tooltip: 'Collapse sidebar',
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),
                  _buildNavItem(icon: Icons.dashboard_outlined, label: 'Dashboard', index: 0),
                  _buildNavItem(icon: Icons.people_outline, label: 'User Management', index: 1),
                  _buildNavItem(icon: Icons.flag_outlined, label: 'Flagged Reviews', index: 2),
                  _buildNavItem(icon: Icons.security_outlined, label: 'Security Management', index: 3),
                  _buildNavItem(icon: Icons.analytics_outlined, label: 'Scan Statistics', index: 4),
                  const Spacer(),
                  Padding(
                    padding: EdgeInsets.all(_isSidebarCollapsed ? 8 : 16),
                    child: Column(
                      children: [
                        if (!_isSidebarCollapsed)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.primaryPurple.withValues(alpha: 0.2)),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryPurple.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.white24,
                                  child: Icon(Icons.person_outline, color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        FirebaseAuth.instance.currentUser?.displayName ?? 'Admin User',
                                        style: const TextStyle(
                                          color: AppColors.primaryText,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        FirebaseAuth.instance.currentUser?.email ?? '',
                                        style: const TextStyle(
                                          color: AppColors.secondaryText,
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        Container(
                          width: _isSidebarCollapsed ? 40 : double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.highRisk.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextButton.icon(
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                              if (context.mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                                  (_) => false,
                                );
                              }
                            },
                            icon: const Icon(Icons.logout, color: AppColors.highRisk, size: 18),
                            label: _isSidebarCollapsed
                                ? const SizedBox.shrink()
                                : const Text(
                                    'Logout',
                                    style: TextStyle(color: AppColors.highRisk),
                                  ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: _isSidebarCollapsed ? 0 : 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            // Main content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.divider.withValues(alpha: 0.3))),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _titles[_selectedIndex],
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _screens[_selectedIndex],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    return Tooltip(
      message: _isSidebarCollapsed ? label : '',
      waitDuration: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Material(
          color: isSelected
              ? AppColors.primaryPurple.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _selectedIndex = index),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _isSidebarCollapsed ? 8 : 12,
                vertical: 10,
              ),
              child: Row(
                mainAxisAlignment: _isSidebarCollapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? AppColors.primaryPurple : AppColors.secondaryText,
                  ),
                  if (!_isSidebarCollapsed) ...[
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? AppColors.primaryText : AppColors.secondaryText,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}