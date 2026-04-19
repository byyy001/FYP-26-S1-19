import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class ThreatEngineModelsScreen extends StatelessWidget {
  const ThreatEngineModelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
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
                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.primaryPurple.withOpacity(0.35),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Testing Placeholder',
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'This section will be used later for Threat Engine AI model testing, training results, and model management.',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                _ModelCard(
                  name: 'Logistic Regression',
                  status: 'Active',
                  accuracy: '82%',
                ),

                SizedBox(height: 16),

                _ModelCard(
                  name: 'Random Forest',
                  status: 'Standby',
                  accuracy: '91%',
                ),

                SizedBox(height: 16),

                _ModelCard(name: 'XGBoost', status: 'Testing', accuracy: '94%'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 🔹 MODEL CARD
class _ModelCard extends StatelessWidget {
  final String name;
  final String status;
  final String accuracy;

  const _ModelCard({
    required this.name,
    required this.status,
    required this.accuracy,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;

    switch (status) {
      case 'Active':
        statusColor = Colors.greenAccent;
        break;
      case 'Testing':
        statusColor = Colors.orangeAccent;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryPurple.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.memory, color: AppColors.primaryPurple, size: 28),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Accuracy: $accuracy',
                  style: const TextStyle(color: AppColors.secondaryText),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: statusColor),
            ),
            child: Text(
              status,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
