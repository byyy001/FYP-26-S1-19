import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import 'unregistered_home_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'terms_screen.dart';
import 'privacy_policy_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      'image': 'assets/images/Onboarding1.png',
      'title': 'URL Scanning Anytime, Anywhere',
      'description':
          'Unlike others, we scan your links immediately using your camera or manual input, so you\'re covered whether it\'s on a screen, printed papers or shared to you.',
    },
    {
      'image': 'assets/images/Onboarding2.png',
      'title': 'Beyond Basic Blocklists',
      'description':
          'Our hybrid AI detects what others miss: phishing, malware, hidden scripts, and excessive ad trackers.',
    },
    {
      'image': 'assets/images/Onboarding3.png',
      'title': 'Security That Knows You',
      'description':
          'Personalized scan settings that learn from you with AI-powered trend analysis, spot your risk patterns and receive alerts when something unusual happens.',
    },
    {
      'image': 'assets/images/Onboarding4.png',
      'title': 'No Jargon, Just Action',
      'description':
          'Clear severity levels with plain-English explanations so you know exactly what to do next.',
    },
  ];

  Future<void> _showChoiceDialog() async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text(
            'Welcome to LinkSentry!',
            style: TextStyle(color: AppColors.primaryText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8), // added for spacing
              const Text(
                'How would you like to proceed?',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            ],
          ),
          actions: [
            // Guest option
            OutlinedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut(); 

                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onboardingCompleted', true);

                if (!context.mounted) return;
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const UnregisteredHomeScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryPurple),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), // 8 → 12
                ),
              ),
              child: const Text(
                'Continue as Guest',
                style: TextStyle(color: AppColors.primaryPurple),
              ),
            ),
            // Login option
            OutlinedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onboardingCompleted', true);
                await prefs.remove('isGuestMode');
                if (!context.mounted) return;
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryPurple),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), // 8 → 12
                ),
              ),
              child: const Text(
                'Login',
                style: TextStyle(color: AppColors.primaryPurple),
              ),
            ),
            // Sign Up option
            OutlinedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onboardingCompleted', true);
                await prefs.remove('isGuestMode');
                if (!context.mounted) return;
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SignUpScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryPurple),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), // 8 → 12
                ),
              ),
              child: const Text(
                'Sign Up',
                style: TextStyle(color: AppColors.primaryPurple),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmall = screenWidth < 360;

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (int page) {
                  setState(() => _currentPage = page);
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 600),
                          child: Image.asset(
                            page['image']!,
                            height: isSmall ? 180 : 220,
                            fit: BoxFit.contain,
                          ),
                          builder: (context, double opacity, child) {
                            return Opacity(opacity: opacity, child: child);
                          },
                        ),
                        const SizedBox(height: 40),
                        Text(
                          page['title']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isSmall ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryText,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page['description']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isSmall ? 14 : 16,
                            color: AppColors.secondaryText,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppColors.primaryPurple
                        : AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24), // 20 → 24
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _showChoiceDialog,
                  child: TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0.95, end: 1.0),
                    duration: const Duration(milliseconds: 200),
                    builder: (context, double scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: AppColors.premiumGradient,
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryPurple.withAlpha(77),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'Get Started',
                              style: TextStyle(
                                fontSize: isSmall ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryText,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.disabledText,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'By using LinkSentry, you agree to our '),
                    TextSpan(
                      text: 'Terms of Use',
                      style: const TextStyle(
                        color: AppColors.primaryPurple,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const TermsScreen()),
                          );
                        },
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: const TextStyle(
                        color: AppColors.primaryPurple,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                          );
                        },
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}