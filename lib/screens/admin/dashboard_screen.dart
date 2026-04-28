import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'user_management_screen.dart';
import 'flagged_reviews_screen.dart';
import 'scan_statistics_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ============================================================================
// Dashboard Content — converted to StatefulWidget so futures are stable
// ============================================================================
class _DashboardContent extends StatefulWidget {
  const _DashboardContent();

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  // Futures are created once in initState — not on every rebuild
  late Future<int> _totalUsers;
  late Future<int> _scansToday;
  late Future<int> _highRiskDetected;
  late Future<int> _flaggedReports;

  @override
  void initState() {
    super.initState();

    // Guard: wait for auth to be confirmed before querying Firestore
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

    // Initialise with futures that resolve to 0 while auth is pending
    _totalUsers = Future.value(0);
    _scansToday = Future.value(0);
    _highRiskDetected = Future.value(0);
    _flaggedReports = Future.value(0);
  }

  // ── Firestore helpers ────────────────────────────────────────────────────

  Future<int> _getTotalUsers() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();
      return snapshot.size;
    } catch (e) {
      debugPrint('Error fetching total users: $e');
      return 0;
    }
  }

  Future<int> _getScansToday() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      debugPrint('Current user UID: $uid');

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      debugPrint('Filtering scans from: $startOfDay');

      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('scans')
          .where('scannedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      debugPrint('Scans today: ${snapshot.size}');
      return snapshot.size;
    } catch (e) {
      debugPrint('Error fetching scans: $e');
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
      debugPrint('Error fetching high risk scans: $e');
      return 0;
    }
  }

  // flagged_reports collection does not exist yet — stubbed to 0
  Future<int> _getFlaggedReports() async => 0;

  // ── Build ────────────────────────────────────────────────────────────────

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
              // Top section: admin overview + stat cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth > 1050;

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          flex: 5,
                          child: _AdminProfileCard(),
                        ),
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
                              _StatCard(
                                title: 'Total Users',
                                value: _totalUsers,
                                icon: Icons.people_outline,
                              ),
                              _StatCard(
                                title: 'Scans Today',
                                value: _scansToday,
                                icon: Icons.qr_code_scanner_outlined,
                              ),
                              _StatCard(
                                title: 'High Risk Detected',
                                value: _highRiskDetected,
                                icon: Icons.warning_amber_rounded,
                              ),
                              _StatCard(
                                title: 'Flagged Reports',
                                value: _flaggedReports,
                                icon: Icons.flag_outlined,
                              ),
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
                          _StatCard(
                            title: 'Total Users',
                            value: _totalUsers,
                            icon: Icons.people_outline,
                          ),
                          _StatCard(
                            title: 'Scans Today',
                            value: _scansToday,
                            icon: Icons.qr_code_scanner_outlined,
                          ),
                          _StatCard(
                            title: 'High Risk Detected',
                            value: _highRiskDetected,
                            icon: Icons.warning_amber_rounded,
                          ),
                          _StatCard(
                            title: 'Flagged Reports',
                            value: _flaggedReports,
                            icon: Icons.flag_outlined,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 18),

              // Middle section: scan chart + system status
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth > 1050;

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Expanded(
                          flex: 8,
                          child: _ScanActivityPanel(),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          flex: 5,
                          child: _SystemStatusPanel(),
                        ),
                      ],
                    );
                  }

                  return const Column(
                    children: [
                      _ScanActivityPanel(),
                      SizedBox(height: 16),
                      _SystemStatusPanel(),
                    ],
                  );
                },
              ),

              const SizedBox(height: 18),

              // Bottom section: reports + system activity
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth > 1050;

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Expanded(
                          flex: 8,
                          child: _RecentFlaggedReportsPanel(),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          flex: 5,
                          child: _RecentSystemActivityPanel(),
                        ),
                      ],
                    );
                  }

                  return const Column(
                    children: [
                      _RecentFlaggedReportsPanel(),
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
// Stat Card + Placeholder
// ============================================================================
class _StatCardPlaceholder extends StatelessWidget {
  final String title;
  final IconData icon;

  const _StatCardPlaceholder({
    required this.title,
    required this.icon,
  });

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
              Text(title,
                  style: const TextStyle(
                      color: AppColors.secondaryText, fontSize: 13)),
              const SizedBox(height: 6),
              const SizedBox(
                width: 40,
                height: 10,
                child: LinearProgressIndicator(),
              ),
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

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: value,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _StatCardPlaceholder(title: title, icon: icon);
        }
        if (snapshot.hasError) {
          debugPrint('StatCard error for $title: ${snapshot.error}');
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
                  Text(title,
                      style: const TextStyle(
                          color: AppColors.secondaryText, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    snapshot.data?.toString() ?? '0',
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
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
// Admin Profile Card — pulls real data from FirebaseAuth
// ============================================================================
class _AdminProfileCard extends StatelessWidget {
  const _AdminProfileCard();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'Admin User';
    final email = user?.email ?? '';

    // Format last sign-in time
    String lastLogin = 'Unknown';
    if (user?.metadata.lastSignInTime != null) {
      final dt = user!.metadata.lastSignInTime!.toLocal();
      final now = DateTime.now();
      final isToday = dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      lastLogin =
          '${isToday ? 'Today' : '${dt.day}/${dt.month}/${dt.year}'}, $hour:$minute';
    }

    return _Panel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Overview',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person_outline, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      email,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Role: System Administrator',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Last Login',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  lastLogin,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Scan Activity Panel (hardcoded chart — wire to Firestore when ready)
// ============================================================================
class _ScanActivityPanel extends StatelessWidget {
  const _ScanActivityPanel();

  @override
  Widget build(BuildContext context) {
    const List<double> values = [80, 120, 95, 150, 200, 170, 130];
    const List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scan Activity (Last 7 Days)',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 290,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryPurple.withOpacity(0.35),
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            5,
                            (index) => Container(height: 1, color: Colors.white10),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(
                            values.length,
                            (index) => _Bar(height: values[index]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: days
                      .map(
                        (day) => SizedBox(
                          width: 32,
                          child: Text(
                            day,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
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
        gradient: const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: AppColors.premiumGradient,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

// ============================================================================
// System Status Panel
// ============================================================================
class _SystemStatusPanel extends StatelessWidget {
  const _SystemStatusPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'System Status',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 16),
          _StatusRow(label: 'Threat Engine', status: 'Online', good: true),
          _StatusRow(label: 'Database', status: 'Connected', good: true),
          _StatusRow(label: 'API Gateway', status: 'Healthy', good: true),
          _StatusRow(label: 'Flag Queue', status: '11 Pending', good: false),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String status;
  final bool good;

  const _StatusRow({
    required this.label,
    required this.status,
    required this.good,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: good ? Colors.greenAccent : Colors.orangeAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            status,
            style: const TextStyle(color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Recent Flagged Reports Panel (hardcoded — wire to Firestore when ready)
// ============================================================================
class _RecentFlaggedReportsPanel extends StatelessWidget {
  const _RecentFlaggedReportsPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Flagged Reports',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: const [
                _ReportRow(
                  url: 'secure-login-check.com',
                  risk: 'High Risk',
                  date: 'Today, 10:45 AM',
                ),
                _ReportRow(
                  url: 'paypal-verify-access.net',
                  risk: 'Suspicious',
                  date: 'Today, 09:12 AM',
                ),
                _ReportRow(
                  url: 'bank-alert-now.co',
                  risk: 'Malicious',
                  date: 'Yesterday, 8:40 PM',
                ),
                _ReportRow(
                  url: 'telegram-security-check.org',
                  risk: 'Suspicious',
                  date: 'Yesterday, 3:05 PM',
                ),
                _ReportRow(
                  url: 'gift-card-claim-now.xyz',
                  risk: 'High Risk',
                  date: 'Yesterday, 1:18 PM',
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String url;
  final String risk;
  final String date;
  final bool isLast;

  const _ReportRow({
    required this.url,
    required this.risk,
    required this.date,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    switch (risk) {
      case 'Malicious':
      case 'High Risk':
        badgeColor = AppColors.highRisk;
        break;
      case 'Suspicious':
        badgeColor = AppColors.mediumRisk;
        break;
      case 'False Positive':
      case 'Safe':
        badgeColor = AppColors.safe;
        break;
      default:
        badgeColor = AppColors.primaryPurple;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  url,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: badgeColor.withOpacity(0.5)),
            ),
            child: Text(
              risk,
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 14),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryPurple,
            ),
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Recent System Activity Panel
// ============================================================================
class _RecentSystemActivityPanel extends StatelessWidget {
  const _RecentSystemActivityPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent System Activity',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 16),
          _MiniActivityTile(
            title: 'New threat rule added',
            subtitle: 'Phishing category updated 24 mins ago',
          ),
          SizedBox(height: 12),
          _MiniActivityTile(
            title: 'Database backup completed',
            subtitle: 'Backup finished successfully at 07:30 AM',
          ),
          SizedBox(height: 12),
          _MiniActivityTile(
            title: 'Flagged report reviewed',
            subtitle: 'Admin marked one URL as malicious',
          ),
          SizedBox(height: 12),
          _MiniActivityTile(
            title: 'User status updated',
            subtitle: 'One suspicious account was disabled',
          ),
        ],
      ),
    );
  }
}

class _MiniActivityTile extends StatelessWidget {
  final String title;
  final String subtitle;

  const _MiniActivityTile({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Shared Panel widget
// ============================================================================
class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _Panel({
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primaryPurple.withOpacity(0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ============================================================================
// Main AdminDashboardScreen with Sidebar and Navigation
// ============================================================================
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    _DashboardContent(),
    UserManagementScreen(),
    FlaggedReviewsScreen(),
    ScanStatisticsScreen(),
  ];

  final List<String> _titles = [
    'Dashboard',
    'User Management',
    'Flagged Reviews',
    'Scan Statistics',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: SafeArea(
        child: Row(
          children: [
            // Sidebar
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: AppColors.mainBackground,
                border: Border(
                  right: BorderSide(
                    color: AppColors.divider.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Image.asset(
                      'assets/images/LinkSentryLogoTop.png',
                      height: 48,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildNavItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    index: 0,
                  ),
                  _buildNavItem(
                    icon: Icons.people_outline,
                    label: 'User Management',
                    index: 1,
                  ),
                  _buildNavItem(
                    icon: Icons.flag_outlined,
                    label: 'Flagged Reviews',
                    index: 2,
                  ),
                  _buildNavItem(
                    icon: Icons.analytics_outlined,
                    label: 'Scan Statistics',
                    index: 3,
                  ),
                  const Spacer(),
                  // Logout section
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primaryPurple.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white24,
                            child: Icon(Icons.person_outline,
                                color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  FirebaseAuth.instance.currentUser
                                          ?.displayName ??
                                      'Admin User',
                                  style: const TextStyle(
                                    color: AppColors.primaryText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  FirebaseAuth.instance.currentUser?.email ??
                                      '',
                                  style: const TextStyle(
                                    color: AppColors.secondaryText,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout,
                                color: AppColors.secondaryText, size: 20),
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                              // TODO: Navigate to login screen after sign out
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            // Main content area
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.divider.withOpacity(0.3),
                        ),
                      ),
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
                        Container(
                          width: 280,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.divider.withOpacity(0.3),
                            ),
                          ),
                          child: const TextField(
                            style: TextStyle(color: AppColors.primaryText),
                            decoration: InputDecoration(
                              hintText: 'Search...',
                              hintStyle:
                                  TextStyle(color: AppColors.disabledText),
                              prefixIcon: Icon(Icons.search,
                                  color: AppColors.secondaryText),
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: _screens,
                    ),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryPurple.withOpacity(0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: AppColors.primaryPurple.withOpacity(0.5))
            : null,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color:
              isSelected ? AppColors.primaryPurple : AppColors.secondaryText,
        ),
        title: Text(
          label,
          style: TextStyle(
            color:
                isSelected ? AppColors.primaryText : AppColors.secondaryText,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}