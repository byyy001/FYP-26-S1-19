import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class FlaggedReviewsScreen extends StatelessWidget {
  const FlaggedReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const reviews = [
      _FlaggedReviewData(
        scanId: '2045',
        url: 'suspicious-site.com',
        reportedBy: 'User123',
        reason: 'Phishing',
        date: 'Feb 10, 2026',
      ),
      _FlaggedReviewData(
        scanId: '2046',
        url: 'verify-login-alert.net',
        reportedBy: 'User128',
        reason: 'Malware',
        date: 'Feb 10, 2026',
      ),
      _FlaggedReviewData(
        scanId: '2047',
        url: 'bank-security-check.co',
        reportedBy: 'User135',
        reason: 'False Positive',
        date: 'Feb 11, 2026',
      ),
      _FlaggedReviewData(
        scanId: '2048',
        url: 'gift-card-prize.xyz',
        reportedBy: 'User142',
        reason: 'Phishing',
        date: 'Feb 11, 2026',
      ),
    ];

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
                        const _SummaryStrip(),
                        const SizedBox(height: 18),
                        ...reviews.map(
                          (review) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _FlaggedReviewCard(review: review),
                          ),
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

class _FlaggedReviewData {
  final String scanId;
  final String url;
  final String reportedBy;
  final String reason;
  final String date;

  const _FlaggedReviewData({
    required this.scanId,
    required this.url,
    required this.reportedBy,
    required this.reason,
    required this.date,
  });
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
            ),
            const _SidebarItem(
              icon: Icons.storage_outlined,
              label: 'Database Management',
            ),
            const _SidebarItem(
              icon: Icons.flag_outlined,
              label: 'Flagged Reviews',
              selected: true,
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
      'Flagged Reviews',
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
      'Review suspicious links reported by users or automatically flagged by the scanner.',
      style: TextStyle(
        color: AppColors.secondaryText,
        fontSize: 14,
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: const [
          Expanded(
            child: _MiniSummary(
              label: 'Pending Reviews',
              value: '12',
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: _MiniSummary(
              label: 'Reviewed Today',
              value: '5',
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: _MiniSummary(
              label: 'False Positives',
              value: '2',
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniSummary extends StatelessWidget {
  final String label;
  final String value;

  const _MiniSummary({
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlaggedReviewCard extends StatelessWidget {
  final _FlaggedReviewData review;

  const _FlaggedReviewCard({
    required this.review,
  });

  @override
  Widget build(BuildContext context) {
    final Color badgeColor;
    switch (review.reason) {
      case 'Phishing':
        badgeColor = Colors.orangeAccent;
        break;
      case 'Malware':
        badgeColor = Colors.redAccent;
        break;
      default:
        badgeColor = AppColors.primaryPurple;
    }

    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flag_outlined,
                color: AppColors.primaryPurple,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Scan ID: ${review.scanId}',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                review.date,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            review.url,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 1,
            color: Colors.white10,
          ),
          const SizedBox(height: 18),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Reported by: ',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: review.reportedBy,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Reason:',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(35),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  review.reason,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Transform.translate(
                offset: const Offset(0, -15),
                child: SizedBox(
                  width: 108,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryText,
                      side: BorderSide(
                        color: AppColors.primaryPurple.withAlpha(80),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      'Review',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
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