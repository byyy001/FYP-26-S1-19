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
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                ),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search field
                    TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.trim().toLowerCase();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search scans...',
                        hintStyle: const TextStyle(
                          color: AppColors.disabledText,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: AppColors.cardBackground,
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.secondaryText,
                          size: 20,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.primaryPurple.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                      ),
                      style: const TextStyle(
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Filter chips
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: _filters.map((filter) {
                        return FilterChip(
                          label: Text(filter),
                          selected: _selectedFilter == filter,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedFilter = filter;
                              });
                            }
                          },
                          backgroundColor: AppColors.mainBackground,
                          selectedColor: AppColors.primaryPurple.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: _selectedFilter == filter
                                ? AppColors.primaryPurple
                                : AppColors.secondaryText,
                            fontWeight: _selectedFilter == filter
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                            side: BorderSide(
                              color: _selectedFilter == filter
                                  ? AppColors.primaryPurple
                                  : AppColors.divider,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // History list
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('scans')
                          .orderBy('scannedAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primaryPurple,
                              ),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return _buildEmptyState('No scans found yet.');
                        }

                        final allDocs = snapshot.data!.docs;

                        final filteredDocs = allDocs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;

                          final url = (data['url'] ?? '')
                              .toString()
                              .toLowerCase();

                          final normalizedStatus = _normalizeStatus(
                            (data['verdict'] ?? data['result'] ?? 'safe')
                                .toString(),
                          );

                          final matchesFilter = _selectedFilter == 'All'
                              ? true
                              : normalizedStatus == _selectedFilter;

                          final matchesSearch = _searchQuery.isEmpty
                              ? true
                              : url.contains(_searchQuery);

                          return matchesFilter && matchesSearch;
                        }).toList();

                        if (filteredDocs.isEmpty) {
                          return _buildEmptyState('No matching scans found.');
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredDocs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final doc = filteredDocs[index];
                            final data = doc.data() as Map<String, dynamic>;

                            final String url =
                                data['url']?.toString() ?? 'No URL found';

                            final String status = _normalizeStatus(
                              (data['verdict'] ?? data['result'] ?? 'safe')
                                  .toString(),
                            );

                            final Timestamp? scannedAt =
                                data['scannedAt'] as Timestamp?;

                            final String scannedTime = scannedAt != null
                                ? _formatDate(scannedAt.toDate())
                                : 'Recently';

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.divider.withOpacity(0.3),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    url,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.primaryText,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          scannedTime,
                                          style: const TextStyle(
                                            color: AppColors.secondaryText,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      _HistoryStatusBadge(status: status),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history_toggle_off,
            color: AppColors.secondaryText,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryStatusBadge extends StatelessWidget {
  final String status;

  const _HistoryStatusBadge({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor = Colors.white;

    switch (status) {
      case 'Safe':
        bgColor = AppColors.safe;
        break;
      case 'Suspicious':
        bgColor = AppColors.mediumRisk;
        textColor = Colors.white;
        break;
      case 'Malicious':
        bgColor = AppColors.highRisk;
        break;
      default:
        bgColor = AppColors.primaryPurple;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}