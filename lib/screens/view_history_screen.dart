import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';

class ViewHistoryScreen extends StatefulWidget {
  const ViewHistoryScreen({super.key});

  @override
  State<ViewHistoryScreen> createState() => _ViewHistoryScreenState();
}

class _ViewHistoryScreenState extends State<ViewHistoryScreen> {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _filters = ['All', 'Safe', 'Suspicious', 'Malicious'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalizeStatus(String value) {
    final status = value.toLowerCase().trim();
    if (status == 'unsafe' || status == 'malicious') return 'Malicious';
    if (status == 'suspicious' || status == 'warning') return 'Suspicious';
    if (status == 'safe') return 'Safe';
    return 'Safe';
  }

  String _formatDateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Map<String, List<QueryDocumentSnapshot>> _groupByDate(
      List<QueryDocumentSnapshot> docs) {
    final Map<String, List<QueryDocumentSnapshot>> grouped = {};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final Timestamp? ts = data['scannedAt'] as Timestamp?;
      final label = ts != null ? _formatDateLabel(ts.toDate()) : 'Unknown';
      grouped.putIfAbsent(label, () => []).add(doc);
    }
    return grouped;
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
          : Column(
              children: [
                // Search field
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _searchQuery = value.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search by URL...',
                      hintStyle: const TextStyle(
                        color: AppColors.disabledText,
                        fontSize: 13,
                      ),


                      filled: true,
                      fillColor: AppColors.cardBackground,
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.secondaryText, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: AppColors.secondaryText, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: AppColors.primaryText),
                  ),
                ),
                // Filter chips
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
                            color: isSelected
                                ? AppColors.primaryPurple
                                : AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryPurple
                                  : AppColors.divider,
                              width: 1,
                            ),
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
                // History list
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
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryPurple,
                          ),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState('No scans yet.\nStart scanning a link!');
                      }

                      // Apply search + filter
                      final filteredDocs = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final url = (data['url'] ?? '').toString().toLowerCase();
                        final status = _normalizeStatus(
                          (data['verdict'] ?? data['result'] ?? 'safe')
                              .toString(),
                        );
                        final matchesFilter = _selectedFilter == 'All' ||
                            status == _selectedFilter;
                        final matchesSearch = _searchQuery.isEmpty ||
                            url.contains(_searchQuery);
                        return matchesFilter && matchesSearch;
                      }).toList();

                      if (filteredDocs.isEmpty) {
                        return _buildEmptyState(
                          _searchQuery.isEmpty
                              ? 'No results for this filter.'
                              : 'No results for "$_searchQuery"',
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
                              // Date header with count badge
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color:
                                            AppColors.primaryPurple.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${docsInGroup.length}',
                                        style: const TextStyle(
                                          color: AppColors.primaryPurple,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Cards for this date
                              ...docsInGroup.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final url = data['url']?.toString() ?? 'No URL found';
                                final status = _normalizeStatus(
                                  (data['verdict'] ?? data['result'] ?? 'safe')
                                      .toString(),
                                );
                                final double riskScore =
                                    (data['riskScore'] as num?)?.toDouble() ?? 0.0;
                                final Timestamp? ts = data['scannedAt'] as Timestamp?;
                                final String timeStr =
                                    ts != null ? _formatTime(ts.toDate()) : '';
                                return _ScanHistoryCard(
                                  url: url,
                                  status: status,
                                  riskScore: riskScore,
                                  time: timeStr,
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
          Icon(
            Icons.history_rounded,
            size: 64,
            color: AppColors.disabledText.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// Individual scan card
class _ScanHistoryCard extends StatelessWidget {
  final String url;
  final String status;
  final double riskScore;
  final String time;

  const _ScanHistoryCard({
    required this.url,
    required this.status,
    required this.riskScore,
    required this.time,
  });

  Color get _statusColor {
    switch (status) {
      case 'Safe':
        return AppColors.safe;
      case 'Suspicious':
        return AppColors.mediumRisk;
      case 'Malicious':
        return AppColors.highRisk;
      default:
        return AppColors.primaryPurple;
    }
  }

  IconData get _statusIcon {
    switch (status) {
      case 'Safe':
        return Icons.check_circle_rounded;
      case 'Suspicious':
        return Icons.warning_amber_rounded;
      case 'Malicious':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_statusIcon, color: _statusColor, size: 24),
          ),
          const SizedBox(width: 14),
          // URL + time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Risk score + status badge
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
                child: Text(
                  status,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Risk: ${riskScore.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: _statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}