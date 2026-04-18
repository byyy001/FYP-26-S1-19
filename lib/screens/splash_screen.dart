import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'onboarding_screen.dart';
import 'unregistered_home_screen.dart';
import 'registered_home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 2500));

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();

    final bool onboardingCompleted = prefs.getBool('onboardingCompleted') ?? false;
    final User? user = FirebaseAuth.instance.currentUser;
    final bool isGuestMode = prefs.getBool('isGuestMode') ?? false;

    if (!onboardingCompleted) {
      // First launch – show onboarding
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    } else {
      // Onboarding already completed
      if (user != null) {
        // Logged in
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RegisteredHomeScreen()),
        );
      } else if (isGuestMode) {
        // Guest mode active
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const UnregisteredHomeScreen()),
        );
      } else {
        // No user, not guest – should not happen, but fallback to onboarding
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF151515),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 1),
              child: Image.asset(
                'assets/images/LinkSentryLogo.png',
                width: screenWidth * 0.6,
                fit: BoxFit.contain,
              ),
              builder: (context, double opacity, child) {
                return Opacity(opacity: opacity, child: child);
              },
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
          ],
        ),
      ),
    );
  }
}
