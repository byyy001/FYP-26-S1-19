import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';

class VerdictNotificationsScreen extends StatefulWidget {
  const VerdictNotificationsScreen({super.key});

  @override
  State<VerdictNotificationsScreen> createState() => _VerdictNotificationsScreenState();
}

class _VerdictNotificationsScreenState extends State<VerdictNotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _fetchAndMarkRead();
  }

  Future<List<Map<String, dynamic>>> _fetchAndMarkRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    // Fetch verdict changes from safe_scans
    final verdictSnapshot = await FirebaseFirestore.instance
        .collection('safe_scans')
        .where('uid', isEqualTo: user.uid)
        .where('rescanned', isEqualTo: true)
        .get();

    final changed = verdictSnapshot.docs.where((doc) {
      final verdict = doc.data()['rescannedVerdict']?.toString().toLowerCase() ?? '';
      return verdict.isNotEmpty && verdict != 'safe';
    }).toList();

    // Fetch admin review notifications
    final adminSnapshot = await FirebaseFirestore.instance
        .collection('user_notifications')
        .where('uid', isEqualTo: user.uid)
        .get();

    // Mark all unread docs in a single batch
    final unreadVerdict = changed.where((doc) => doc.data()['notifiedUser'] != true).toList();
    final unreadAdmin = adminSnapshot.docs.where((doc) => doc.data()['notifiedUser'] != true).toList();
    if (unreadVerdict.isNotEmpty || unreadAdmin.isNotEmpty) {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in unreadVerdict) { batch.update(doc.reference, {'notifiedUser': true}); }
      for (final doc in unreadAdmin) { batch.update(doc.reference, {'notifiedUser': true}); }
      await batch.commit();
    }

    // Combine both types, tagged with notificationType
    final verdictResults = changed.map((doc) => {
      'id': doc.id,
      'notificationType': 'verdict_change',
      ...doc.data(),
    }).toList();

    final adminResults = adminSnapshot.docs.map((doc) => {
      'id': doc.id,
      'notificationType': doc.data()['type'] ?? 'admin_reviewed',
      ...doc.data(),
    }).toList();

    final result = [...verdictResults, ...adminResults];
    result.sort((a, b) {
      final aTs = a['rescannedAt'] ?? a['createdAt'];
      final bTs = b['rescannedAt'] ?? b['createdAt'];
      if (aTs is Timestamp && bTs is Timestamp) return bTs.compareTo(aTs);
      return 0;
    });
    return result;
  }

  String _formatTimestamp(dynamic ts) {
    if (ts is Timestamp) return DateFormat('MMM d, hh:mm a').format(ts.toDate());
    return '—';
  }

  Color _verdictColor(String verdict) {
    switch (verdict.toLowerCase()) {
      case 'malicious':
        return AppColors.highRisk;
      case 'suspicious':
      case 'low risk':
        return AppColors.mediumRisk;
      default:
        return AppColors.secondaryText;
    }
  }

  IconData _verdictIcon(String verdict) {
    switch (verdict.toLowerCase()) {
      case 'malicious':
        return Icons.cancel_rounded;
      case 'suspicious':
      case 'low risk':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: AppColors.primaryText),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: AppColors.divider.withValues(alpha: 0.6), thickness: 0.6, height: 1),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.primaryPurple),
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) return _buildEmptyState();

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildNotificationCard(notifications[index]),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_rounded, color: AppColors.secondaryText, size: 56),
            SizedBox(height: 16),
            Text(
              'No notifications',
              style: TextStyle(color: AppColors.primaryText, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            Text(
              'You\'ll be notified here if any previously safe URL is later found to be a threat.',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final type = notification['notificationType'] as String? ?? 'verdict_change';
    if (type == 'admin_reviewed') return _buildAdminReviewCard(notification);
    if (type == 'admin_resolved') return _buildAdminResolvedCard(notification);
    return _buildVerdictChangeCard(notification);
  }

  Widget _buildVerdictChangeCard(Map<String, dynamic> notification) {
    final verdict = notification['rescannedVerdict']?.toString() ?? 'Unknown';
    final color = _verdictColor(verdict);
    final icon = _verdictIcon(verdict);
    final url = notification['url']?.toString() ?? '—';
    final rescannedAt = notification['rescannedAt'];

    return _NotificationCardShell(
      color: color,
      icon: icon,
      title: 'URL Threat Detected',
      description: 'A URL you previously scanned as safe has been flagged as $verdict.',
      url: url,
      badgeLabel: verdict,
      badgeColor: color,
      timestamp: _formatTimestamp(rescannedAt),
    );
  }

  Widget _buildAdminReviewCard(Map<String, dynamic> notification) {
    final url = notification['url']?.toString() ?? '—';
    final reason = notification['reason']?.toString() ?? '';
    final createdAt = notification['createdAt'];
    const color = AppColors.primaryPurple;

    return _NotificationCardShell(
      color: color,
      icon: Icons.admin_panel_settings_outlined,
      title: 'Report Reviewed',
      description: reason.isNotEmpty
          ? 'An admin has reviewed your flagged report (reason: $reason). No change to the verdict was made.'
          : 'An admin has reviewed your flagged report. No change to the verdict was made.',
      url: url,
      badgeLabel: 'Reviewed',
      badgeColor: color,
      timestamp: _formatTimestamp(createdAt),
    );
  }

  Widget _buildAdminResolvedCard(Map<String, dynamic> notification) {
    final url = notification['url']?.toString() ?? '—';
    final domain = notification['domain']?.toString() ?? '';
    final createdAt = notification['createdAt'];
    const color = AppColors.highRisk;

    return _NotificationCardShell(
      color: color,
      icon: Icons.gpp_bad_outlined,
      title: 'Report Resolved — Verdict Updated',
      description: domain.isNotEmpty
          ? 'An admin has resolved your report. "$domain" has been added to the global blacklist. The verdict for this URL has been updated to Malicious.'
          : 'An admin has resolved your report. The URL has been added to the global blacklist and its verdict has been updated to Malicious.',
      url: url,
      badgeLabel: 'Resolved',
      badgeColor: color,
      timestamp: _formatTimestamp(createdAt),
    );
  }
}

class _NotificationCardShell extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String description;
  final String url;
  final String badgeLabel;
  final Color badgeColor;
  final String timestamp;

  const _NotificationCardShell({
    required this.color,
    required this.icon,
    required this.title,
    required this.description,
    required this.url,
    required this.badgeLabel,
    required this.badgeColor,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.mainBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    url,
                    style: const TextStyle(color: AppColors.primaryText, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timestamp,
                      style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
