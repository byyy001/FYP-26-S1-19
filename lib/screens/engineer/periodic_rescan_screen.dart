import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../threat_engine/layer5_facade/threat_engine.dart';
import '../../threat_engine/scan_settings.dart';

class PeriodicRescanScreen extends StatefulWidget {
  const PeriodicRescanScreen({super.key});

  @override
  State<PeriodicRescanScreen> createState() => _PeriodicRescanScreenState();
}

class _PeriodicRescanScreenState extends State<PeriodicRescanScreen> {
  late Future<List<Map<String, dynamic>>> _safeScansFuture;

  // Engine state
  late ThreatEngine _engine;
  bool _engineReady = false;
  String? _engineError;

  // Rescan state
  bool _isRescanning = false;
  int _rescanProgress = 0;
  int _rescanTotal = 0;
  String _currentUrl = '';
  bool _rescanComplete = false;
  int _rescanChangesCount = 0;

  // In-memory results keyed by document ID — mirrors what is written to Firestore
  final Map<String, Map<String, dynamic>> _rescanResults = {};

  @override
  void initState() {
    super.initState();
    _safeScansFuture = _fetchSafeScans();
    _initEngine();
  }

  Future<void> _initEngine() async {
    try {
      _engine = await ThreatEngine.getInstance();
      if (mounted) setState(() => _engineReady = true);
    } catch (e) {
      if (mounted) setState(() => _engineError = e.toString());
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSafeScans() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('safe_scans')
        .orderBy('scannedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  void _refresh() {
    setState(() {
      _safeScansFuture = _fetchSafeScans();
      _rescanResults.clear();
      _rescanComplete = false;
      _rescanChangesCount = 0;
    });
  }

  Future<void> _runRescan(List<Map<String, dynamic>> scans) async {
    if (!_engineReady || _isRescanning) return;

    setState(() {
      _isRescanning = true;
      _rescanProgress = 0;
      _rescanTotal = scans.length;
      _currentUrl = '';
      _rescanComplete = false;
      _rescanChangesCount = 0;
    });

    int changesFound = 0;

    for (final scan in scans) {
      final url = scan['url']?.toString() ?? '';
      final docId = scan['id']?.toString() ?? '';
      if (url.isEmpty || docId.isEmpty) {
        if (mounted) setState(() => _rescanProgress++);
        continue;
      }

      if (mounted) setState(() => _currentUrl = url);

      try {
        final result = await _engine.analyze(url, settings: ScanSettings.defaultSettings());
        final scanResult = result['scan_result'] as Map<String, dynamic>;
        final riskScore = double.tryParse(scanResult['risk_score']?.toString() ?? '0') ?? 0.0;
        final verdict = riskScore >= 76
            ? 'Malicious'
            : (riskScore >= 51 ? 'Suspicious' : (riskScore >= 26 ? 'Low Risk' : 'Safe'));

        if (verdict.toLowerCase() != 'safe') changesFound++;

        // Write result to Firestore immediately so progress is never lost
        await FirebaseFirestore.instance.collection('safe_scans').doc(docId).update({
          'rescanned': true,
          'rescannedVerdict': verdict,
          'rescannedRiskScore': riskScore,
          'rescannedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          setState(() {
            _rescanResults[docId] = {
              'rescanned': true,
              'rescannedVerdict': verdict,
              'rescannedRiskScore': riskScore,
              'rescannedAt': DateTime.now(),
            };
            _rescanProgress++;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _rescanResults[docId] = {'rescanned': true, 'rescannedVerdict': 'Error', 'rescannedAt': DateTime.now()};
            _rescanProgress++;
          });
        }
      }
    }

    if (mounted) {
      setState(() {
        _isRescanning = false;
        _currentUrl = '';
        _rescanComplete = true;
        _rescanChangesCount = changesFound;
      });
    }
  }

  String _formatTimestamp(dynamic ts) {
    if (ts is Timestamp) return DateFormat('MMM d yyyy, hh:mm a').format(ts.toDate());
    if (ts is DateTime) return DateFormat('MMM d yyyy, hh:mm a').format(ts);
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1380),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _safeScansFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppColors.primaryPurple),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading data: ${snapshot.error}',
                    style: const TextStyle(color: AppColors.highRisk),
                  ),
                );
              }

              final scans = snapshot.data ?? [];

              // Merge in-memory rescan results so the table reflects live progress
              final mergedScans = scans.map((scan) {
                final inMemory = _rescanResults[scan['id']];
                if (inMemory != null) return {...scan, ...inMemory};
                return scan;
              }).toList();

              final totalCount = mergedScans.length;
              final rescannedCount = mergedScans.where((s) => s['rescanned'] == true).length;
              final changedCount = mergedScans.where((s) {
                final rv = s['rescannedVerdict']?.toString().toLowerCase();
                return rv != null && rv != 'safe' && rv != 'error';
              }).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEngineStatus(),
                  const SizedBox(height: 16),
                  if (_rescanComplete) ...[
                    _buildCompletionBanner(),
                    const SizedBox(height: 16),
                  ],
                  _buildSummaryRow(totalCount, rescannedCount, changedCount),
                  const SizedBox(height: 20),
                  _buildTableCard(mergedScans, scans),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEngineStatus() {
    if (_engineError != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.highRisk.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.highRisk.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.highRisk, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Threat engine failed to load: $_engineError',
                style: const TextStyle(color: AppColors.highRisk, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _initEngine,
              child: const Text('Retry', style: TextStyle(color: AppColors.highRisk)),
            ),
          ],
        ),
      );
    }

    if (!_engineReady) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryPurple.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.primaryPurple)),
            ),
            SizedBox(width: 12),
            Text('Loading threat engine...', style: TextStyle(color: AppColors.secondaryText, fontSize: 13)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.safe.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.safe.withValues(alpha: 0.35)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: AppColors.safe, size: 18),
          SizedBox(width: 10),
          Text('Threat engine ready', style: TextStyle(color: AppColors.safe, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildCompletionBanner() {
    final hasChanges = _rescanChangesCount > 0;
    final color = hasChanges ? AppColors.highRisk : AppColors.safe;
    final icon = hasChanges ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded;
    final message = hasChanges
        ? '$_rescanChangesCount URL${_rescanChangesCount == 1 ? '' : 's'} changed verdict — review highlighted rows below'
        : 'All $_rescanTotal URLs are still safe — no action needed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rescan complete — $_rescanTotal URL${_rescanTotal == 1 ? '' : 's'} processed',
                  style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(message, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: _refresh,
            style: TextButton.styleFrom(foregroundColor: color),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(int total, int rescanned, int changed) {
    return Row(
      children: [
        _buildStatCard(icon: Icons.shield_outlined, label: 'Total Safe Scans', value: '$total', color: AppColors.primaryPurple),
        const SizedBox(width: 14),
        _buildStatCard(icon: Icons.refresh_rounded, label: 'Rescanned', value: '$rescanned', color: AppColors.safe),
        const SizedBox(width: 14),
        _buildStatCard(
          icon: Icons.warning_amber_rounded,
          label: 'Verdict Changed',
          value: '$changed',
          color: changed > 0 ? AppColors.highRisk : AppColors.secondaryText,
        ),
      ],
    );
  }

  Widget _buildStatCard({required IconData icon, required String label, required String value, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.14), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: AppColors.primaryText, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCard(List<Map<String, dynamic>> mergedScans, List<Map<String, dynamic>> rawScans) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryPurple.withValues(alpha: 0.35)),
        boxShadow: [BoxShadow(color: AppColors.primaryPurple.withValues(alpha: 0.14), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Safe Scan Records', style: TextStyle(color: AppColors.primaryText, fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: (_engineReady && !_isRescanning && mergedScans.isNotEmpty) ? () => _runRescan(rawScans) : null,
                icon: _isRescanning
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(_isRescanning ? 'Rescanning...' : 'Run Rescan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  disabledBackgroundColor: AppColors.primaryPurple.withValues(alpha: 0.3),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white54,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _isRescanning ? null : _refresh,
                icon: const Icon(Icons.sync_rounded, color: AppColors.secondaryText),
                tooltip: 'Refresh',
              ),
            ],
          ),
          if (_isRescanning) ...[
            const SizedBox(height: 14),
            _buildProgressBar(),
          ],
          const SizedBox(height: 16),
          if (mergedScans.isEmpty) _buildEmptyState() else _buildTable(mergedScans),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _rescanTotal > 0 ? _rescanProgress / _rescanTotal : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Scanning $_rescanProgress of $_rescanTotal',
              style: const TextStyle(color: AppColors.secondaryText, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: AppColors.primaryPurple, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.mainBackground,
            valueColor: const AlwaysStoppedAnimation(AppColors.primaryPurple),
          ),
        ),
        if (_currentUrl.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _currentUrl,
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: const Column(
        children: [
          Icon(Icons.shield_outlined, color: AppColors.secondaryText, size: 48),
          SizedBox(height: 12),
          Text('No safe scans yet', style: TextStyle(color: AppColors.secondaryText, fontSize: 15, fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('Safe scan records will appear here once users scan URLs', style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> scans) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: AppColors.mainBackground, borderRadius: BorderRadius.circular(10)),
          child: const Row(
            children: [
              Expanded(flex: 4, child: _HeaderCell('URL')),
              Expanded(flex: 3, child: _HeaderCell('User UID')),
              Expanded(flex: 2, child: _HeaderCell('Scanned At')),
              Expanded(flex: 2, child: _HeaderCell('Risk Score')),
              Expanded(flex: 2, child: _HeaderCell('Rescan Status')),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: scans.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) => _buildRow(scans[index]),
        ),
      ],
    );
  }

  Widget _buildRow(Map<String, dynamic> scan) {
    final isBeingScanned = _isRescanning && scan['url']?.toString() == _currentUrl;
    final rescanned = scan['rescanned'] == true;
    final rescannedVerdict = scan['rescannedVerdict']?.toString();
    final verdictChanged = rescanned && rescannedVerdict != null && rescannedVerdict.toLowerCase() != 'safe';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (isBeingScanned) {
      statusColor = AppColors.primaryPurple;
      statusLabel = 'Scanning...';
      statusIcon = Icons.radar_outlined;
    } else if (!rescanned) {
      statusColor = AppColors.secondaryText;
      statusLabel = 'Pending';
      statusIcon = Icons.schedule_rounded;
    } else if (verdictChanged) {
      statusColor = AppColors.highRisk;
      statusLabel = rescannedVerdict;
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusColor = AppColors.safe;
      statusLabel = 'Still Safe';
      statusIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isBeingScanned ? AppColors.primaryPurple.withValues(alpha: 0.05) : AppColors.mainBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: verdictChanged
              ? AppColors.highRisk.withValues(alpha: 0.3)
              : isBeingScanned
                  ? AppColors.primaryPurple.withValues(alpha: 0.3)
                  : AppColors.divider.withValues(alpha: 0.15),
          width: (verdictChanged || isBeingScanned) ? 1.2 : 0.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(scan['url']?.toString() ?? '—', style: const TextStyle(color: AppColors.primaryText, fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 3,
            child: Text(scan['uid']?.toString() ?? '—', style: const TextStyle(color: AppColors.secondaryText, fontSize: 12, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 2,
            child: Text(_formatTimestamp(scan['scannedAt']), style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              (scan['riskScore'] as num?)?.toStringAsFixed(1) ?? '—',
              style: const TextStyle(color: AppColors.primaryText, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                isBeingScanned
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.primaryPurple)))
                    : Icon(statusIcon, size: 15, color: statusColor),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: AppColors.secondaryText, fontSize: 12, fontWeight: FontWeight.w600));
  }
}
