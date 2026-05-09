import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import 'scan_result_details_screen.dart';
import '../threat_engine/scan_settings.dart';
import '../threat_engine/layer5_facade/threat_engine.dart';
import 'result_screen.dart';

class ViewHistoryScreen extends StatefulWidget {
  const ViewHistoryScreen({super.key});

  @override
  State<ViewHistoryScreen> createState() => _ViewHistoryScreenState();
}

class _ViewHistoryScreenState extends State<ViewHistoryScreen> {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isRescanning = false;

  final List<String> _filters = ['All', 'Safe', 'Suspicious', 'Malicious'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getStatusFromRiskScore(double riskScore) {
    if (riskScore >= 76) return 'Malicious';
    if (riskScore >= 51) return 'Suspicious';
    if (riskScore >= 26) return 'Low Risk';
    return 'Safe';
  }

  bool _matchesFilter(String filter, double riskScore) {
    if (filter == 'All') return true;
    final status = _getStatusFromRiskScore(riskScore);
    return status == filter;
  }

  String _formatDateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dt.year, dt.month, dt.day);
    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Map<String, List<QueryDocumentSnapshot>> _groupByDate(List<QueryDocumentSnapshot> docs) {
    final Map<String, List<QueryDocumentSnapshot>> grouped = {};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final Timestamp? ts = data['scannedAt'] as Timestamp?;
      final label = ts != null ? _formatDateLabel(ts.toDate()) : 'Unknown';
      grouped.putIfAbsent(label, () => []).add(doc);
    }
    return grouped;
  }

  ScanResult _convertToScanResult(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final Timestamp? scannedAt = data['scannedAt'] as Timestamp?;
    final scanDate = scannedAt != null
        ? '${_formatDateLabel(scannedAt.toDate())} at ${_formatTime(scannedAt.toDate())}'
        : 'Unknown date';

    double _getDouble(String snakeKey, String camelKey) {
      final value = data[snakeKey] ?? data[camelKey];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    final Map<String, dynamic> scanMap = {
      'url': data['url'] ?? '',
      'scan_date': scanDate,
      'threat_type': data['threat_type'] ?? data['threatType'] ?? 'unknown',
      'risk_score': _getDouble('risk_score', 'riskScore'),
      'explanation': data['explanation'] ?? '',
      'detected_threats': (data['detected_threats'] ?? data['detectedThreats'] as List?)?.cast<String>() ?? [],
      'ml_confidence': data['ml_confidence'] ?? data['mlConfidence'] ?? 'low',
      'ml_score': _getDouble('ml_score', 'mlScore'),
      'ai_score': _getDouble('ai_score', 'aiScore'),
      'behavior_score': _getDouble('behavior_score', 'behaviorScore'),
      'external_score': _getDouble('external_score', 'externalScore'),
      'external_sources': (data['external_sources'] ?? data['externalSources'] as List?)?.cast<String>() ?? [],
      'actions': (data['actions'] ?? data['recommendedActions'] as List?)?.cast<String>() ?? [],
      'safety_tips': (data['safety_tips'] ?? data['safetyTips'] as List?)?.cast<String>() ?? [],
    };
    return ScanResult.fromJson(scanMap);
  }

  Future<void> _deleteScan(DocumentSnapshot doc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await doc.reference.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan deleted'), backgroundColor: AppColors.safe),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: AppColors.highRisk),
        );
      }
    }
  }

  Future<ScanSettings> _loadUserSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return ScanSettings.forBeginner();
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('scan_preferences')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        return ScanSettings(
          phishingSensitivity: data['phishingSensitivity'] ?? true,
          httpSitesWarning: false,
          scriptAnalysis: data['scriptAnalysis'] ?? true,
          adReductionAnalysis: false,
          adDensityLevel: 1,
          autoRecheckScans: false,
          sharingConfiguration: false,
          useExternalApis: data['useExternalApis'] ?? true,
          isPremium: data['isPremium'] ?? true,
          userLevel: data['userLevel'] ?? 'beginner',
          enableMachineLearning: true,
          useEnsemble: data['useEnsemble'] ?? true,
          useLogisticRegression: data['useLogisticRegression'] ?? true,
          useDecisionTree: data['useDecisionTree'] ?? true,
          useXGBoost: data['useXGBoost'] ?? true,
          useLightGBM: data['useLightGBM'] ?? true,
          deepScan: data['deepScan'] ?? true,
          adFilter: false,
        );
      }
    } catch (_) {}
    return ScanSettings.forBeginner();
  }

  Future<void> _rescanUrl(String url, DocumentReference docRef) async {
    setState(() => _isRescanning = true);
    try {
      final settings = await _loadUserSettings();
      final engine = await ThreatEngine.getInstance();
      final result = await engine.analyze(url, settings: settings);
      final scanResult = result['scan_result'] as Map<String, dynamic>;

      final double riskScore =
          double.tryParse(scanResult['risk_score']?.toString() ?? '0') ?? 0.0;
      final String verdict = _getStatusFromRiskScore(riskScore);

      await docRef.update({
        'riskScore': riskScore,
        'risk_score': riskScore,
        'verdict': verdict,
        'threat_type': scanResult['threat_type'] ?? 'unknown',
        'explanation': scanResult['explanation'] ?? '',
        'detected_threats': scanResult['detected_threats'] ?? [],
        'ml_confidence': scanResult['ml_confidence'] ?? 'low',
        'ml_score': scanResult['ml_score'] ?? 0,
        'ai_score': scanResult['ai_score'] ?? 0,
        'behavior_score': scanResult['behavior_score'] ?? 0,
        'external_score': scanResult['external_score'] ?? 0,
        'external_sources': scanResult['external_sources'] ?? [],
        'actions': scanResult['actions'] ?? [],
        'safety_tips': scanResult['safety_tips'] ?? [],
        'scannedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen.fromEngineResult(
            engineResult: scanResult,
            settings: settings,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rescan failed: $e'), backgroundColor: AppColors.highRisk),
        );
      }
    } finally {
      if (mounted) setState(() => _isRescanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmall = screenWidth < 360;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'View History',
          style: TextStyle(
            color: AppColors.primaryText,
            fontSize: isSmall ? 20 : 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: user == null
          ? const Center(
              child: Text(
                'Please sign in to view scan history.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 14),
              ),
            )
          : _isRescanning
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Search by URL...',
                          hintStyle: const TextStyle(color: AppColors.disabledText, fontSize: 13),
                          filled: true,
                          fillColor: AppColors.cardBackground,
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.secondaryText, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, color: AppColors.secondaryText, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        style: const TextStyle(color: AppColors.primaryText),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _filters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final filter = _filters[index];
                          final isSelected = _selectedFilter == filter;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedFilter = filter),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primaryPurple : AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: isSelected ? AppColors.primaryPurple : AppColors.divider, width: 1),
                              ),
                              child: Text(
                                filter,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.secondaryText,
                                  fontSize: 12.5,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('scans')
                            .orderBy('scannedAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple));
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return _buildEmptyState('No scans yet.\nStart scanning a link!');
                          }

                          final filteredDocs = snapshot.data!.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final url = (data['url'] ?? '').toString().toLowerCase();
                            final riskScore = (data['riskScore'] as num?)?.toDouble() ?? 0.0;
                            return _matchesFilter(_selectedFilter, riskScore) &&
                                (_searchQuery.isEmpty || url.contains(_searchQuery));
                          }).toList();

                          if (filteredDocs.isEmpty) {
                            return _buildEmptyState(
                              _searchQuery.isEmpty ? 'No results for this filter.' : 'No results for "$_searchQuery"',
                            );
                          }

                          final grouped = _groupByDate(filteredDocs);
                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                            itemCount: grouped.length,
                            itemBuilder: (context, groupIndex) {
                              final dateLabel = grouped.keys.elementAt(groupIndex);
                              final docsInGroup = grouped[dateLabel]!;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16, bottom: 10),
                                    child: Row(
                                      children: [
                                        Text(
                                          dateLabel,
                                          style: const TextStyle(
                                            color: AppColors.secondaryText,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryPurple.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '${docsInGroup.length}',
                                            style: const TextStyle(color: AppColors.primaryPurple, fontSize: 11, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...docsInGroup.map((doc) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    final url = data['url']?.toString() ?? 'No URL found';
                                    final double riskScore = (data['riskScore'] as num?)?.toDouble() ?? 0.0;
                                    final status = _getStatusFromRiskScore(riskScore);
                                    final Timestamp? ts = data['scannedAt'] as Timestamp?;
                                    final String timeStr = ts != null ? _formatTime(ts.toDate()) : '';
                                    return _ScanHistoryCard(
                                      url: url,
                                      status: status,
                                      riskScore: riskScore,
                                      time: timeStr,
                                      onTap: () {
                                        final scanResult = _convertToScanResult(doc);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ScanResultDetailsScreen(
                                              scanResult: scanResult,
                                              onDelete: () => _deleteScan(doc),
                                              onRescan: () => _rescanUrl(url, doc.reference),
                                            ),
                                          ),
                                        );
                                      },
                                      onDelete: () => _deleteScan(doc),
                                      onRescan: () => _rescanUrl(url, doc.reference),
                                    );
                                  }).toList(),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: AppColors.disabledText.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.secondaryText, fontSize: 14)),
        ],
      ),
    );
  }
}

// Individual scan card with popup menu
class _ScanHistoryCard extends StatelessWidget {
  final String url;
  final String status;
  final double riskScore;
  final String time;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRescan;

  const _ScanHistoryCard({
    required this.url,
    required this.status,
    required this.riskScore,
    required this.time,
    required this.onTap,
    required this.onDelete,
    required this.onRescan,
  });

  Color get _statusColor {
    switch (status) {
      case 'Safe': return AppColors.safe;
      case 'Suspicious': return AppColors.mediumRisk;
      case 'Low Risk': return AppColors.mediumRisk;
      case 'Malicious': return AppColors.highRisk;
      default: return AppColors.primaryPurple;
    }
  }

  IconData get _statusIcon {
    switch (status) {
      case 'Safe': return Icons.check_circle_rounded;
      case 'Suspicious': case 'Low Risk': return Icons.warning_amber_rounded;
      case 'Malicious': return Icons.cancel_rounded;
      default: return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: _statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(_statusIcon, color: _statusColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(url, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.primaryText, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(time, style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _statusColor.withOpacity(0.5)),
                  ),
                  child: Text(status, style: TextStyle(color: _statusColor, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✅ FIXED: use floor() to match the gauge's truncation
                    Text('Risk: ${riskScore.floor()}%', style: TextStyle(color: _statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: _statusColor, size: 18),
                      onSelected: (value) {
                        if (value == 'rescan') {
                          onRescan();
                        } else if (value == 'delete') {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: AppColors.cardBackground,
                              title: const Text('Delete Scan', style: TextStyle(color: AppColors.primaryText)),
                              content: const Text('Are you sure you want to delete this scan?', style: TextStyle(color: AppColors.secondaryText)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText))),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    onDelete();
                                  },
                                  child: const Text('Delete', style: TextStyle(color: AppColors.highRisk)),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'rescan', child: Row(children: [Icon(Icons.refresh, size: 18), SizedBox(width: 8), Text('Rescan URL')])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: AppColors.highRisk), SizedBox(width: 8), Text('Delete from History', style: TextStyle(color: AppColors.highRisk))])),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}