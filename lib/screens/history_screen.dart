import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmall = screenWidth < 360;

    final List<Map<String, String>> historyItems = [
      {
        'url': 'exampleurl1.com',
        'date': 'Jan 21, 19:00',
        'status': 'Safe',
      },
      {
        'url': 'exampleurl2.com',
        'date': 'Jan 22, 19:00',
        'status': 'Suspicious',
      },
      {
        'url': 'exampleurl3.com',
        'date': 'Jan 25, 19:00',
        'status': 'Malicious',
      },
      {
        'url': 'exampleurl4.com',
        'date': 'Feb 14, 13:00',
        'status': 'Malicious',
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'View\nHistory',
                style: TextStyle(
                  fontSize: isSmall ? 26 : 32,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                  height: 1.0,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
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
                    Text(
                      'Scans',
                      style: TextStyle(
                        fontSize: isSmall ? 18 : 20,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search scans...',
                        hintStyle: const TextStyle(
                          color: AppColors.disabledText,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                        filled: true,
                        fillColor: AppColors.mainBackground,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: AppColors.primaryText),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        _HistoryFilter(label: 'All', selected: true),
                        _HistoryFilter(label: 'Safe', selected: false),
                        _HistoryFilter(label: 'Suspicious', selected: false),
                        _HistoryFilter(label: 'Malicious', selected: false),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...historyItems.map(
                      (item) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.mainBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['url']!,
                                    style: const TextStyle(
                                      color: AppColors.primaryText,
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item['date']!,
                                    style: const TextStyle(
                                      color: AppColors.secondaryText,
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _HistoryStatusBadge(status: item['status']!),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.cardBackground,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryPurple,
        unselectedItemColor: AppColors.secondaryText,
        currentIndex: 1,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
        onTap: (index) {},
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
    Color textColor = Colors.white;

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
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}