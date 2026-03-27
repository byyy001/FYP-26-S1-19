import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class SecurityManagementScreen extends StatelessWidget {
  const SecurityManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _TopHeader(),
                        const SizedBox(height: 10),
                        const _PageTitleSection(),
                        const SizedBox(height: 18),
                        const _ProtectionRulesCard(),
                        const SizedBox(height: 16),
                        const _SensitivityCard(),
                        const SizedBox(height: 16),
                        const _ThresholdCard(),
                        const SizedBox(height: 16),
                        const _RateLimitCard(),
                        const SizedBox(height: 18),
                        const _SaveSettingsButton(),
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
            ),
            const _SidebarItem(
              icon: Icons.security_outlined,
              label: 'Security Management',
              selected: true,
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
      'Security Management',
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
      'Manage scanner behaviour, thresholds, and protective system rules.',
      style: TextStyle(
        color: AppColors.secondaryText,
        fontSize: 14,
      ),
    );
  }
}

class _ProtectionRulesCard extends StatelessWidget {
  const _ProtectionRulesCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Protection Rules',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Control the core protection behaviour used by the scanner.',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 16),
          _ToggleRow(
            label: 'Tracker Detection',
            subtitle: 'Detect tracking scripts and hidden trackers.',
            valueText: 'ON',
            isOn: true,
          ),
          SizedBox(height: 12),
          _ToggleRow(
            label: 'Auto Block High Risk Domains',
            subtitle: 'Prevent access to known high-risk domains.',
            valueText: 'ON',
            isOn: true,
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final String valueText;
  final bool isOn;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.valueText,
    required this.isOn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isOn ? Colors.greenAccent.withAlpha(25) : Colors.white10,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              valueText,
              style: TextStyle(
                color: isOn ? Colors.greenAccent : AppColors.secondaryText,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: isOn,
            onChanged: (_) {},
            activeColor: Colors.greenAccent,
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: Colors.white24,
          ),
        ],
      ),
    );
  }
}

class _SensitivityCard extends StatelessWidget {
  const _SensitivityCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scan Sensitivity Level',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Choose how aggressively suspicious links should be flagged.',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 16),
          _OptionSelector(
            selectedLabel: 'Medium',
          ),
        ],
      ),
    );
  }
}

class _ThresholdCard extends StatelessWidget {
  const _ThresholdCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ad-Intensity Threshold',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Choose when ad-heavy pages should trigger warnings.',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 16),
          _OptionSelector(
            selectedLabel: 'Medium',
          ),
        ],
      ),
    );
  }
}

class _OptionSelector extends StatelessWidget {
  final String selectedLabel;

  const _OptionSelector({
    required this.selectedLabel,
  });

  @override
  Widget build(BuildContext context) {
    const options = ['Low', 'Medium', 'High'];

    return Row(
      children: options.map((option) {
        final bool selected = option == selectedLabel;

        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
              option,
              style: TextStyle(
                color:
                    selected ? AppColors.primaryText : AppColors.secondaryText,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RateLimitCard extends StatelessWidget {
  const _RateLimitCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Max Scan Request Per Minute',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Set the maximum number of scan requests allowed each minute.',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primaryPurple.withAlpha(30),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.menu,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Request Limit',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '60',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveSettingsButton extends StatelessWidget {
  const _SaveSettingsButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Save Settings',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
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