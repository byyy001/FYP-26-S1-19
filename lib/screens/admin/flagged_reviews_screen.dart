import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Flagged Reviews',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Review suspicious links reported by users or automatically flagged by the scanner.',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              _buildSummaryStrip(),
              const SizedBox(height: 24),
              ...reviews.map(
                (review) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _FlaggedReviewCard(review: review),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryStrip() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: const [
          Expanded(
            child: _MiniSummary(label: 'Pending Reviews', value: '12'),
          ),
          SizedBox(width: 16),
          Expanded(
            child: _MiniSummary(label: 'Reviewed Today', value: '5'),
          ),
          SizedBox(width: 16),
          Expanded(
            child: _MiniSummary(label: 'False Positives', value: '2'),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              fontSize: 28,
              fontWeight: FontWeight.bold,
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
    Color badgeColor;
    switch (review.reason) {
      case 'Phishing':
        badgeColor = AppColors.mediumRisk; // orange
        break;
      case 'Malware':
        badgeColor = AppColors.highRisk; // red
        break;
      case 'False Positive':
        badgeColor = AppColors.primaryPurple;
        break;
      default:
        badgeColor = AppColors.primaryPurple;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                review.date,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.url,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.divider, thickness: 0.5),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Reported by: ',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                ),
              ),
              Text(
                review.reportedBy,
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 20),
              const Text(
                'Reason:',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withOpacity(0.5)),
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
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryText,
                  side: BorderSide(color: AppColors.primaryPurple.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text('Review'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}