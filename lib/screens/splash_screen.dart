import 'package:flutter/material.dart';
import 'package:linksentry/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserStatus();
    });
  }

  Future<void> _checkUserStatus() async {
    // Run the 2s delay and auth/shared-URL fetch in parallel
    final results = await Future.wait([
      Future.delayed(const Duration(seconds: 2)),
      FirebaseAuth.instance.authStateChanges().first,
      ReceiveSharingIntent.instance.getInitialMedia(),
    ]);

    if (!mounted) return;

    if (kIsWeb) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final bool hasSeenOnboarding = prefs.getBool('seenOnboarding') ?? false;

    final User? user = results[1] as User?;

    // Extract shared URL if app was cold-started via a share intent
    final sharedFiles = results[2] as List<SharedMediaFile>;
    String? sharedUrl;
    for (final file in sharedFiles) {
      if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
        final urlRegex = RegExp(r'https?://[^\s]+|www\.[^\s]+', caseSensitive: false);
        final match = urlRegex.firstMatch(file.path);
        sharedUrl = (match?.group(0) ?? file.path).trim();
        break;
      }
    }
    if (sharedFiles.isNotEmpty) ReceiveSharingIntent.instance.reset();

    if (!hasSeenOnboarding) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => OnboardingScreen()),
      );
      return;
    }
    if (user == null || user.isAnonymous) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => UnregisteredHomeScreen(initialUrl: sharedUrl)),
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => RegisteredHomeScreen(initialUrl: sharedUrl)),
    );
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
