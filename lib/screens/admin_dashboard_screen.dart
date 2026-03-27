import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: SafeArea(
        child: Row(
          children: [
            const _AdminSidebar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1380),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _TopHeader(),
                        const SizedBox(height: 18),

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
                                      children: const [
                                        _StatCard(
                                          title: 'Total Users',
                                          value: '1,234',
                                          icon: Icons.people_outline,
                                        ),
                                        _StatCard(
                                          title: 'Scans Today',
                                          value: '675',
                                          icon: Icons.qr_code_scanner_outlined,
                                        ),
                                        _StatCard(
                                          title: 'High Risk Detected',
                                          value: '87',
                                          icon: Icons.warning_amber_rounded,
                                        ),
                                        _StatCard(
                                          title: 'Flagged Reports',
                                          value: '11',
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
                                  children: const [
                                    _StatCard(
                                      title: 'Total Users',
                                      value: '1,234',
                                      icon: Icons.people_outline,
                                    ),
                                    _StatCard(
                                      title: 'Scans Today',
                                      value: '675',
                                      icon: Icons.qr_code_scanner_outlined,
                                    ),
                                    _StatCard(
                                      title: 'High Risk Detected',
                                      value: '87',
                                      icon: Icons.warning_amber_rounded,
                                    ),
                                    _StatCard(
                                      title: 'Flagged Reports',
                                      value: '11',
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          right: BorderSide(
            color: AppColors.primaryPurple.withAlpha(45),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: AppColors.premiumGradient,
                    ),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'LinkSentry Admin',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const _SidebarItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              selected: true,
            ),
            const _SidebarItem(
              icon: Icons.people_outline,
              label: 'User Management',
            ),
            const _SidebarItem(
              icon: Icons.security_outlined,
              label: 'Security Management',
            ),
            const _SidebarItem(
              icon: Icons.analytics_outlined,
              label: 'Scan Statistics',
            ),
            const _SidebarItem(
              icon: Icons.storage_outlined,
              label: 'Database Management',
            ),
            const _SidebarItem(
              icon: Icons.flag_outlined,
              label: 'Flagged Reviews',
            ),
            const _SidebarItem(
              icon: Icons.memory_outlined,
              label: 'System Usage',
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.mainBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primaryPurple.withAlpha(45),
                ),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person_outline, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin User',
                          style: TextStyle(
                            color: AppColors.primaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'admin@linksentry.com',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.logout, color: AppColors.secondaryText, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _SidebarItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primaryPurple.withAlpha(35)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: selected
            ? Border.all(color: AppColors.primaryPurple.withAlpha(80))
            : null,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: selected
              ? AppColors.primaryPurple
              : AppColors.secondaryText,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: selected
                ? AppColors.primaryText
                : AppColors.secondaryText,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        onTap: () {
          // TODO: connect navigation later
        },
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin Dashboard',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Monitor system activity, flagged scans, and key platform metrics.',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 320,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primaryPurple.withAlpha(40),
            ),
          ),
          child: const TextField(
            style: TextStyle(color: AppColors.primaryText),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Search users, URLs, reports...',
              hintStyle: TextStyle(color: AppColors.disabledText),
              prefixIcon: Icon(Icons.search, color: AppColors.secondaryText),
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminProfileCard extends StatelessWidget {
  const _AdminProfileCard();

  @override
  Widget build(BuildContext context) {
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
          const Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white24,
                child: Icon(
                  Icons.person_outline,
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
                      'exampleemail.com',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
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
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Last Login',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  'Today, 08:42 AM',
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
        border: Border.all(
          color: AppColors.primaryPurple.withAlpha(35),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withAlpha(18),
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
                color: AppColors.primaryPurple.withAlpha(35),
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
                            (index) => Container(
                              height: 1,
                              color: Colors.white10,
                            ),
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

  const _Bar({
    required this.height,
  });

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
            style: const TextStyle(
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

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
        badgeColor = Colors.redAccent;
        break;
      case 'High Risk':
        badgeColor = Colors.orangeAccent;
        break;
      default:
        badgeColor = AppColors.primaryPurple;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Colors.white10),
              ),
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
              color: badgeColor.withAlpha(35),
              borderRadius: BorderRadius.circular(999),
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
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }
}

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
          color: AppColors.primaryPurple.withAlpha(35),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withAlpha(14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}