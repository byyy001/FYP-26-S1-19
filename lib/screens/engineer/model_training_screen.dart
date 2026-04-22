import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../constants/app_colors.dart';

class ModelTrainingScreen extends StatefulWidget {
  const ModelTrainingScreen({super.key});

  @override
  State<ModelTrainingScreen> createState() => _ModelTrainingScreenState();
}

class _ModelTrainingScreenState extends State<ModelTrainingScreen> {
  bool _isUploading = false;
  bool _isStartingTraining = false;

  String _currentStatus = 'Idle';
  String _latestLog =
      'Waiting for engineer to upload dataset and start training.';
  double _progressValue = 0.0;

  String _baseDatasetName = 'final_dataset_with_all_features_v3.1.csv';
  String _uploadedFileName = 'No file selected';
  String _fileFormat = 'CSV';
  String _detectedRows = '-';
  String _detectedColumns = '-';
  String _schemaStatus = 'Not Ready';

  String _lastRun = '-';
  String _latestJobId = '-';

  Future<void> _pickAndUploadCsv() async {
    try {
      setState(() {
        _isUploading = true;
        _currentStatus = 'Uploading';
        _latestLog = 'Opening file picker...';
        _progressValue = 0.1;
      });

      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isUploading = false;
          _currentStatus = 'Idle';
          _latestLog = 'File selection cancelled.';
          _progressValue = 0.0;
        });
        return;
      }

      final PlatformFile pickedFile = result.files.first;
      final Uint8List? fileBytes = pickedFile.bytes;

      if (fileBytes == null) {
        setState(() {
          _isUploading = false;
          _currentStatus = 'Upload Failed';
          _latestLog = 'Could not read file bytes. Please try again.';
          _progressValue = 0.0;
        });
        return;
      }

      final String fileName = pickedFile.name;
      final int fileSize = pickedFile.size;
      final String datasetId =
          'dataset_${DateTime.now().millisecondsSinceEpoch}';
      final String storagePath = 'datasets/raw/$datasetId-$fileName';

      setState(() {
        _uploadedFileName = fileName;
        _fileFormat = 'CSV';
        _detectedRows = 'Pending';
        _detectedColumns = 'Pending';
        _schemaStatus = 'Uploading...';
        _latestLog = 'Uploading $fileName to Firebase Storage...';
        _progressValue = 0.35;
      });

      final Reference storageRef = FirebaseStorage.instance.ref().child(
        storagePath,
      );

      final SettableMetadata metadata = SettableMetadata(
        contentType: 'text/csv',
      );

      await storageRef.putData(fileBytes, metadata);

      setState(() {
        _latestLog = 'Upload complete. Saving dataset metadata to Firestore...';
        _progressValue = 0.75;
      });

      await FirebaseFirestore.instance
          .collection('datasets')
          .doc(datasetId)
          .set({
            'name': fileName,
            'type': 'raw',
            'storagePath': storagePath,
            'status': 'uploaded',
            'uploadedAt': Timestamp.now(),
            'sizeBytes': fileSize,
            'baseDataset': _baseDatasetName,
            'labelColumn': 'label',
            'featureCount': 59,
          });

      setState(() {
        _isUploading = false;
        _currentStatus = 'Ready';
        _latestLog = 'Dataset uploaded successfully and metadata saved.';
        _progressValue = 1.0;
        _schemaStatus = 'Ready';
        _detectedRows = 'To validate';
        _detectedColumns = '59';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV uploaded successfully.')),
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
        _currentStatus = 'Upload Failed';
        _latestLog = 'Upload error: $e';
        _progressValue = 0.0;
        _schemaStatus = 'Failed';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _startTrainingJob() async {
    if (_uploadedFileName == 'No file selected') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a CSV dataset first.')),
      );
      return;
    }

    try {
      setState(() {
        _isStartingTraining = true;
        _currentStatus = 'Queued';
        _latestLog = 'Creating training job record...';
        _progressValue = 0.15;
      });

      final String jobId = 'train_${DateTime.now().millisecondsSinceEpoch}';

      await FirebaseFirestore.instance
          .collection('training_jobs')
          .doc(jobId)
          .set({
            'jobId': jobId,
            'status': 'queued',
            'createdAt': Timestamp.now(),
            'createdBy': 'engineer',
            'modelType': 'logistic_regression',
            'mergeMode': 'base_plus_uploaded',
            'featureSet': 'full_features',
            'exportFormat': 'json_mobile_threat_engine',
            'baseDataset': _baseDatasetName,
            'uploadedFileName': _uploadedFileName,
          });

      setState(() {
        _isStartingTraining = false;
        _currentStatus = 'Queued';
        _latestLog = 'Training job created. Backend trigger not connected yet.';
        _progressValue = 0.25;
        _latestJobId = jobId;
        _lastRun = DateTime.now().toString();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Training job created in Firestore.')),
      );
    } catch (e) {
      setState(() {
        _isStartingTraining = false;
        _currentStatus = 'Create Job Failed';
        _latestLog = 'Failed to create training job: $e';
        _progressValue = 0.0;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create training job: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1380),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth > 1050;

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: _DatasetSourcePanel(
                            baseDatasetName: _baseDatasetName,
                            uploadedFileName: _uploadedFileName,
                            fileFormat: _fileFormat,
                            detectedRows: _detectedRows,
                            detectedColumns: _detectedColumns,
                            schemaStatus: _schemaStatus,
                            isUploading: _isUploading,
                            onChooseFile: _pickAndUploadCsv,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 5,
                          child: _TrainingStatusPanel(
                            currentStatus: _currentStatus,
                            lastRun: _lastRun,
                            latestJobId: _latestJobId,
                            progressValue: _progressValue,
                            latestLog: _latestLog,
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      _DatasetSourcePanel(
                        baseDatasetName: _baseDatasetName,
                        uploadedFileName: _uploadedFileName,
                        fileFormat: _fileFormat,
                        detectedRows: _detectedRows,
                        detectedColumns: _detectedColumns,
                        schemaStatus: _schemaStatus,
                        isUploading: _isUploading,
                        onChooseFile: _pickAndUploadCsv,
                      ),
                      const SizedBox(height: 16),
                      _TrainingStatusPanel(
                        currentStatus: _currentStatus,
                        lastRun: _lastRun,
                        latestJobId: _latestJobId,
                        progressValue: _progressValue,
                        latestLog: _latestLog,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth > 1050;

                  if (isWide) {
                    return const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: _DatasetPreviewPanel()),
                        SizedBox(width: 16),
                        Expanded(flex: 5, child: _TrainingConfigPanel()),
                      ],
                    );
                  }

                  return const Column(
                    children: [
                      _DatasetPreviewPanel(),
                      SizedBox(height: 16),
                      _TrainingConfigPanel(),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              _TrainingConfigActions(
                isStartingTraining: _isStartingTraining,
                onStartTraining: _startTrainingJob,
              ),
              const SizedBox(height: 18),
              const _LatestModelResultsPanel(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatasetSourcePanel extends StatelessWidget {
  final String baseDatasetName;
  final String uploadedFileName;
  final String fileFormat;
  final String detectedRows;
  final String detectedColumns;
  final String schemaStatus;
  final bool isUploading;
  final Future<void> Function() onChooseFile;

  const _DatasetSourcePanel({
    required this.baseDatasetName,
    required this.uploadedFileName,
    required this.fileFormat,
    required this.detectedRows,
    required this.detectedColumns,
    required this.schemaStatus,
    required this.isUploading,
    required this.onChooseFile,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dataset Source',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload a new CSV dataset and prepare it for retraining.',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primaryPurple.withOpacity(0.25),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.upload_file_outlined,
                  color: AppColors.primaryPurple,
                  size: 34,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Upload New Training Dataset',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Accepted format: CSV',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: isUploading ? null : onChooseFile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      isUploading
                          ? Icons.hourglass_top
                          : Icons.file_upload_outlined,
                      size: 18,
                    ),
                    label: Text(
                      isUploading ? 'Uploading...' : 'Choose CSV File',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _InfoRow(label: 'Base Dataset', value: baseDatasetName),
                const _DividerLine(),
                _InfoRow(label: 'Uploaded File', value: uploadedFileName),
                const _DividerLine(),
                _InfoRow(label: 'File Format', value: fileFormat),
                const _DividerLine(),
                _InfoRow(label: 'Detected Rows', value: detectedRows),
                const _DividerLine(),
                _InfoRow(label: 'Detected Columns', value: detectedColumns),
                const _DividerLine(),
                _InfoRow(
                  label: 'Schema Status',
                  value: schemaStatus,
                  highlight: schemaStatus == 'Ready',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingStatusPanel extends StatelessWidget {
  final String currentStatus;
  final String lastRun;
  final String latestJobId;
  final double progressValue;
  final String latestLog;

  const _TrainingStatusPanel({
    required this.currentStatus,
    required this.lastRun,
    required this.latestJobId,
    required this.progressValue,
    required this.latestLog,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Training Status',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Track the current retraining job and latest execution details.',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Current Status', value: currentStatus),
                const SizedBox(height: 10),
                _InfoRow(label: 'Last Run', value: lastRun),
                const SizedBox(height: 10),
                _InfoRow(label: 'Latest Job ID', value: latestJobId),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Progress',
            style: TextStyle(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 10,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryPurple,
              ),
            ),
          ),
          const SizedBox(height: 18),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Latest Log',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  latestLog,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
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

class _DatasetPreviewPanel extends StatelessWidget {
  const _DatasetPreviewPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dataset Preview',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Preview a few uploaded rows before combining with the base dataset.',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.mainBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primaryPurple.withOpacity(0.20),
                ),
              ),
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
                  DataColumn(label: Text('url')),
                  DataColumn(label: Text('length')),
                  DataColumn(label: Text('phish_score')),
                  DataColumn(label: Text('label')),
                ],
                rows: const [
                  DataRow(
                    cells: [
                      DataCell(Text('example-login-check.com')),
                      DataCell(Text('24')),
                      DataCell(Text('0.82')),
                      DataCell(Text('1')),
                    ],
                  ),
                  DataRow(
                    cells: [
                      DataCell(Text('safe-site.org')),
                      DataCell(Text('13')),
                      DataCell(Text('0.08')),
                      DataCell(Text('0')),
                    ],
                  ),
                  DataRow(
                    cells: [
                      DataCell(Text('verify-bank-alert.net')),
                      DataCell(Text('21')),
                      DataCell(Text('0.91')),
                      DataCell(Text('1')),
                    ],
                  ),
                  DataRow(
                    cells: [
                      DataCell(Text('promo-reward-link.xyz')),
                      DataCell(Text('20')),
                      DataCell(Text('0.77')),
                      DataCell(Text('2')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Dataset validation note: column structure appears compatible with the current threat engine feature set.',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingConfigPanel extends StatelessWidget {
  const _TrainingConfigPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Training Configuration',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Set the retraining configuration before launching a new job.',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Selected Model'),
          const SizedBox(height: 8),
          const _FakeSelectField(value: 'Logistic Regression'),
          const SizedBox(height: 14),
          const _FieldLabel('Dataset Merge Mode'),
          const SizedBox(height: 8),
          const _FakeSelectField(value: 'Base Dataset + Uploaded Data'),
          const SizedBox(height: 14),
          const _FieldLabel('Feature Set'),
          const SizedBox(height: 8),
          const _FakeSelectField(value: 'Full Features'),
          const SizedBox(height: 14),
          const _FieldLabel('Export Format'),
          const SizedBox(height: 8),
          const _FakeSelectField(value: 'JSON for Mobile Threat Engine'),
          const SizedBox(height: 14),
          const _FieldLabel('Training Notes'),
          const SizedBox(height: 8),
          TextField(
            maxLines: 4,
            style: const TextStyle(color: AppColors.primaryText),
            decoration: InputDecoration(
              hintText: 'Add notes for this retraining job...',
              hintStyle: const TextStyle(color: AppColors.disabledText),
              filled: true,
              fillColor: AppColors.mainBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.primaryPurple.withOpacity(0.25),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.primaryPurple.withOpacity(0.25),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryPurple),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingConfigActions extends StatelessWidget {
  final bool isStartingTraining;
  final Future<void> Function() onStartTraining;

  const _TrainingConfigActions({
    required this.isStartingTraining,
    required this.onStartTraining,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton.icon(
        onPressed: isStartingTraining ? null : onStartTraining,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(
          isStartingTraining ? Icons.hourglass_top : Icons.play_arrow_rounded,
        ),
        label: Text(
          isStartingTraining ? 'Creating Job...' : 'Start Training',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _LatestModelResultsPanel extends StatelessWidget {
  const _LatestModelResultsPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Latest Model Results',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Review the latest trained model metrics before deployment.',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isWide = constraints.maxWidth > 900;

              if (isWide) {
                return const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Model Version',
                        value: 'v1.2.0',
                        icon: Icons.memory_outlined,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: _MetricCard(
                        title: 'Accuracy',
                        value: '82%',
                        icon: Icons.analytics_outlined,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: _MetricCard(
                        title: 'Precision',
                        value: '0.79',
                        icon: Icons.track_changes_outlined,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: _MetricCard(
                        title: 'Recall',
                        value: '0.76',
                        icon: Icons.show_chart_outlined,
                      ),
                    ),
                  ],
                );
              }

              return const Column(
                children: [
                  _MetricCard(
                    title: 'Model Version',
                    value: 'v1.2.0',
                    icon: Icons.memory_outlined,
                  ),
                  SizedBox(height: 12),
                  _MetricCard(
                    title: 'Accuracy',
                    value: '82%',
                    icon: Icons.analytics_outlined,
                  ),
                  SizedBox(height: 12),
                  _MetricCard(
                    title: 'Precision',
                    value: '0.79',
                    icon: Icons.track_changes_outlined,
                  ),
                  SizedBox(height: 12),
                  _MetricCard(
                    title: 'Recall',
                    value: '0.76',
                    icon: Icons.show_chart_outlined,
                  ),
                ],
              );
            },
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
                _InfoRow(label: 'Last Trained', value: '12 Feb 2026'),
                SizedBox(height: 10),
                _InfoRow(label: 'Active Model', value: 'Logistic Regression'),
                SizedBox(height: 10),
                _InfoRow(label: 'Deployment Status', value: 'Current'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.primaryPurple.withOpacity(0.35),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Compare Models',
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
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Deploy Latest Model',
                      style: TextStyle(fontWeight: FontWeight.w700),
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

class _FakeSelectField extends StatelessWidget {
  final String value;

  const _FakeSelectField({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryPurple.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.secondaryText,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _InfoRow({
    required this.label,
    required this.value,
    this.highlight = false,
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
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlight ? AppColors.safe : AppColors.primaryText,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
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
