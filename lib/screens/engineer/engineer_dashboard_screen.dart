import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../login_screen.dart';
import 'threat_engine_models_screen.dart';
import 'system_performance_screen.dart';
import 'system_settings_screen.dart';
import 'periodic_rescan_screen.dart';
import 'monthly_app_health_screen.dart';
import 'model_training_screen.dart';

// ============================================================================
// Engineer Dashboard Home Content
// ============================================================================
class _EngineerDashboardContent extends StatelessWidget {
  const _EngineerDashboardContent();

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
              // Top section: engineer overview + stat cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth > 1050;

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(flex: 5, child: _EngineerProfileCard()),
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
                            children: const [
                              _StatCard(
                                title: 'System Uptime',
                                value: '99.98%',
                                icon: Icons.access_time_outlined,
                              ),
                              _StatCard(
                                title: 'Active Scans',
                                value: '256',
                                icon: Icons.radar_outlined,
                              ),
                              _StatCard(
                                title: 'Alerts Today',
                                value: '12',
                                icon: Icons.warning_amber_rounded,
                              ),
                              _StatCard(
                                title: 'Queued Jobs',
                                value: '43',
                                icon: Icons.sync_outlined,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      const _EngineerProfileCard(),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 2.4,
                        children: const [
                          _StatCard(
                            title: 'System Uptime',
                            value: '99.98%',
                            icon: Icons.access_time_outlined,
                          ),
                          _StatCard(
                            title: 'Active Scans',
                            value: '256',
                            icon: Icons.radar_outlined,
                          ),
                          _StatCard(
                            title: 'Alerts Today',
                            value: '12',
                            icon: Icons.warning_amber_rounded,
                          ),
                          _StatCard(
                            title: 'Queued Jobs',
                            value: '43',
                            icon: Icons.sync_outlined,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 18),

              // Middle section: performance chart + service status
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth > 1050;

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Expanded(flex: 8, child: _PerformanceTrendPanel()),
                        SizedBox(width: 16),
                        Expanded(flex: 5, child: _SystemHealthPanel()),
                      ],
                    );
                  }

                  return const Column(
                    children: [
                      _PerformanceTrendPanel(),
                      SizedBox(height: 16),
                      _SystemHealthPanel(),
                    ],
                  );
                },
              ),

              const SizedBox(height: 18),

              // Bottom section: alerts + recent activity
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth > 1050;

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Expanded(flex: 8, child: _RecentCriticalAlertsPanel()),
                        SizedBox(width: 16),
                        Expanded(
                          flex: 5,
                          child: _RecentEngineerActivityPanel(),
                        ),
                      ],
                    );
                  }

                  return const Column(
                    children: [
                      _RecentCriticalAlertsPanel(),
                      SizedBox(height: 16),
                      _RecentEngineerActivityPanel(),
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
// Dashboard Widgets
// ============================================================================
class _EngineerProfileCard extends StatelessWidget {
  const _EngineerProfileCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Engineer Overview',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white24,
                child: Icon(
                  Icons.engineering_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Full Name',
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'engineer@linksentry.com',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Role: System Engineer',
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
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Last Sync',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  'Today, 09:15 AM',
                  style: TextStyle(
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryPurple.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryPurple, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
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

class _PerformanceTrendPanel extends StatelessWidget {
  const _PerformanceTrendPanel();

  @override
  Widget build(BuildContext context) {
    const List<double> values = [85, 72, 90, 78, 96, 88, 92];
    const List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Trend (Last 7 Days)',
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
                            (index) =>
                                Container(height: 1, color: Colors.white10),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(
                            values.length,
                            (index) => _Bar(height: values[index] * 2),
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

class _SystemHealthPanel extends StatelessWidget {
  const _SystemHealthPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'System Health',
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
          _StatusRow(label: 'Backup Service', status: 'Scheduled', good: true),
          _StatusRow(label: 'Alert Queue', status: '12 Pending', good: false),
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
          Text(status, style: const TextStyle(color: AppColors.secondaryText)),
        ],
      ),
    );
  }
}

class _RecentCriticalAlertsPanel extends StatelessWidget {
  const _RecentCriticalAlertsPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Critical Alerts',
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
            child: const Column(
              children: [
                _AlertRow(
                  title: 'High CPU Spike',
                  level: 'High',
                  date: 'Today, 10:45 AM',
                ),
                _AlertRow(
                  title: 'API Timeout Error',
                  level: 'Medium',
                  date: 'Today, 09:12 AM',
                ),
                _AlertRow(
                  title: 'Backup Delay Warning',
                  level: 'Low',
                  date: 'Yesterday, 8:40 PM',
                ),
                _AlertRow(
                  title: 'Queue Congestion',
                  level: 'Medium',
                  date: 'Yesterday, 3:05 PM',
                ),
                _AlertRow(
                  title: 'Sandbox Restart Required',
                  level: 'High',
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

class _AlertRow extends StatelessWidget {
  final String title;
  final String level;
  final String date;
  final bool isLast;

  const _AlertRow({
    required this.title,
    required this.level,
    required this.date,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    switch (level) {
      case 'High':
        badgeColor = AppColors.highRisk;
        break;
      case 'Medium':
        badgeColor = AppColors.mediumRisk;
        break;
      case 'Low':
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
                  title,
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
              level,
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
            child: const Text('View'),
          ),
        ],
      ),
    );
  }
}

class _RecentEngineerActivityPanel extends StatelessWidget {
  const _RecentEngineerActivityPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Engineer Activity',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 16),
          _MiniActivityTile(
            title: 'Maintenance mode updated',
            subtitle: 'System settings changed 24 mins ago',
          ),
          SizedBox(height: 12),
          _MiniActivityTile(
            title: 'Performance scan completed',
            subtitle: 'CPU and memory audit finished successfully',
          ),
          SizedBox(height: 12),
          _MiniActivityTile(
            title: 'Backup schedule reviewed',
            subtitle: 'Auto backup interval confirmed by engineer',
          ),
          SizedBox(height: 12),
          _MiniActivityTile(
            title: 'System update checked',
            subtitle: 'No pending updates found for current version',
          ),
        ],
      ),
    );
  }
}

class _MiniActivityTile extends StatelessWidget {
  final String title;
  final String subtitle;

  const _MiniActivityTile({required this.title, required this.subtitle});

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
        border: Border.all(color: AppColors.primaryPurple.withOpacity(0.35)),
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
// Main Engineer Dashboard Screen
// ============================================================================
class EngineerDashboardScreen extends StatefulWidget {
  const EngineerDashboardScreen({super.key});

  @override
  State<EngineerDashboardScreen> createState() =>
      _EngineerDashboardScreenState();
}

class _EngineerDashboardScreenState extends State<EngineerDashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    _EngineerDashboardContent(),
    ThreatEngineModelsScreen(),
    SystemPerformanceScreen(),
    SystemSettingsScreen(),
    PeriodicRescanScreen(),
    MonthlyAppHealthScreen(),
    ModelTrainingScreen(),
  ];

  final List<String> _titles = [
    'Engineer Dashboard',
    'Threat Engine AI Models',
    'System Performance',
    'System Settings',
    'Periodic Rescan',
    'Monthly App Health',
    'Model Training',
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
                    label: 'Engineer Dashboard',
                    index: 0,
                  ),

                  _buildNavItem(
                    icon: Icons.monitor_heart_outlined,
                    label: 'Threat Engine AI Models',
                    index: 1,
                  ),
                  _buildNavItem(
                    icon: Icons.monitor_heart_outlined,
                    label: 'System Performance',
                    index: 2,
                  ),
                  _buildNavItem(
                    icon: Icons.settings_outlined,
                    label: 'System Settings',
                    index: 3,
                  ),
                  _buildNavItem(
                    icon: Icons.refresh_outlined,
                    label: 'Periodic Rescan',
                    index: 4,
                  ),
                  _buildNavItem(
                    icon: Icons.health_and_safety_outlined,
                    label: 'Monthly App Health',
                    index: 5,
                  ),
                  _buildNavItem(
                    icon: Icons.model_training_outlined,
                    label: 'Model Training',
                    index: 6,
                  ),

                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
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
                            child: Icon(
                              Icons.person_outline,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  FirebaseAuth.instance.currentUser?.displayName ?? 'Engineer User',
                                  style: const TextStyle(
                                    color: AppColors.primaryText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  FirebaseAuth.instance.currentUser?.email ?? '',
                                  style: const TextStyle(
                                    color: AppColors.secondaryText,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.logout,
                              color: AppColors.highRisk,
                              size: 20,
                            ),
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
                          ),
                        ],
                      ),
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
                              hintStyle: TextStyle(
                                color: AppColors.disabledText,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: AppColors.secondaryText,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 10,
                              ),
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
          color: isSelected ? AppColors.primaryPurple : AppColors.secondaryText,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primaryText : AppColors.secondaryText,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
