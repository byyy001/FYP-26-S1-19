import 'package:flutter/material.dart';
import 'onboarding_screen.dart'; // We'll navigate here after loading

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Wait 2.5 seconds, then go to onboarding
    Future.delayed(const Duration(milliseconds: 2500), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF151515), // mainBackground
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo with fade-in animation
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 1),
              child: Image.asset(
                'assets/images/LinkSentryLogo.png',
                width: screenWidth * 0.6, // Responsive width
                fit: BoxFit.contain,
              ),
              builder: (context, double opacity, child) {
                return Opacity(opacity: opacity, child: child);
              },
            ),
            const SizedBox(height: 30),
            // Subtle loading indicator (optional – remove if not wanted)
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)), // primaryPurple
            ),
          ],
        ),
      ),
    );
  }
}