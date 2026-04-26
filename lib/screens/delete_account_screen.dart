import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import 'unregistered_home_screen.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _isConfirmed = false;
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Delete Account',
          style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Warning icon and title
              Center(
                child: Column(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.highRisk, size: 64),
                    const SizedBox(height: 12),
                    const Text(
                      'Delete Account',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryText),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Warning message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.highRisk.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.highRisk.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'This action cannot be undone. This will permanently delete:',
                      style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 12),
                    BulletPoint(text: 'All your scan history'),
                    BulletPoint(text: 'Your saved scan preferences'),
                    BulletPoint(text: 'Your account information'),
                    BulletPoint(text: 'Your account settings'),
                    SizedBox(height: 12),
                    Text(
                      'If you agree that this will permanently delete the above data of your account, please proceed to delete.',
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Confirmation checkbox
              Row(
                children: [
                  Checkbox(
                    value: _isConfirmed,
                    onChanged: (val) => setState(() => _isConfirmed = val ?? false),
                    activeColor: AppColors.primaryPurple,
                    checkColor: Colors.white,
                  ),
                  const Expanded(
                    child: Text(
                      'I have read the above and understand this is permanent',
                      style: TextStyle(color: AppColors.primaryText),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isDeleting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.secondaryText),
                        foregroundColor: AppColors.secondaryText,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_isConfirmed && !_isDeleting) ? _deleteAccount : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.highRisk,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isDeleting
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('DELETE'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    setState(() => _isDeleting = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user signed in'), backgroundColor: AppColors.highRisk),
      );
      Navigator.pop(context);
      return;
    }

    try {
      final userId = user.uid;
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(userId);

      // Delete all subcollections
      final batch = FirebaseFirestore.instance.batch();

      // Delete scans subcollection
      final scansSnapshot = await userDocRef.collection('scans').get();
      for (final doc in scansSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete settings subcollection
      final settingsSnapshot = await userDocRef.collection('settings').get();
      for (final doc in settingsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete false reports submitted by this user
      final reportsSnapshot = await FirebaseFirestore.instance
          .collection('false_reports')
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in reportsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete user document itself
      batch.delete(userDocRef);

      // Commit batch
      await batch.commit();

      // Delete Firebase Auth user
      await user.delete();

      // Sign out (already deleted, but for safety)
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      // Navigate to unregistered home screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const UnregisteredHomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete account: $e'), backgroundColor: AppColors.highRisk),
      );
      setState(() => _isDeleting = false);
    }
  }
}

// Helper widget for bullet points
class BulletPoint extends StatelessWidget {
  final String text;
  const BulletPoint({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.secondaryText, fontSize: 14)),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.secondaryText, fontSize: 14))),
        ],
      ),
    );
  }
}