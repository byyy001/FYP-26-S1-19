import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';

class FlaggedReviewsScreen extends StatefulWidget {
  const FlaggedReviewsScreen({super.key});

  @override
  State<FlaggedReviewsScreen> createState() => _FlaggedReviewsScreenState();
}

class _FlaggedReviewsScreenState extends State<FlaggedReviewsScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary strip with live counts
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('false_reports').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return _buildSummaryStrip(pending: 0, reviewedToday: 0, falsePositives: 0);
                  }
                  final docs = snapshot.data!.docs;
                  final now = DateTime.now();
                  final startOfDay = DateTime(now.year, now.month, now.day);
                  int pending = 0;
                  int reviewedToday = 0;
                  int falsePositives = 0;
                  for (final doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] ?? '';
                    final reason = (data['reason'] ?? '').toLowerCase();
                    final submittedAt = data['submittedAt'] as Timestamp?;
                    if (status == 'pending') pending++;
                    if (status == 'reviewed' &&
                        submittedAt != null &&
                        submittedAt.toDate().isAfter(startOfDay)) {
                      reviewedToday++;
                    }
                    if (reason == 'false positive') falsePositives++;
                  }
                  return _buildSummaryStrip(
                    pending: pending,
                    reviewedToday: reviewedToday,
                    falsePositives: falsePositives,
                  );
                },
              ),
              const SizedBox(height: 24),
              // List of flagged reports (only pending, order by newest first)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('false_reports')
                    .where('status', isEqualTo: 'pending')
                    .orderBy('submittedAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: AppColors.primaryPurple),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          'Error loading reports: ${snapshot.error}',
                          style: TextStyle(color: AppColors.highRisk),
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(40),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'No pending flagged reports.',
                        style: TextStyle(color: AppColors.secondaryText),
                      ),
                    );
                  }
                  final reports = snapshot.data!.docs;
                  return Column(
                    children: reports.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _FlaggedReviewCard(
                          docId: doc.id,
                          data: data,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryStrip({
    required int pending,
    required int reviewedToday,
    required int falsePositives,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryPurple.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _MiniSummary(label: 'Pending Reviews', value: pending.toString()),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _MiniSummary(label: 'Reviewed Today', value: reviewedToday.toString()),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _MiniSummary(label: 'False Positives', value: falsePositives.toString()),
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

class _FlaggedReviewCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _FlaggedReviewCard({
    required this.docId,
    required this.data,
  });

  @override
  State<_FlaggedReviewCard> createState() => _FlaggedReviewCardState();
}

class _FlaggedReviewCardState extends State<_FlaggedReviewCard> {
  bool _isUpdating = false;

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      await FirebaseFirestore.instance
          .collection('false_reports')
          .doc(widget.docId)
          .update({'status': newStatus});

      if (newStatus == 'reviewed') {
        final userId = widget.data['userId'] as String?;
        if (userId != null && userId.isNotEmpty) {
          await FirebaseFirestore.instance.collection('user_notifications').add({
            'uid': userId,
            'type': 'admin_reviewed',
            'url': widget.data['url'] ?? '',
            'reason': widget.data['reason'] ?? '',
            'notifiedUser': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report marked as $newStatus'),
            backgroundColor: AppColors.safe,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating report: $e'),
            backgroundColor: AppColors.highRisk,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _resolveWithBlacklist() async {
    final url = widget.data['url'] as String? ?? '';
    final rawHost = Uri.tryParse(url)?.host ?? '';
    final domain = rawHost.startsWith('www.') ? rawHost.substring(4) : rawHost;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Add to Global Blacklist?',
          style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w700),
        ),
        content: Text(
          domain.isNotEmpty
              ? 'Resolving this report will add "$domain" to the global blacklist. All future scans of this domain will be flagged as malicious.'
              : 'Resolving this report will mark it as resolved.',
          style: const TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.highRisk,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isUpdating = true);
    try {
      await FirebaseFirestore.instance
          .collection('false_reports')
          .doc(widget.docId)
          .update({'status': 'resolved'});

      if (domain.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('app_config')
            .doc('threat_engine')
            .update({
          'global_blacklist': FieldValue.arrayUnion([domain]),
          'last_updated': FieldValue.serverTimestamp(),
          'version': FieldValue.increment(1),
        });
      }

      final userId = widget.data['userId'] as String?;
      if (userId != null && userId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('user_notifications').add({
          'uid': userId,
          'type': 'admin_resolved',
          'url': url,
          'domain': domain,
          'reason': widget.data['reason'] ?? '',
          'notifiedUser': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              domain.isNotEmpty
                  ? '"$domain" added to global blacklist'
                  : 'Report resolved',
            ),
            backgroundColor: AppColors.safe,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.highRisk,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.data['url'] ?? 'Unknown URL';
    final reason = widget.data['reason'] ?? 'No reason provided';
    final reportedBy = widget.data['userId'] ?? 'Unknown user';
    final submittedAt = (widget.data['submittedAt'] as Timestamp?)?.toDate();
    final scanResult = widget.data['scanResult'] as Map<String, dynamic>?;
    final verdict = scanResult?['verdict'] ?? 'Unknown';
    final riskScore = scanResult?['risk_score'] ?? 0;

    final String formattedDate = submittedAt != null
        ? '${submittedAt.day}/${submittedAt.month}/${submittedAt.year}'
        : 'Unknown date';

    // Determine badge color based on reason
    Color badgeColor;
    switch (reason.toLowerCase()) {
      case 'phishing':
        badgeColor = AppColors.mediumRisk;
        break;
      case 'malware':
        badgeColor = AppColors.highRisk;
        break;
      case 'false positive':
        badgeColor = AppColors.safe;
        break;
      default:
        badgeColor = AppColors.primaryPurple;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryPurple.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withValues(alpha: 0.1),
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
                'Reported by: $reportedBy',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                formattedDate,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            url,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verdict: $verdict (Risk: ${riskScore.toStringAsFixed(0)}%)',
                      style: TextStyle(
                        color: riskScore >= 50 ? AppColors.highRisk : AppColors.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Reason: $reason',
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  reason,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.divider, thickness: 0.5),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _isUpdating ? null : () => _updateStatus('reviewed'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryPurple),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: _isUpdating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Mark as Reviewed'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isUpdating ? null : _resolveWithBlacklist,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.safe,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: _isUpdating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Resolve'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}