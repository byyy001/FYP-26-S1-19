import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import 'scan_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'help_screen.dart';
import 'about_screen.dart';
import 'unregistered_home_screen.dart';
import 'report_history_screen.dart';
import 'delete_account_screen.dart';   // <-- added for delete account

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;

  String _fullName = 'User';
  String _email = '';
  bool _isPremium = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _fullName = 'Guest User';
          _email = '';
          _isPremium = false;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data();

      final settingsDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('scan_preferences')
          .get();

      final settingsData = settingsDoc.data();

      final firstName = data?['firstName']?.toString().trim() ?? '';
      final lastName = data?['lastName']?.toString().trim() ?? '';
      final fullName = '$firstName $lastName'.trim();

      if (!mounted) return;

      setState(() {
        _fullName = fullName.isNotEmpty ? fullName : 'User';
        _email = user.email ?? '';
        _isPremium = settingsData?['isPremium'] ?? false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _fullName = 'User';
        _email = user.email ?? '';
        _isPremium = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const UnregisteredHomeScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $e'),
          backgroundColor: AppColors.highRisk,
        ),
      );
    }
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label coming soon'),
        backgroundColor: AppColors.primaryPurple,
      ),
    );
  }

  Future<void> _deleteScanHistory() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in first.'),
          backgroundColor: AppColors.highRisk,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Delete Scan History',
          style: TextStyle(color: AppColors.primaryText),
        ),
        content: const Text(
          'Are you sure you want to delete all scan history?',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.highRisk),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final scansRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('scans');

      final snapshot = await scansRef.get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete scan history: $e'),
          backgroundColor: AppColors.highRisk,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmall = screenWidth < 360;

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
          'My Profile',
          style: TextStyle(
            color: AppColors.primaryText,
            fontSize: isSmall ? 20 : 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryPurple,
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile card
                    _buildProfileCard(),
                    const SizedBox(height: 24),

                    // Account section
                    _buildSectionCard(
                      title: 'Account',
                      icon: Icons.account_circle_outlined,
                      children: [
                        _ProfileSettingTile(
                          label: 'Delete Scan History',
                          onTap: _deleteScanHistory,
                        ),
                        _ProfileSettingTile(
                          label: 'Delete Account',
                          isDestructive: true,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DeleteAccountScreen(),
                              ),
                            );
                          },
                          showDivider: false,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Preferences section
                    _buildSectionCard(
                      title: 'Preferences',
                      icon: Icons.tune_outlined,
                      children: [
                        _ProfileSettingTile(
                          label: 'Scan Settings',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ScanSettingsScreen(),
                              ),
                            );
                          },
                        ),
                        _ProfileSettingTile(
                          label: 'Push Notifications',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const NotificationSettingsScreen(),
                              ),
                            );
                          },
                          showDivider: false,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Support section
                    _buildSectionCard(
                      title: 'Support',
                      icon: Icons.help_outline,
                      children: [
                        _ProfileSettingTile(
                          label: 'Report History',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ReportHistoryScreen(),
                              ),
                            );
                          },
                        ),
                        _ProfileSettingTile(
                          label: 'Help',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HelpScreen(),
                              ),
                            );
                          },
                        ),
                        _ProfileSettingTile(
                          label: 'About',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AboutScreen(),
                              ),
                            );
                          },
                          showDivider: false,
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // Sign Out button
                    Center(
                      child: SizedBox(
                        width: screenWidth * 0.52,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _signOut,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.highRisk,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Sign Out',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.primaryPurple.withOpacity(0.2),
            child: Icon(
              Icons.person,
              size: 32,
              color: AppColors.primaryPurple,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fullName,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _email.isNotEmpty ? _email : 'No email found',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _isPremium
                        ? AppColors.primaryPurple.withOpacity(0.15)
                        : AppColors.disabledText.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isPremium
                          ? AppColors.primaryPurple
                          : AppColors.disabledText,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _isPremium ? 'Premium User' : 'Free User',
                    style: TextStyle(
                      color: _isPremium
                          ? AppColors.primaryPurple
                          : AppColors.secondaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primaryPurple),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileSettingTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool showDivider;
  final bool isDestructive;

  const _ProfileSettingTile({
    required this.label,
    required this.onTap,
    this.showDivider = true,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor =
        isDestructive ? AppColors.highRisk : AppColors.primaryText;

    return Column(
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          title: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: isDestructive
                ? AppColors.highRisk.withOpacity(0.7)
                : AppColors.secondaryText,
          ),
          onTap: onTap,
        ),
        if (showDivider)
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.divider,
          ),
      ],
    );
  }
}