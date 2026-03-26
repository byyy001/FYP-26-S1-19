import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ScanStatisticsScreen extends StatelessWidget {
  const ScanStatisticsScreen({super.key});

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
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _TopHeader(),
                        const SizedBox(height: 10),
                        const _PageTitleSection(),
                        const SizedBox(height: 18),
                        const _DateFilterCard(),
                        const SizedBox(height: 16),
                        const _SummaryStatsCard(),
                        const SizedBox(height: 16),
                        const _DailyScansCard(),
                        const SizedBox(height: 16),
                        const _ThreatDistributionCard(),
                        const SizedBox(height: 18),
                        const _ExportButton(),
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
              selected: true,
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
        onTap: () {},
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Scan Statistics',
      style: TextStyle(
        color: AppColors.primaryText,
        fontSize: 30,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _PageTitleSection extends StatelessWidget {
  const _PageTitleSection();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'View scan trends, risk distribution, and activity over time.',
      style: TextStyle(
        color: AppColors.secondaryText,
        fontSize: 14,
      ),
    );
  }
}

class _DateFilterCard extends StatelessWidget {
  const _DateFilterCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          const Icon(Icons.date_range_outlined, color: AppColors.secondaryText),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Date Range',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Last 7 Days',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.primaryPurple.withAlpha(35)),
            ),
            child: const Text(
              'Change',
              style: TextStyle(
                color: AppColors.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStatsCard extends StatelessWidget {
  const _SummaryStatsCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 18),
          _SummaryLine(label: 'Total Scans', value: '12,540'),
          SizedBox(height: 14),
          _SummaryLine(label: 'High Risk', value: '1,245'),
          SizedBox(height: 14),
          _SummaryLine(label: 'Medium Risk', value: '3,210'),
          SizedBox(height: 14),
          _SummaryLine(label: 'Low Risk', value: '8,085'),
          SizedBox(height: 14),
          _SummaryLine(label: 'Average Scans Per Day', value: '1,791'),
          SizedBox(height: 14),
          _SummaryLine(label: 'Peak Scan Day', value: 'Friday'),
          SizedBox(height: 14),
          _SummaryLine(label: 'Most Common Threat Type', value: 'Phishing'),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DailyScansCard extends StatelessWidget {
  const _DailyScansCard();

  @override
  Widget build(BuildContext context) {
    const values = [90.0, 120.0, 110.0, 150.0, 180.0, 160.0, 130.0];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Scans (Last 7 Days)',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 280,
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

class _ThreatDistributionCard extends StatelessWidget {
  const _ThreatDistributionCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Threat Type Distribution',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryPurple.withAlpha(35),
              ),
            ),
            child: const Column(
              children: [
                _DistributionRow(
                  label: 'Phishing',
                  percent: '38%',
                  widthFactor: 0.38,
                ),
                SizedBox(height: 14),
                _DistributionRow(
                  label: 'Malware',
                  percent: '27%',
                  widthFactor: 0.27,
                ),
                SizedBox(height: 14),
                _DistributionRow(
                  label: 'Suspicious Ads',
                  percent: '19%',
                  widthFactor: 0.19,
                ),
                SizedBox(height: 14),
                _DistributionRow(
                  label: 'Insecure Scripts',
                  percent: '16%',
                  widthFactor: 0.16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  final String label;
  final String percent;
  final double widthFactor;

  const _DistributionRow({
    required this.label,
    required this.percent,
    required this.widthFactor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Row(
              children: [
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
                  percent,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Stack(
              children: [
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Container(
                  height: 10,
                  width: constraints.maxWidth * widthFactor,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.premiumGradient,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Export Report',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
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