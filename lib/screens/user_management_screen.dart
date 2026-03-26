import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

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

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: SafeArea(
        child: Row(
          children: [
            const _AdminSidebar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1380),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _TopHeader(),
                        const SizedBox(height: 10),
                        const _PageTitleSection(),
                        const SizedBox(height: 14),
                        const _SearchAndFiltersPanel(),
                        const SizedBox(height: 18),
                        ...users.map(
                          (user) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _UserCard(user: user),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const _PaginationSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          right: BorderSide(
            color: AppColors.primaryPurple.withAlpha(45),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: AppColors.premiumGradient,
                    ),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'LinkSentry Admin',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const _SidebarItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
            ),
            const _SidebarItem(
              icon: Icons.people_outline,
              label: 'User Management',
              selected: true,
            ),
            const _SidebarItem(
              icon: Icons.security_outlined,
              label: 'Security Management',
            ),
            const _SidebarItem(
              icon: Icons.analytics_outlined,
              label: 'Scan Statistics',
            ),
            const _SidebarItem(
              icon: Icons.storage_outlined,
              label: 'Database Management',
            ),
            const _SidebarItem(
              icon: Icons.flag_outlined,
              label: 'Flagged Reviews',
            ),
            const _SidebarItem(
              icon: Icons.memory_outlined,
              label: 'System Usage',
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.mainBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primaryPurple.withAlpha(45),
                ),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person_outline, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin User',
                          style: TextStyle(
                            color: AppColors.primaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'admin@linksentry.com',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.logout, color: AppColors.secondaryText, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _SidebarItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primaryPurple.withAlpha(35)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: selected
            ? Border.all(color: AppColors.primaryPurple.withAlpha(80))
            : null,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: selected
              ? AppColors.primaryPurple
              : AppColors.secondaryText,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: selected
                ? AppColors.primaryText
                : AppColors.secondaryText,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        onTap: () {},
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'User Management',
      style: TextStyle(
        color: AppColors.primaryText,
        fontSize: 30,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _PageTitleSection extends StatelessWidget {
  const _PageTitleSection();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Manage user accounts, roles, and account statuses.',
      style: TextStyle(
        color: AppColors.secondaryText,
        fontSize: 14,
      ),
    );
  }
}

class _SearchAndFiltersPanel extends StatelessWidget {
  const _SearchAndFiltersPanel();

  @override
  Widget build(BuildContext context) {
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
            width: 360,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primaryPurple.withAlpha(35),
              ),
            ),
            child: const TextField(
              style: TextStyle(color: AppColors.primaryText),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search users...',
                hintStyle: TextStyle(color: AppColors.disabledText),
                prefixIcon: Icon(Icons.search, color: AppColors.secondaryText),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primaryPurple.withAlpha(30)
            : AppColors.mainBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? AppColors.primaryPurple.withAlpha(80)
              : Colors.white10,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.primaryText : AppColors.secondaryText,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 18),
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            child: Icon(
              Icons.person_outline,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 17,
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
          const SizedBox(width: 12),
          SizedBox(
            width: 360,
            child: Row(
              children: [
                const Text(
                  'Role:',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 96,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _InfoBadge(
                      label: user.role,
                      textColor: AppColors.primaryText,
                      backgroundColor: Colors.white10,
                    ),
                  ),
                ),
                const SizedBox(width: 28),
                const Text(
                  'Status:',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 120,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _InfoBadge(
                      label: user.status,
                      textColor:
                          isActive ? Colors.greenAccent : Colors.redAccent,
                      backgroundColor: isActive
                          ? Colors.greenAccent.withAlpha(25)
                          : Colors.redAccent.withAlpha(25),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 92,
            height: 40,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryText,
                side: BorderSide(
                  color: AppColors.primaryPurple.withAlpha(80),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Edit',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 2),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color backgroundColor;

  const _InfoBadge({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PaginationSection extends StatelessWidget {
  const _PaginationSection();

  @override
  Widget build(BuildContext context) {
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
            SizedBox(width: 10),
            _PageNumber(label: '1', selected: true),
            SizedBox(width: 10),
            _PageNumber(label: '2'),
            SizedBox(width: 10),
            _PageNumber(label: '3'),
            SizedBox(width: 10),
            _PageNumber(label: '4'),
            SizedBox(width: 10),
            _PageNumber(label: '5'),
            SizedBox(width: 10),
            _PageNumber(label: '6'),
            SizedBox(width: 10),
            _PageArrow(icon: Icons.chevron_right),
          ],
        ),
      ],
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
          color: selected ? AppColors.primaryPurple : Colors.white10,
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
        border: Border.all(color: Colors.white10),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primaryPurple.withAlpha(35),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withAlpha(14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}