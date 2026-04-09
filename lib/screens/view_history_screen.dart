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
      body: SafeArea(
        child: user == null
            ? const Center(
                child: Text(
                  'Please sign in to view scan history.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 14,
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: AppColors.primaryText,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'View\nHistory',
                            style: TextStyle(
                              fontSize: isSmall ? 26 : 32,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                              height: 1.05,
                              color: AppColors.primaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primaryPurple.withAlpha(70),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 10),
                            child: Text(
                              'Scans',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.italic,
                                color: AppColors.primaryText,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
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
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                              filled: true,
                              fillColor: AppColors.mainBackground,
                              prefixIcon: const Icon(
                                Icons.search,
                                color: AppColors.secondaryText,
                                size: 20,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: const TextStyle(
                              color: AppColors.primaryText,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 24,
                              runSpacing: 8,
                              children: _filters.map((filter) {
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedFilter = filter;
                                    });
                                  },
                                  child: _HistoryFilter(
                                    label: filter,
                                    selected: _selectedFilter == filter,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .collection('scans')
                                .orderBy('scannedAt', descending: true)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 30),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primaryPurple,
                                    ),
                                  ),
                                );
                              }

                              if (!snapshot.hasData ||
                                  snapshot.data!.docs.isEmpty) {
                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 24,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.mainBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.divider,
                                    ),
                                  ),
                                  child: const Text(
                                    'No scans found yet.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.secondaryText,
                                      fontSize: 14,
                                    ),
                                  ),
                                );
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
                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 24,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.mainBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.divider,
                                    ),
                                  ),
                                  child: const Text(
                                    'No matching scans found.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.secondaryText,
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              }

                              return Column(
                                children: filteredDocs.map((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;

                                  final String url =
                                      data['url']?.toString() ?? 'No URL found';

                                  final String status = _normalizeStatus(
                                    (data['verdict'] ??
                                            data['result'] ??
                                            'safe')
                                        .toString(),
                                  );

                                  final Timestamp? scannedAt =
                                      data['scannedAt'] as Timestamp?;

                                  final String scannedTime = scannedAt != null
                                      ? scannedAt
                                          .toDate()
                                          .toString()
                                          .substring(0, 19)
                                      : 'Recently';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.mainBackground,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.divider,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          url,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.primaryText,
                                            fontSize: 14,
                                            fontStyle: FontStyle.italic,
                                            height: 1.3,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                scannedTime,
                                                style: const TextStyle(
                                                  color:
                                                      AppColors.secondaryText,
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
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _HistoryFilter extends StatelessWidget {
  final String label;
  final bool selected;

  const _HistoryFilter({
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: selected ? AppColors.primaryText : AppColors.secondaryText,
        fontSize: 13,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontStyle: FontStyle.italic,
        decoration: selected ? TextDecoration.underline : TextDecoration.none,
        decorationColor: AppColors.primaryText,
        decorationThickness: 2,
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
    Color backgroundColor;

    switch (status) {
      case 'Safe':
        backgroundColor = Colors.green;
        break;
      case 'Suspicious':
        backgroundColor = Colors.orange;
        break;
      case 'Malicious':
        backgroundColor = Colors.redAccent;
        break;
      default:
        backgroundColor = AppColors.primaryPurple;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor.withAlpha(220),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}