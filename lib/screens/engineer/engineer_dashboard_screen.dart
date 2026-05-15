import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../login_screen.dart';
import 'threat_engine_models_screen.dart';
import 'system_performance_screen.dart';
import 'system_settings_screen.dart';
import 'periodic_rescan_screen.dart';
import 'monthly_app_health_screen.dart';
import 'model_training_screen.dart';
import 'backup_management_screen.dart';

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
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EngineerProfileCard(),

              SizedBox(height: 18),

              _ThreatEngineModelSummaryPanel(),

              SizedBox(height: 18),

              _PeriodicRescanSummaryPanel(),

              SizedBox(height: 18),

              _ModelTrainingSummaryPanel(),

              SizedBox(height: 24),
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
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : 'Engineer User';
    final email = user?.email ?? 'engineer@linksentry.com';

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
          Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white24,
                child: Icon(
                  Icons.engineering_outlined,
                  color: Colors.white,
                  size: 28,
                ),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      email,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    const Text(
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
                  'Dashboard Status',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  'Live engineer session',
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

class _ThreatEngineModelSummaryPanel extends StatelessWidget {
  const _ThreatEngineModelSummaryPanel();

  static const List<_DashboardModelInfo> _modelOrder = [
    _DashboardModelInfo(
      type: 'logistic_regression',
      label: 'Logistic Regression',
      icon: Icons.memory_outlined,
    ),
    _DashboardModelInfo(
      type: 'decision_tree',
      label: 'Decision Tree',
      icon: Icons.account_tree_outlined,
    ),
    _DashboardModelInfo(
      type: 'xgboost',
      label: 'XGBoost',
      icon: Icons.bolt_outlined,
    ),
    _DashboardModelInfo(
      type: 'lightgbm',
      label: 'LightGBM',
      icon: Icons.flash_on_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('model_versions')
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _Panel(
            child: Text(
              'Unable to load model summary: ${snapshot.error}',
              style: const TextStyle(color: AppColors.highRisk, fontSize: 14),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Panel(
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text(
                  'Loading threat engine model summary...',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final Map<String, Map<String, dynamic>> activeModels = {};

        for (final doc in docs) {
          final data = doc.data();
          final modelType = data['modelType']?.toString();

          if (modelType != null && modelType.isNotEmpty) {
            activeModels[modelType] = data;
          }
        }

        return _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Threat Engine Model Summary',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Overview of the active machine learning models used by the scan engine.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
              ),
              const SizedBox(height: 18),

              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth > 900;
                  final double cardWidth = isWide
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final model in _modelOrder)
                        SizedBox(
                          width: cardWidth,
                          child: _DashboardModelCard(
                            model: model,
                            data: activeModels[model.type],
                          ),
                        ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 14),

              _EnsembleSummaryCard(
                activeModelCount: activeModels.length,
                totalModelCount: _modelOrder.length,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardModelInfo {
  final String type;
  final String label;
  final IconData icon;

  const _DashboardModelInfo({
    required this.type,
    required this.label,
    required this.icon,
  });
}

class _DashboardModelCard extends StatelessWidget {
  final _DashboardModelInfo model;
  final Map<String, dynamic>? data;

  const _DashboardModelCard({required this.model, required this.data});

  @override
  Widget build(BuildContext context) {
    final bool isActive = data != null;
    final accuracy = _formatAccuracy(data?['accuracy']);
    final macroF1 = _formatMetric(data?['macroF1']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? AppColors.primaryPurple.withOpacity(0.35)
              : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            model.icon,
            color: isActive ? AppColors.primaryPurple : AppColors.disabledText,
            size: 24,
          ),
          const SizedBox(height: 12),
          Text(
            model.label,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isActive ? 'Active' : 'Not active',
            style: TextStyle(
              color: isActive ? Colors.greenAccent : AppColors.disabledText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _SmallModelMetric(label: 'Accuracy', value: accuracy),
          const SizedBox(height: 6),
          _SmallModelMetric(label: 'Macro F1', value: macroF1),
        ],
      ),
    );
  }

  static String _formatAccuracy(dynamic value) {
    if (value == null) return '-';

    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null) return '-';

    if (number <= 1) {
      return '${(number * 100).toStringAsFixed(2)}%';
    }

    return '${number.toStringAsFixed(2)}%';
  }

  static String _formatMetric(dynamic value) {
    if (value == null) return '-';

    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null) return '-';

    return number.toStringAsFixed(4);
  }
}

class _SmallModelMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SmallModelMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EnsembleSummaryCard extends StatelessWidget {
  final int activeModelCount;
  final int totalModelCount;

  const _EnsembleSummaryCard({
    required this.activeModelCount,
    required this.totalModelCount,
  });

  @override
  Widget build(BuildContext context) {
    final bool ready = activeModelCount == totalModelCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryPurple.withOpacity(0.45)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.hub_outlined,
            color: AppColors.primaryPurple,
            size: 26,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ensemble Verdict Layer',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ready
                      ? 'Combines all 4 active models to support the final scan verdict.'
                      : '$activeModelCount of $totalModelCount models are currently active.',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: ready
                  ? Colors.greenAccent.withOpacity(0.16)
                  : Colors.orangeAccent.withOpacity(0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: ready
                    ? Colors.greenAccent.withOpacity(0.55)
                    : Colors.orangeAccent.withOpacity(0.55),
              ),
            ),
            child: Text(
              ready ? 'Ready' : 'Partial',
              style: TextStyle(
                color: ready ? Colors.greenAccent : Colors.orangeAccent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodicRescanSummaryPanel extends StatelessWidget {
  const _PeriodicRescanSummaryPanel();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('safe_scans')
          .orderBy('scannedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _Panel(
            child: Text(
              'Unable to load periodic rescan summary: ${snapshot.error}',
              style: const TextStyle(color: AppColors.highRisk, fontSize: 14),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Panel(
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text(
                  'Loading periodic rescan summary...',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final scans = docs.map((doc) => doc.data()).toList();

        final totalSafeScans = scans.length;

        final rescannedCount = scans.where((scan) {
          return scan['rescanned'] == true;
        }).length;

        final changedVerdictCount = scans.where((scan) {
          final verdict = scan['rescannedVerdict']?.toString().toLowerCase();
          return verdict != null && verdict != 'safe' && verdict != 'error';
        }).length;

        final pendingCount = totalSafeScans - rescannedCount;

        final latestRescan = _findLatestTimestamp(scans, 'rescannedAt');
        final latestScan = _findLatestTimestamp(scans, 'scannedAt');

        return _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Periodic Rescan Summary',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Overview of saved safe URLs that are monitored for verdict changes during scheduled rescans.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
              ),
              const SizedBox(height: 18),

              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth > 900;
                  final double cardWidth = isWide
                      ? (constraints.maxWidth - 36) / 4
                      : constraints.maxWidth;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _RescanMetricTile(
                          icon: Icons.shield_outlined,
                          label: 'Safe URLs Tracked',
                          value: '$totalSafeScans',
                          subtitle: 'Stored in safe scan records',
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _RescanMetricTile(
                          icon: Icons.refresh_rounded,
                          label: 'Already Rescanned',
                          value: '$rescannedCount',
                          subtitle: 'URLs checked again',
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _RescanMetricTile(
                          icon: Icons.pending_actions_outlined,
                          label: 'Pending Rescan',
                          value: '$pendingCount',
                          subtitle: 'URLs not rescanned yet',
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _RescanMetricTile(
                          icon: Icons.warning_amber_rounded,
                          label: 'Verdict Changes',
                          value: '$changedVerdictCount',
                          subtitle: 'Changed after rescan',
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.mainBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primaryPurple.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_outlined,
                      color: AppColors.primaryPurple,
                      size: 24,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Latest Rescan Activity',
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            latestRescan == null
                                ? 'No completed rescans recorded yet.'
                                : 'Last rescan completed on ${_formatDateTime(latestRescan)}.',
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      latestScan == null
                          ? 'No scan date'
                          : 'Latest safe scan: ${_formatDateTime(latestScan)}',
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static DateTime? _findLatestTimestamp(
    List<Map<String, dynamic>> scans,
    String field,
  ) {
    DateTime? latest;

    for (final scan in scans) {
      final value = scan[field];
      DateTime? date;

      if (value is Timestamp) {
        date = value.toDate();
      } else if (value is DateTime) {
        date = value;
      }

      if (date != null && (latest == null || date.isAfter(latest))) {
        latest = date;
      }
    }

    return latest;
  }

  static String _formatDateTime(DateTime date) {
    final hour = date.hour > 12
        ? date.hour - 12
        : date.hour == 0
        ? 12
        : date.hour;

    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${date.day}/${date.month}/${date.year}, $hour:$minute $period';
  }
}

class _RescanMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;

  const _RescanMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 155,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryPurple, size: 24),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ModelTrainingSummaryPanel extends StatelessWidget {
  const _ModelTrainingSummaryPanel();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('model_versions')
          .snapshots(),
      builder: (context, modelSnapshot) {
        if (modelSnapshot.hasError) {
          return _Panel(
            child: Text(
              'Unable to load model training summary: ${modelSnapshot.error}',
              style: const TextStyle(color: AppColors.highRisk, fontSize: 14),
            ),
          );
        }

        if (modelSnapshot.connectionState == ConnectionState.waiting) {
          return const _Panel(
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text(
                  'Loading model training summary...',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        final modelDocs = modelSnapshot.data?.docs ?? [];

        final candidateModels = modelDocs.where((doc) {
          final data = doc.data();
          return data['status']?.toString().toLowerCase() == 'candidate';
        }).toList();

        candidateModels.sort((a, b) {
          final aData = a.data();
          final bData = b.data();

          final aTime =
              _extractDateTime(aData['createdAt']) ??
              _extractDateTime(aData['trainedAt']) ??
              _extractDateTime(aData['deployedAt']) ??
              DateTime.fromMillisecondsSinceEpoch(0);

          final bTime =
              _extractDateTime(bData['createdAt']) ??
              _extractDateTime(bData['trainedAt']) ??
              _extractDateTime(bData['deployedAt']) ??
              DateTime.fromMillisecondsSinceEpoch(0);

          return bTime.compareTo(aTime);
        });

        final latestCandidate = candidateModels.isNotEmpty
            ? candidateModels.first.data()
            : null;

        final latestModelName =
            latestCandidate?['modelDisplayName']?.toString() ??
            _formatModelType(latestCandidate?['modelType']) ??
            'No candidate model';

        final latestModelVersion =
            latestCandidate?['modelVersionId']?.toString() ??
            latestCandidate?['activeModelVersionId']?.toString() ??
            latestCandidate?['version']?.toString() ??
            '-';

        final accuracy = _formatPercent(latestCandidate?['accuracy']);
        final macroF1 = _formatScore(latestCandidate?['macroF1']);
        final candidateStatus = latestCandidate?['status']?.toString() ?? '-';

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('datasets')
              .where('status', isEqualTo: 'uploaded')
              .snapshots(),
          builder: (context, datasetSnapshot) {
            final datasetCount = datasetSnapshot.data?.docs.length ?? 0;
            final datasetText =
                datasetSnapshot.connectionState == ConnectionState.waiting
                ? 'Loading...'
                : '$datasetCount';

            return _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Model Training Summary',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Overview of uploaded datasets and candidate models prepared for deployment.',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 18),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isWide = constraints.maxWidth > 900;
                      final double cardWidth = isWide
                          ? (constraints.maxWidth - 36) / 4
                          : constraints.maxWidth;

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: _TrainingMetricTile(
                              icon: Icons.dataset_outlined,
                              label: 'Uploaded Datasets',
                              value: datasetText,
                              subtitle: 'Ready for retraining',
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _TrainingMetricTile(
                              icon: Icons.model_training_outlined,
                              label: 'Candidate Models',
                              value: '${candidateModels.length}',
                              subtitle: 'Waiting for review',
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _TrainingMetricTile(
                              icon: Icons.analytics_outlined,
                              label: 'Candidate Accuracy',
                              value: accuracy,
                              subtitle: 'Latest candidate',
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _TrainingMetricTile(
                              icon: Icons.score_outlined,
                              label: 'Candidate Macro F1',
                              value: macroF1,
                              subtitle: 'Latest candidate',
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.mainBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primaryPurple.withOpacity(0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.rocket_launch_outlined,
                          color: AppColors.primaryPurple,
                          size: 24,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                latestModelName,
                                style: const TextStyle(
                                  color: AppColors.primaryText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                latestCandidate == null
                                    ? 'No candidate model has been generated yet.'
                                    : 'Version: $latestModelVersion',
                                style: const TextStyle(
                                  color: AppColors.secondaryText,
                                  fontSize: 12.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: latestCandidate == null
                                ? Colors.orangeAccent.withOpacity(0.16)
                                : AppColors.primaryPurple.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: latestCandidate == null
                                  ? Colors.orangeAccent.withOpacity(0.55)
                                  : AppColors.primaryPurple.withOpacity(0.55),
                            ),
                          ),
                          child: Text(
                            latestCandidate == null
                                ? 'No Candidate'
                                : candidateStatus,
                            style: TextStyle(
                              color: latestCandidate == null
                                  ? Colors.orangeAccent
                                  : AppColors.primaryPurple,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static DateTime? _extractDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String? _formatModelType(dynamic value) {
    final modelType = value?.toString();

    if (modelType == null || modelType.isEmpty) return null;

    switch (modelType) {
      case 'logistic_regression':
        return 'Logistic Regression';
      case 'decision_tree':
        return 'Decision Tree';
      case 'xgboost':
        return 'XGBoost';
      case 'lightgbm':
        return 'LightGBM';
      default:
        return modelType;
    }
  }

  static String _formatPercent(dynamic value) {
    if (value == null) return '-';

    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null) return '-';

    if (number <= 1) {
      return '${(number * 100).toStringAsFixed(2)}%';
    }

    return '${number.toStringAsFixed(2)}%';
  }

  static String _formatScore(dynamic value) {
    if (value == null) return '-';

    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null) return '-';

    return number.toStringAsFixed(4);
  }
}

class _TrainingMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;

  const _TrainingMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 155,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryPurple, size: 24),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
    BackupManagementScreen(),
  ];

  final List<String> _titles = [
    'Engineer Dashboard',
    'Threat Engine AI Models',
    'System Performance',
    'System Settings',
    'Periodic Rescan',
    'Monthly App Health',
    'Model Training',
    'Backup Management',
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
                      height: 130,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        children: [
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
                          _buildNavItem(
                            icon: Icons.backup_outlined,
                            label: 'Backup Management',
                            index: 7,
                          ),
                        ],
                      ),
                    ),
                  ),
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
                                  FirebaseAuth
                                          .instance
                                          .currentUser
                                          ?.displayName ??
                                      'Engineer User',
                                  style: const TextStyle(
                                    color: AppColors.primaryText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  FirebaseAuth.instance.currentUser?.email ??
                                      '',
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
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
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
