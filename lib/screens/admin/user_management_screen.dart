import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const users = [
      _UserData(
        name: 'John Doe',
        email: 'john@email.com',
        role: 'User',
        status: 'Active',
      ),
      _UserData(
        name: 'Jane Doe',
        email: 'jane@email.com',
        role: 'User',
        status: 'Suspended',
      ),
      _UserData(
        name: 'Michael Tan',
        email: 'michael@linksentry.com',
        role: 'Admin',
        status: 'Active',
      ),
      _UserData(
        name: 'Sarah Lim',
        email: 'sarah@email.com',
        role: 'User',
        status: 'Active',
      ),
      _UserData(
        name: 'Daniel Ng',
        email: 'daniel@linksentry.com',
        role: 'Engineer',
        status: 'Active',
      ),
      _UserData(
        name: 'Rachel Lee',
        email: 'rachel@email.com',
        role: 'User',
        status: 'Suspended',
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'User Management',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Manage user accounts, roles, and account statuses.',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              _buildSearchAndFiltersPanel(),
              const SizedBox(height: 24),
              ...users.map(
                (user) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _UserCard(user: user),
                ),
              ),
              const SizedBox(height: 24),
              _buildPaginationSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFiltersPanel() {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  _FilterChip(label: 'All', selected: true),
                  _FilterChip(label: 'User'),
                  _FilterChip(label: 'Admin'),
                  _FilterChip(label: 'Engineer'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: 320,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryPurple.withOpacity(0.35),
              ),
            ),
            child: const TextField(
              style: TextStyle(color: AppColors.primaryText),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search users...',
                hintStyle: TextStyle(color: AppColors.disabledText),
                prefixIcon: Icon(Icons.search, color: AppColors.secondaryText),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationSection() {
    return Column(
      children: [
        const Center(
          child: Text(
            'Showing 1–6 of 35 Users',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            _PageArrow(icon: Icons.chevron_left),
            SizedBox(width: 8),
            _PageNumber(label: '1', selected: true),
            SizedBox(width: 8),
            _PageNumber(label: '2'),
            SizedBox(width: 8),
            _PageNumber(label: '3'),
            SizedBox(width: 8),
            _PageNumber(label: '4'),
            SizedBox(width: 8),
            _PageNumber(label: '5'),
            SizedBox(width: 8),
            _PageNumber(label: '6'),
            SizedBox(width: 8),
            _PageArrow(icon: Icons.chevron_right),
          ],
        ),
      ],
    );
  }
}

class _UserData {
  final String name;
  final String email;
  final String role;
  final String status;

  const _UserData({
    required this.name,
    required this.email,
    required this.role,
    required this.status,
  });
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _FilterChip({
    required this.label,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primaryPurple.withOpacity(0.2)
            : AppColors.mainBackground,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: selected
              ? AppColors.primaryPurple.withOpacity(0.6)
              : AppColors.divider.withOpacity(0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.primaryText : AppColors.secondaryText,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final _UserData user;

  const _UserCard({
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = user.status == 'Active';

    return _Panel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person_outline, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                const Text(
                  'Role:',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.role,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                const Text(
                  'Status:',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.safe.withOpacity(0.2)
                        : AppColors.highRisk.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive
                          ? AppColors.safe.withOpacity(0.5)
                          : AppColors.highRisk.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    user.status,
                    style: TextStyle(
                      color: isActive ? AppColors.safe : AppColors.highRisk,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            height: 40,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryText,
                side: BorderSide(color: AppColors.primaryPurple.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageNumber extends StatelessWidget {
  final String label;
  final bool selected;

  const _PageNumber({
    required this.label,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryPurple : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? AppColors.primaryPurple : AppColors.divider.withOpacity(0.3),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PageArrow extends StatelessWidget {
  final IconData icon;

  const _PageArrow({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider.withOpacity(0.3)),
      ),
      child: Icon(
        icon,
        color: AppColors.secondaryText,
        size: 20,
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _Panel({
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryPurple.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}