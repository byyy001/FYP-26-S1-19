import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

class ThreatEngineModelsScreen extends StatelessWidget {
  const ThreatEngineModelsScreen({super.key});

  String _formatPercent(dynamic value) {
    if (value == null) return '-';
    final double number = (value as num).toDouble();
    return '${(number * 100).toStringAsFixed(2)}%';
  }

  String _formatScore(dynamic value) {
    if (value == null) return '-';
    final double number = (value as num).toDouble();
    return number.toStringAsFixed(4);
  }

  String _formatTimestamp(dynamic value) {
    if (value == null) return '-';

    if (value is Timestamp) {
      return value.toDate().toString();
    }

    return value.toString();
  }

  String _displayModelName(Map<String, dynamic> data) {
    final displayName = data['modelDisplayName']?.toString();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final modelType = data['modelType']?.toString() ?? '-';

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

  Map<String, dynamic>? _latestActiveModelForType(
    List<QueryDocumentSnapshot> docs,
    String modelType,
  ) {
    final matchedDocs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['modelType'] == modelType && data['status'] == 'active';
    }).toList();

    if (matchedDocs.isEmpty) return null;

    matchedDocs.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;

      final DateTime aTime = aData['deployedAt'] is Timestamp
          ? (aData['deployedAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);

      final DateTime bTime = bData['deployedAt'] is Timestamp
          ? (bData['deployedAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);

      return bTime.compareTo(aTime);
    });

    return matchedDocs.first.data() as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    const modelConfigs = [
      {
        'modelType': 'logistic_regression',
        'displayName': 'Logistic Regression',
        'shortName': 'LR',
      },
      {
        'modelType': 'decision_tree',
        'displayName': 'Decision Tree',
        'shortName': 'DT',
      },
      {'modelType': 'xgboost', 'displayName': 'XGBoost', 'shortName': 'XGB'},
      {'modelType': 'lightgbm', 'displayName': 'LightGBM', 'shortName': 'LGBM'},
    ];

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('model_versions')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _Panel(
                    child: Text(
                      'Loading model versions...',
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _Panel(
                    child: Text(
                      'Failed to load model versions: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Threat Engine AI Models',
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'View deployed threat detection models and their latest evaluation results.',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),

                    for (final config in modelConfigs) ...[
                      _ModelVersionCard(
                        displayName: config['displayName']!,
                        shortName: config['shortName']!,
                        modelType: config['modelType']!,
                        data: _latestActiveModelForType(
                          docs,
                          config['modelType']!,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
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

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();

    Color statusColor;
    if (normalized == 'active') {
      statusColor = Colors.greenAccent;
    } else if (normalized == 'candidate') {
      statusColor = Colors.orangeAccent;
    } else if (normalized == 'not trained') {
      statusColor = Colors.grey;
    } else {
      statusColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: statusColor),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: statusColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ModelVersionCard extends StatelessWidget {
  final String displayName;
  final String shortName;
  final String modelType;
  final Map<String, dynamic>? data;

  const _ModelVersionCard({
    required this.displayName,
    required this.shortName,
    required this.modelType,
    required this.data,
  });

  String _formatPercent(dynamic value) {
    if (value == null) return '-';
    final double number = (value as num).toDouble();
    return '${(number * 100).toStringAsFixed(2)}%';
  }

  String _formatScore(dynamic value) {
    if (value == null) return '-';
    final double number = (value as num).toDouble();
    return number.toStringAsFixed(4);
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
    final bool isAvailable = data != null;

    final String modelVersionId =
        data?['modelVersionId']?.toString() ??
        data?['activeModelVersionId']?.toString() ??
        '-';

    final String modelFilePath =
        data?['activeModelFilePath']?.toString() ??
        data?['modelFilePath']?.toString() ??
        '-';

    final String scalerFilePath =
        data?['activeScalerFilePath']?.toString() ??
        data?['scalerFilePath']?.toString() ??
        '-';

    final String confusionMatrixPath =
        data?['confusionMatrixPath']?.toString() ?? '';

    final String metricsFilePath = data?['metricsFilePath']?.toString() ?? '';

    final String deployedAt = _formatTimestamp(data?['deployedAt']);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.memory_outlined,
                color: AppColors.primaryPurple,
                size: 32,
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
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAvailable
                          ? 'Version: $modelVersionId'
                          : '$shortName model has not been deployed yet.',
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: isAvailable ? 'Active' : 'Not Trained'),
            ],
          ),

          if (!isAvailable) ...[
            const SizedBox(height: 18),
            const Text(
              'No active model version found yet. Train and deploy this model from the Model Training page.',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
            ),
          ] else ...[
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, constraints) {
                final bool isWide = constraints.maxWidth > 850;

                final cards = [
                  _MetricCard(
                    title: 'Accuracy',
                    value: _formatPercent(data!['accuracy']),
                    icon: Icons.analytics_outlined,
                  ),
                  _MetricCard(
                    title: 'Macro Precision',
                    value: _formatScore(data!['macroPrecision']),
                    icon: Icons.track_changes_outlined,
                  ),
                  _MetricCard(
                    title: 'Macro Recall',
                    value: _formatScore(data!['macroRecall']),
                    icon: Icons.show_chart_outlined,
                  ),
                  _MetricCard(
                    title: 'Macro F1',
                    value: _formatScore(data!['macroF1']),
                    icon: Icons.score_outlined,
                  ),
                ];

                if (isWide) {
                  return Row(
                    children: [
                      for (int i = 0; i < cards.length; i++) ...[
                        Expanded(child: cards[i]),
                        if (i != cards.length - 1) const SizedBox(width: 14),
                      ],
                    ],
                  );
                }

                return Column(
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      cards[i],
                      if (i != cards.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.mainBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primaryPurple.withOpacity(0.20),
                ),
              ),
              child: Column(
                children: [
                  _InfoRow(label: 'Model Type', value: modelType),
                  const _DividerLine(),
                  _InfoRow(label: 'Model File', value: modelFilePath),
                  const _DividerLine(),
                  _InfoRow(label: 'Scaler File', value: scalerFilePath),
                  const _DividerLine(),
                  _InfoRow(label: 'Deployed At', value: deployedAt),
                ],
              ),
            ),

            const SizedBox(height: 18),

            LayoutBuilder(
              builder: (context, constraints) {
                final bool isWide = constraints.maxWidth > 800;

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(
                        child: _EvaluationImageCard(
                          title: 'Confusion Matrix',
                          storagePath: confusionMatrixPath,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _PerformanceSummaryTableCard(
                          title: 'Performance Summary',
                          metricsPath: metricsFilePath,
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    _EvaluationImageCard(
                      title: 'Confusion Matrix',
                      storagePath: confusionMatrixPath,
                    ),
                    const SizedBox(height: 16),
                    _PerformanceSummaryTableCard(
                      title: 'Performance Summary',
                      metricsPath: metricsFilePath,
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _EvaluationImageCard extends StatelessWidget {
  final String title;
  final String storagePath;

  const _EvaluationImageCard({required this.title, required this.storagePath});

  Future<void> _showImageDialog(BuildContext context) async {
    if (storagePath.isEmpty || storagePath == '-') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No image available.')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Container(
            width: 900,
            constraints: const BoxConstraints(maxHeight: 720),
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder<Uint8List?>(
                    future: FirebaseStorage.instance
                        .ref(storagePath)
                        .getData(5 * 1024 * 1024),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Failed to load image: ${snapshot.error}',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }

                      final imageBytes = snapshot.data;

                      if (imageBytes == null) {
                        return const Center(
                          child: Text(
                            'Image data is empty.',
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }

                      return InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Center(
                          child: Image.memory(imageBytes, fit: BoxFit.contain),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  storagePath,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showImageDialog(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.mainBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primaryPurple.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.image_outlined,
              color: AppColors.primaryPurple,
              size: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    storagePath.isEmpty || storagePath == '-'
                        ? 'No image available'
                        : 'Click to preview image',
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.open_in_full,
              color: AppColors.secondaryText,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceSummaryTableCard extends StatelessWidget {
  final String title;
  final String metricsPath;

  const _PerformanceSummaryTableCard({
    required this.title,
    required this.metricsPath,
  });

  Future<Map<String, dynamic>> _loadMetricsJson() async {
    final Uint8List? bytes = await FirebaseStorage.instance
        .ref(metricsPath)
        .getData(2 * 1024 * 1024);

    if (bytes == null) {
      throw Exception('Metrics file is empty.');
    }

    final String jsonString = utf8.decode(bytes);
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  String _formatMetric(dynamic value) {
    if (value == null) return '-';
    if (value is num) return value.toStringAsFixed(4);
    return value.toString();
  }

  String _formatSupport(dynamic value) {
    if (value == null) return '-';
    if (value is num) return value.toInt().toString();
    return value.toString();
  }

  Future<void> _showMetricsDialog(BuildContext context) async {
    if (metricsPath.isEmpty || metricsPath == '-') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No metrics file available.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Container(
            width: 900,
            constraints: const BoxConstraints(maxHeight: 720),
            padding: const EdgeInsets.all(18),
            child: FutureBuilder<Map<String, dynamic>>(
              future: _loadMetricsJson(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Text(
                    'Failed to load metrics: ${snapshot.error}',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  );
                }

                final metrics = snapshot.data!;
                final report =
                    metrics['classificationReport'] as Map<String, dynamic>?;

                if (report == null) {
                  return const Text(
                    'classificationReport not found in metrics.json.',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  );
                }

                final classes = ['Safe', 'Suspicious', 'Phishing', 'Malware'];

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Overall Accuracy: ${_formatMetric(metrics['accuracy'])}',
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Macro F1: ${_formatMetric(metrics['macroF1'])}',
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
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
                          DataColumn(label: Text('Class')),
                          DataColumn(label: Text('Precision')),
                          DataColumn(label: Text('Recall')),
                          DataColumn(label: Text('F1-score')),
                          DataColumn(label: Text('Support')),
                        ],
                        rows: classes.map((className) {
                          final classMetrics =
                              report[className] as Map<String, dynamic>? ?? {};

                          return DataRow(
                            cells: [
                              DataCell(Text(className)),
                              DataCell(
                                Text(_formatMetric(classMetrics['precision'])),
                              ),
                              DataCell(
                                Text(_formatMetric(classMetrics['recall'])),
                              ),
                              DataCell(
                                Text(_formatMetric(classMetrics['f1-score'])),
                              ),
                              DataCell(
                                Text(_formatSupport(classMetrics['support'])),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      metricsPath,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showMetricsDialog(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.mainBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primaryPurple.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.table_chart_outlined,
              color: AppColors.primaryPurple,
              size: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    metricsPath.isEmpty || metricsPath == '-'
                        ? 'No metrics file available'
                        : 'Click to view performance table',
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.open_in_full,
              color: AppColors.secondaryText,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryPurple.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryPurple, size: 22),
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
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 20,
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontWeight: FontWeight.w700,
                fontSize: 13,
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
    return const Divider(height: 1, thickness: 1, color: Colors.white10);
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
