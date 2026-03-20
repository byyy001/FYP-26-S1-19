import 'package:cloud_firestore/cloud_firestore.dart'; // For Firestore querying
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For getting current user details
import '../services/google_safe_browsing_service.dart'; // Safe Browsing API

class RegisteredHomeScreen extends StatefulWidget {
  const RegisteredHomeScreen({super.key});

  @override
  State<RegisteredHomeScreen> createState() => _RegisteredHomeScreenState();
}

class _RegisteredHomeScreenState extends State<RegisteredHomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;

  // Fetch the user's first name from Firebase Firestore
  Future<String> getUserFirstName() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        String firstName = userDoc['firstName'] ?? 'User';
        return firstName;
      }
    }
    return 'User'; // Fallback if user data is not found
  }

  // Classify URL using Google Safe Browsing API
  Future<void> _scanURL(String url) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use Google Safe Browsing API to classify the URL
      bool isSafe = await GoogleSafeBrowsingService().isUrlSafe(url);

      // Show the result to the user
      if (isSafe) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This URL is safe!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This URL is unsafe!'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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
        centerTitle: true,
        title: Image.asset(
          'assets/images/LinkSentryLogoTop.png',
          height: 40,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: AppColors.primaryText),
            onPressed: () {
              // Navigate to profile screen
            },
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: getUserFirstName(), // Fetch the user's first name from Firestore
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error fetching user data'));
          }

          String userName = snapshot.data ?? 'User';

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Greeting with actual user name from Firestore
                  Text(
                    'Ready To Scan $userName?',
                    style: TextStyle(
                      fontSize: isSmall ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap camera to scan link or paste URL below',
                    style: TextStyle(
                      fontSize: isSmall ? 14 : 16,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Stats cards (dummy data for now)
                  Row(
                    children: [
                      _buildStatCard('Total Scans', '100', AppColors.primaryText),
                      const SizedBox(width: 12),
                      _buildStatCard('Safe Links', '80', AppColors.safe),
                      const SizedBox(width: 12),
                      _buildStatCard('Threats', '20', AppColors.highRisk),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Scan section
                  Text(
                    'Scan a Link',
                    style: TextStyle(
                      fontSize: isSmall ? 18 : 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paste any URL to check if it\'s safe',
                    style: TextStyle(
                      fontSize: isSmall ? 12 : 14,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // URL input row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: InputDecoration(
                            hintText: 'example-link.com',
                            hintStyle: TextStyle(color: AppColors.disabledText),
                            filled: true,
                            fillColor: AppColors.cardBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          style: const TextStyle(color: AppColors.primaryText),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildScanButton(context), // Scan button
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.cardBackground,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryPurple,
        unselectedItemColor: AppColors.secondaryText,
        currentIndex: 1, // Home selected
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.help_outline), label: 'Help'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
        onTap: (index) {
          // Handle navigation here
        },
      ),
    );
  }

  // Stats card widget
  Widget _buildStatCard(String label, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Scan button widget
  Widget _buildScanButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.premiumGradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
        onPressed: () {
          // Trigger scan with the URL
          String url = _urlController.text.trim();
          if (url.isNotEmpty) {
            _scanURL(url); // Call the scan function
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please enter a URL')),
            );
          }
        },
        child: const Text('Scan'),
      ),
    );
  }
}