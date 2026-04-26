import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';

class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'Report History',
          style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w600),
        ),
      ),
      body: user == null
          ? const Center(
              child: Text(
                'Please sign in to view your reports.',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            )
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search by URL...',
                      hintStyle: const TextStyle(color: AppColors.disabledText),
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      prefixIcon: const Icon(Icons.search, color: AppColors.secondaryText),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, color: AppColors.secondaryText),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    style: const TextStyle(color: AppColors.primaryText),
                  ),
                ),
                // Status filter chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pending', 'pending'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Reviewed', 'reviewed'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Resolved', 'resolved'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Report list
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('false_reports')
                        .where('userId', isEqualTo: user.uid)
                        .orderBy('submittedAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState();
                      }

                      var reports = snapshot.data!.docs;
                      if (_searchQuery.isNotEmpty) {
                        reports = reports.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final url = (data['url'] ?? '').toString().toLowerCase();
                          return url.contains(_searchQuery);
                        }).toList();
                      }
                      if (_statusFilter != 'all') {
                        reports = reports.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final status = data['status']?.toString().toLowerCase() ?? 'pending';
                          return status == _statusFilter;
                        }).toList();
                      }

                      if (reports.isEmpty) {
                        return _buildEmptyState(message: 'No reports match your filters.');
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        itemCount: reports.length,
                        itemBuilder: (context, index) {
                          final doc = reports[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final url = data['url'] ?? '';
                          final status = data['status'] ?? 'pending';
                          final reason = data['reason'] ?? '';
                          final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
                          final verdict = (data['scanResult'] as Map?)?['verdict'] ?? 'Unknown';

                          String statusText = status.toString().toUpperCase();
                          Color statusColor;
                          switch (status.toString().toLowerCase()) {
                            case 'pending':
                              statusColor = Colors.orange;
                              break;
                            case 'reviewed':
                              statusColor = Colors.blue;
                              break;
                            case 'resolved':
                              statusColor = AppColors.safe;
                              break;
                            default:
                              statusColor = AppColors.secondaryText;
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: AppColors.cardBackground,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          url,
                                          style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: statusColor.withOpacity(0.5)),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Verdict: $verdict',
                                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                                  ),
                                  if (reason.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Reason: $reason',
                                      style: const TextStyle(color: AppColors.secondaryText, fontSize: 12, fontStyle: FontStyle.italic),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    'Submitted: ${submittedAt != null ? _formatDate(submittedAt) : 'Unknown'}',
                                    style: const TextStyle(color: AppColors.disabledText, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _statusFilter = value;
        });
      },
      backgroundColor: AppColors.cardBackground,
      selectedColor: AppColors.primaryPurple.withOpacity(0.2),
      checkmarkColor: AppColors.primaryPurple,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primaryPurple : AppColors.secondaryText,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildEmptyState({String message = 'No reports submitted yet.'}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.report_off_outlined, size: 64, color: AppColors.disabledText),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: AppColors.secondaryText),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}