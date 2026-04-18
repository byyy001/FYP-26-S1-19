import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import 'scan_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'help_screen.dart';
import 'about_screen.dart';
import 'unregistered_home_screen.dart';

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

      final firstName = data?['firstName']?.toString().trim() ?? '';
      final lastName = data?['lastName']?.toString().trim() ?? '';
      final fullName = '$firstName $lastName'.trim();

      if (!mounted) return;

      setState(() {
        _fullName = fullName.isNotEmpty ? fullName : 'User';
        _email = user.email ?? '';
        _isPremium = data?['isPremium'] ?? true;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _fullName = 'User';
        _email = user.email ?? '';
        _isPremium = true;
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmall = screenWidth < 360;

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryPurple,
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back + title
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
                            'My\nProfile',
                            style: TextStyle(
                              fontSize: isSmall ? 26 : 32,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                              height: 1.0,
                              color: AppColors.primaryText,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Profile card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primaryPurple.withAlpha(70),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: isSmall ? 28 : 34,
                            backgroundColor:
                                AppColors.disabledText.withAlpha(100),
                            child: Icon(
                              Icons.person,
                              size: isSmall ? 28 : 34,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _fullName,
                                  style: const TextStyle(
                                    color: AppColors.primaryText,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FontStyle.italic,
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
                                        ? AppColors.primaryPurple.withAlpha(35)
                                        : AppColors.disabledText.withAlpha(35),
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
                    ),

                    const SizedBox(height: 22),

                    // Account section
                    _buildSectionCard(
                      title: 'Account',
                      children: [
                        _ProfileSettingTile(
                          label: 'Delete Scan History',
                          onTap: () => _showComingSoon('Delete Scan History'),
                        ),
                        _ProfileSettingTile(
                          label: 'Delete Account',
                          isDestructive: true,
                          onTap: () => _showComingSoon('Delete Account'),
                          showDivider: false,
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Preferences section
                    _buildSectionCard(
                      title: 'Preferences',
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

                    const SizedBox(height: 18),

                    // Support section
                    _buildSectionCard(
                      title: 'Support',
                      children: [
                        _ProfileSettingTile(
                          label: 'Report Issues',
                          onTap: () => _showComingSoon('Report Issues'),
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

                    const SizedBox(height: 26),

                    Center(
                      child: SizedBox(
                        width: screenWidth * 0.52,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _signOut,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.redAccent.withAlpha(130),
                              width: 1,
                            ),
                            foregroundColor: Colors.redAccent,
                            backgroundColor: Colors.redAccent.withAlpha(18),
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

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryPurple.withAlpha(50),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.disabledText.withAlpha(35),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
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
        isDestructive ? Colors.redAccent : AppColors.primaryText;

    return Column(
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          title: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: isDestructive ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: isDestructive
                ? Colors.redAccent.withAlpha(180)
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