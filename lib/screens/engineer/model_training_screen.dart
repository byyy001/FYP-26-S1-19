import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  String? _uploadedDatasetId;
  String? _uploadedStoragePath;
  String? _selectedExistingDatasetId;
  String _fileFormat = 'CSV';
  String _detectedRows = '-';
  String _detectedColumns = '-';
  String _schemaStatus = 'Not Ready';

  String _selectedModelType = 'logistic_regression';
  String _selectedMergeMode = 'base_plus_uploaded';
  String _lastRun = '-';
  String _latestJobId = '-';
  final String _cloudRunTrainingUrl =
      'https://linksentry-training-backend-1071145926774.asia-southeast1.run.app/start-training';

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

        _uploadedDatasetId = datasetId;
        _uploadedStoragePath = storagePath;
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

  Future<void> _selectExistingDataset(
    String datasetId,
    Map<String, dynamic> data,
  ) async {
    final String fileName = data['name'] ?? 'Unknown dataset';
    final String storagePath = data['storagePath'] ?? '';

    if (storagePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected dataset has no storage path.')),
      );
      return;
    }

    setState(() {
      _selectedExistingDatasetId = datasetId;
      _uploadedDatasetId = datasetId;
      _uploadedStoragePath = storagePath;
      _uploadedFileName = fileName;

      _fileFormat = 'CSV';
      _detectedRows = 'Existing';
      _detectedColumns = '${data['featureCount'] ?? 59}';
      _schemaStatus = 'Ready';
      _currentStatus = 'Ready';
      _latestLog = 'Existing dataset selected: $fileName';
      _progressValue = 1.0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Selected existing dataset: $fileName')),
    );
  }

  Future<void> _callCloudRunTrainingBackend(String jobId) async {
    if (_cloudRunTrainingUrl.isEmpty) {
      setState(() {
        _latestLog = 'Training job created. Cloud Run URL not connected yet.';
      });
      return;
    }

    final response = await http.post(
      Uri.parse(_cloudRunTrainingUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'jobId': jobId}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Cloud Run error ${response.statusCode}: ${response.body}',
      );
    }
  }

  Future<void> _startTrainingJob() async {
    if (_selectedMergeMode == 'base_plus_uploaded' &&
        (_uploadedFileName == 'No file selected' ||
            _uploadedDatasetId == null ||
            _uploadedStoragePath == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload or select a CSV dataset first.'),
        ),
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
            'modelType': _selectedModelType,
            'mergeMode': _selectedMergeMode,
            'featureSet': 'full_features',
            'exportFormat': 'json_mobile_threat_engine',
            'baseDataset': _baseDatasetName,
            'baseDatasetStoragePath':
                'datasets/base/final_dataset_with_all_features_v3.1.csv',
            'uploadedFileName': _selectedMergeMode == 'base_plus_uploaded'
                ? _uploadedFileName
                : null,
            'uploadedDatasetId': _selectedMergeMode == 'base_plus_uploaded'
                ? _uploadedDatasetId
                : null,
            'uploadedStoragePath': _selectedMergeMode == 'base_plus_uploaded'
                ? _uploadedStoragePath
                : null,
          });
      await _callCloudRunTrainingBackend(jobId);
      setState(() {
        _isStartingTraining = false;
        _currentStatus = 'Completed';
        _latestLog =
            'Training completed. Check Firestore and Storage for results.';
        _progressValue = 1.0;
        _latestJobId = jobId;
        _lastRun = DateTime.now().toString();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Training job completed.')));
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
                            selectedExistingDatasetId:
                                _selectedExistingDatasetId,
                            onChooseFile: _pickAndUploadCsv,
                            onSelectExistingDataset: _selectExistingDataset,
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
                        selectedExistingDatasetId: _selectedExistingDatasetId,
                        onChooseFile: _pickAndUploadCsv,
                        onSelectExistingDataset: _selectExistingDataset,
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
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(flex: 7, child: _DatasetPreviewPanel()),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 5,
                          child: _TrainingConfigPanel(
                            selectedModelType: _selectedModelType,
                            selectedMergeMode: _selectedMergeMode,
                            onModelChanged: (value) {
                              setState(() {
                                _selectedModelType = value;
                              });
                            },
                            onMergeModeChanged: (value) {
                              setState(() {
                                _selectedMergeMode = value;
                              });
                            },
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      const _DatasetPreviewPanel(),
                      const SizedBox(height: 16),
                      _TrainingConfigPanel(
                        selectedModelType: _selectedModelType,
                        selectedMergeMode: _selectedMergeMode,
                        onModelChanged: (value) {
                          setState(() {
                            _selectedModelType = value;
                          });
                        },
                        onMergeModeChanged: (value) {
                          setState(() {
                            _selectedMergeMode = value;
                          });
                        },
                      ),
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
  final String? selectedExistingDatasetId;
  final Future<void> Function() onChooseFile;
  final Future<void> Function(String datasetId, Map<String, dynamic> data)
  onSelectExistingDataset;

  const _DatasetSourcePanel({
    required this.baseDatasetName,
    required this.uploadedFileName,
    required this.fileFormat,
    required this.detectedRows,
    required this.detectedColumns,
    required this.schemaStatus,
    required this.isUploading,
    required this.selectedExistingDatasetId,
    required this.onChooseFile,
    required this.onSelectExistingDataset,
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

          // Select existing uploaded dataset
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('datasets')
                .where('status', isEqualTo: 'uploaded')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.mainBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Loading existing datasets...',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.mainBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'No existing uploaded datasets found.',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                );
              }

              final docs = snapshot.data!.docs;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Existing Dataset',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedExistingDatasetId,
                    dropdownColor: AppColors.cardBackground,
                    style: const TextStyle(color: AppColors.primaryText),
                    decoration: InputDecoration(
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
                        borderSide: const BorderSide(
                          color: AppColors.primaryPurple,
                        ),
                      ),
                    ),
                    hint: const Text(
                      'Choose previously uploaded CSV',
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                    items: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['name'] ?? doc.id;

                      return DropdownMenuItem<String>(
                        value: doc.id,
                        child: Text(name, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (datasetId) {
                      if (datasetId == null) return;

                      final selectedDoc = docs.firstWhere(
                        (doc) => doc.id == datasetId,
                      );

                      final data = selectedDoc.data() as Map<String, dynamic>;

                      onSelectExistingDataset(datasetId, data);
                    },
                  ),
                ],
              );
            },
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
  final String selectedModelType;
  final String selectedMergeMode;
  final ValueChanged<String> onModelChanged;
  final ValueChanged<String> onMergeModeChanged;

  const _TrainingConfigPanel({
    required this.selectedModelType,
    required this.selectedMergeMode,
    required this.onModelChanged,
    required this.onMergeModeChanged,
  });

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
          DropdownButtonFormField<String>(
            value: selectedModelType,
            dropdownColor: AppColors.cardBackground,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
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

            items: const [
              DropdownMenuItem<String>(
                value: 'logistic_regression',
                child: Text('Logistic Regression'),
              ),
              DropdownMenuItem<String>(
                value: 'decision_tree',
                child: Text('Decision Tree'),
              ),

              // Coming soon: backend Python file not added yet
              DropdownMenuItem<String>(
                value: 'xgboost',
                child: Text('XGBoost'),
              ),

              // Coming soon: backend Python file not added yet
              DropdownMenuItem<String>(
                value: 'lightgbm',
                child: Text('LightGBM'),
              ),
            ],

            onChanged: (value) {
              if (value == null) return;
              onModelChanged(value);
            },
          ),
          const SizedBox(height: 14),
          const _FieldLabel('Dataset Merge Mode'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedMergeMode,
            dropdownColor: AppColors.cardBackground,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
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
            items: const [
              DropdownMenuItem<String>(
                value: 'base_only',
                child: Text('Base Dataset Only'),
              ),
              DropdownMenuItem<String>(
                value: 'base_plus_uploaded',
                child: Text('Base Dataset + Uploaded Data'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              onMergeModeChanged(value);
            },
          ),

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
      final DateTime dateTime = value.toDate();
      return dateTime.toString();
    }

    return value.toString();
  }

  Future<void> _deployLatestModel(
    BuildContext context,
    String modelVersionId,
  ) async {
    const String deployUrl =
        'https://linksentry-training-backend-1071145926774.asia-southeast1.run.app/deploy-model';

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deploying latest model...')),
      );

      final response = await http.post(
        Uri.parse(deployUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'modelVersionId': modelVersionId}),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Deploy failed ${response.statusCode}: ${response.body}',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model deployed successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Deploy failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('model_versions')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Panel(
            child: Text(
              'Loading latest model results...',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          );
        }

        if (snapshot.hasError) {
          return _Panel(
            child: Text(
              'Failed to load model results: ${snapshot.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const _Panel(
            child: Text(
              'No trained candidate models found yet.',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          );
        }

        final List<QueryDocumentSnapshot> candidateDocs = snapshot.data!.docs
            .where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['status'] == 'candidate';
            })
            .toList();

        if (candidateDocs.isEmpty) {
          return const _Panel(
            child: Text(
              'No candidate model available yet. Run training first.',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          );
        }

        candidateDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          final DateTime aTime = aData['createdAt'] is Timestamp
              ? (aData['createdAt'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);

          final DateTime bTime = bData['createdAt'] is Timestamp
              ? (bData['createdAt'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);

          return bTime.compareTo(aTime);
        });

        final latestDoc = candidateDocs.first;
        final data = latestDoc.data() as Map<String, dynamic>;

        final String modelVersionId =
            data['modelVersionId']?.toString() ?? latestDoc.id;
        final String modelType = data['modelType']?.toString() ?? '-';
        final String status = data['status']?.toString() ?? '-';
        final String createdAt = _formatTimestamp(data['createdAt']);

        final String confusionMatrixPath =
            data['confusionMatrixPath']?.toString() ?? '';
        final String metricsFilePath =
            data['metricsFilePath']?.toString() ?? '';

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
                'Review the latest trained candidate model before deployment.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
              ),
              const SizedBox(height: 16),

              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth > 900;

                  final cards = [
                    _MetricCard(
                      title: 'Model Version',
                      value: modelVersionId,
                      icon: Icons.memory_outlined,
                    ),
                    _MetricCard(
                      title: 'Accuracy',
                      value: _formatPercent(data['accuracy']),
                      icon: Icons.analytics_outlined,
                    ),
                    _MetricCard(
                      title: 'Macro Precision',
                      value: _formatScore(data['macroPrecision']),
                      icon: Icons.track_changes_outlined,
                    ),
                    _MetricCard(
                      title: 'Macro Recall',
                      value: _formatScore(data['macroRecall']),
                      icon: Icons.show_chart_outlined,
                    ),
                    _MetricCard(
                      title: 'Macro F1',
                      value: _formatScore(data['macroF1']),
                      icon: Icons.score_outlined,
                    ),
                  ];

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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

              const SizedBox(height: 18),

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
                    _InfoRow(label: 'Created At', value: createdAt),
                    const SizedBox(height: 10),
                    _InfoRow(label: 'Model Type', value: modelType),
                    const SizedBox(height: 10),
                    _InfoRow(label: 'Candidate Status', value: status),
                    const SizedBox(height: 10),
                    _InfoRow(
                      label: 'Model File',
                      value: data['modelFilePath']?.toString() ?? '-',
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(
                      label: 'Scaler File',
                      value: data['scalerFilePath']?.toString() ?? '-',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth > 900;

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        onPressed: () async {
                          await _deployLatestModel(context, modelVersionId);
                        },
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
      },
    );
  }
}

class _EvaluationImageCard extends StatelessWidget {
  final String title;
  final String storagePath;

  const _EvaluationImageCard({required this.title, required this.storagePath});

  Future<void> _showImageDialog(BuildContext context) async {
    if (storagePath.isEmpty) {
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
                    storagePath.isEmpty
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
    if (metricsPath.isEmpty) {
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
                    metricsPath.isEmpty
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
