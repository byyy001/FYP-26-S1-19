import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';

class BackupManagementScreen extends StatelessWidget {
  const BackupManagementScreen({super.key});

  Future<void> _createBackupRecord(BuildContext context) async {
    const String backupUrl =
        'https://linksentry-training-backend-1071145926774.asia-southeast1.run.app/create-firestore-backup';

    final String backupId = 'backup_${DateTime.now().millisecondsSinceEpoch}';

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Starting Firestore backup export...')),
      );

      final response = await http.post(
        Uri.parse(backupUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'backupId': backupId,

          // Empty list means export all collections.
          // Or specify only selected collections:
          // ['users', 'training_jobs', 'model_versions', 'datasets']
          'collectionIds': [],
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Backup failed ${response.statusCode}: ${response.body}',
        );
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Firestore backup export started successfully.'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start Firestore backup: $e')),
      );
    }
  }

  String _formatTimestamp(dynamic value) {
    if (value == null) return '-';

    if (value is Timestamp) {
      return value.toDate().toString();
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('backup_records')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];

                Map<String, dynamic>? latestBackup;

                if (docs.isNotEmpty) {
                  latestBackup = docs.first.data() as Map<String, dynamic>;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Backup Management',
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Track system backup records for Firestore data and Firebase Storage artifacts.',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: 'Last Backup',
                            value: latestBackup == null
                                ? '-'
                                : _formatTimestamp(latestBackup['createdAt']),
                            icon: Icons.backup_outlined,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _SummaryCard(
                            title: 'Backup Status',
                            value: latestBackup?['status']?.toString() ?? '-',
                            icon: Icons.check_circle_outline,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _SummaryCard(
                            title: 'Total Backup Records',
                            value: docs.length.toString(),
                            icon: Icons.history_outlined,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Start Firestore Backup',
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'This records a backup checkpoint for the system engineer. Actual Firestore export can be performed using Google Cloud commands and stored in Cloud Storage.',
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: () => _createBackupRecord(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryPurple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.add_task_outlined),
                              label: const Text(
                                'Start Firestore Backup',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Backup History',
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),

                          if (snapshot.connectionState ==
                              ConnectionState.waiting)
                            const Text(
                              'Loading backup records...',
                              style: TextStyle(color: AppColors.secondaryText),
                            )
                          else if (docs.isEmpty)
                            const Text(
                              'No backup records found yet.',
                              style: TextStyle(color: AppColors.secondaryText),
                            )
                          else
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingTextStyle: const TextStyle(
                                  color: AppColors.primaryText,
                                  fontWeight: FontWeight.w700,
                                ),
                                dataTextStyle: const TextStyle(
                                  color: AppColors.secondaryText,
                                  fontSize: 12,
                                ),
                                columns: const [
                                  DataColumn(label: Text('Backup ID')),
                                  DataColumn(label: Text('Type')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Created At')),
                                  DataColumn(label: Text('Storage Location')),
                                ],
                                rows: docs.map((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          data['backupId']?.toString() ??
                                              doc.id,
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          data['backupType']?.toString() ?? '-',
                                        ),
                                      ),
                                      DataCell(
                                        Text(data['status']?.toString() ?? '-'),
                                      ),
                                      DataCell(
                                        Text(
                                          _formatTimestamp(data['createdAt']),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          data['storageLocation']?.toString() ??
                                              '-',
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Backup Scope',
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'The backup scope includes Firestore collections such as users, scans, datasets, training_jobs, model_versions, and system_settings. Firebase Storage artifacts such as uploaded datasets, candidate models, active models, metrics files, confusion matrices, and performance summaries are also included in the backup plan.',
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryPurple, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 18,
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

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryPurple.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
