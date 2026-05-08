import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class SystemSettingsScreen extends StatelessWidget {
  const SystemSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopHeader(),
                  SizedBox(height: 10),
                  _PageTitleSection(),
                  SizedBox(height: 18),
                  _SystemConfigCard(),
                  SizedBox(height: 16),
                  _SystemPerformanceCard(),
                  SizedBox(height: 16),
                  _SystemUpdatesCard(),
                  SizedBox(height: 16),
                  _SystemBackupsCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'System Settings',
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
      'Manage system configuration, performance, updates, and backups.',
      style: TextStyle(
        color: AppColors.secondaryText,
        fontSize: 14,
      ),
    );
  }
}

class _SystemConfigCard extends StatelessWidget {
  const _SystemConfigCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Configuration',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Control maintenance behaviour and system-level processing rules.',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 18),
          _ToggleSettingRow(
            label: 'Maintenance Mode',
            subtitle: 'Temporarily restrict normal system access.',
            isOn: true,
          ),
          SizedBox(height: 12),
          _DropdownSettingRow(
            label: 'Log Retention Period',
            value: '30 Days',
          ),
          SizedBox(height: 12),
          _ToggleSettingRow(
            label: 'Enable Sandbox',
            subtitle: 'Run suspicious items in an isolated environment.',
            isOn: false,
          ),
          SizedBox(height: 12),
          _DropdownSettingRow(
            label: 'Auto Re-analysis Schedule',
            value: '30 Days',
          ),
        ],
      ),
    );
  }
}

class _SystemPerformanceCard extends StatelessWidget {
  const _SystemPerformanceCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Performance',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Monitor current resource usage and recent system behaviour.',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 18),
          _UsageBar(label: 'CPU Usage', percentText: '45%', fill: 0.45),
          SizedBox(height: 14),
          _UsageBar(label: 'Memory Usage', percentText: '60%', fill: 0.60),
          SizedBox(height: 18),
          _ChartPlaceholder(title: 'System Performance Trend'),
          SizedBox(height: 18),
          _ErrorSummaryCard(),
        ],
      ),
    );
  }
}

class _SystemUpdatesCard extends StatelessWidget {
  const _SystemUpdatesCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Updates',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Review current version details and recent deployment history.',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoLine(label: 'Current Version', value: 'v1.0.2'),
                SizedBox(height: 10),
                _InfoLine(label: 'Last Updated', value: '12 Feb 2026'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: null,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: AppColors.primaryPurple.withAlpha(70),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Check for Updates',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Update History',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              children: [
                _HistoryRow(
                  version: 'v1.0.2',
                  description: 'Security Patch',
                  date: '12 Feb 2026',
                ),
                _DividerLine(),
                _HistoryRow(
                  version: 'v1.0.1',
                  description: 'Bug Fixes',
                  date: '12 Jan 2026',
                ),
                _DividerLine(),
                _HistoryRow(
                  version: 'v1.0.0',
                  description: 'Initial Release',
                  date: '1 Jan 2026',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
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
                'Deploy Update',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemBackupsCard extends StatelessWidget {
  const _SystemBackupsCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Backups',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Track backup health and manage recovery options.',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoLine(label: 'Last Backup', value: '20 Feb 2026'),
                SizedBox(height: 10),
                _InfoLine(label: 'Backup Status', value: 'Successful'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _ToggleSettingRow(
            label: 'Auto Backup',
            subtitle: 'Automatically create scheduled system backups.',
            isOn: true,
          ),
          const SizedBox(height: 18),
          const Text(
            'Backup History',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              children: [
                _HistoryRow(
                  version: '20 Feb 2026',
                  description: 'Manual Backup',
                  date: 'Success',
                ),
                _DividerLine(),
                _HistoryRow(
                  version: '2 Feb 2026',
                  description: 'Auto Backup',
                  date: 'Success',
                ),
                _DividerLine(),
                _HistoryRow(
                  version: '15 Jan 2026',
                  description: 'Auto Backup',
                  date: 'Success',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.primaryPurple.withAlpha(70),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Backup Now',
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
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
                      'Restore Backup',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleSettingRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool isOn;

  const _ToggleSettingRow({
    required this.label,
    required this.subtitle,
    required this.isOn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
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
          ),
          const SizedBox(width: 12),
          Switch(
            value: isOn,
            onChanged: (_) {},
            activeColor: Colors.greenAccent,
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: Colors.white24,
          ),
        ],
      ),
    );
  }
}

class _DropdownSettingRow extends StatelessWidget {
  final String label;
  final String value;

  const _DropdownSettingRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primaryPurple.withAlpha(25),
              ),
            ),
            child: Row(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.secondaryText,
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  final String label;
  final String percentText;
  final double fill;

  const _UsageBar({
    required this.label,
    required this.percentText,
    required this.fill,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
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
                percentText,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            children: [
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              FractionallySizedBox(
                widthFactor: fill,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.premiumGradient,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartPlaceholder extends StatelessWidget {
  final String title;

  const _ChartPlaceholder({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 220,
          decoration: BoxDecoration(
            color: AppColors.mainBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primaryPurple.withAlpha(35),
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(18),
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
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: CustomPaint(
                    painter: _TrendLinePainter(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: AppColors.premiumGradient,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height * 0.75)
      ..lineTo(size.width * 0.15, size.height * 0.60)
      ..lineTo(size.width * 0.30, size.height * 0.65)
      ..lineTo(size.width * 0.45, size.height * 0.40)
      ..lineTo(size.width * 0.60, size.height * 0.48)
      ..lineTo(size.width * 0.75, size.height * 0.30)
      ..lineTo(size.width, size.height * 0.36);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ErrorSummaryCard extends StatelessWidget {
  const _ErrorSummaryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Error Log Summary',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12),
          Text(
            '• 12 Minor Warnings',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '• 4 Critical Errors',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({
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
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final String version;
  final String description;
  final String date;

  const _HistoryRow({
    required this.version,
    required this.description,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              version,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                color: AppColors.secondaryText,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              date,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: Colors.white10,
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