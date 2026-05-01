import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:linksentry/screens/login_screen.dart';
import 'package:linksentry/screens/scan_settings_screen.dart';
import 'package:linksentry/screens/signup_screen.dart';
import 'firebase_options.dart';
import 'constants/app_colors.dart';
import 'screens/result_screen.dart';
import 'screens/invalid_url_screen.dart';
import 'screens/view_history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/admin/dashboard_screen.dart';
import 'screens/admin/user_management_screen.dart';
import 'screens/admin/security_management_screen.dart';
import 'screens/admin/scan_statistics_screen.dart';
import 'screens/admin/flagged_reviews_screen.dart';
import 'screens/admin/admin_system_settings_screen.dart';
import 'screens/engineer/engineer_dashboard_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/unregistered_home_screen.dart';
import 'screens/registered_home_screen.dart';
import 'screens/about_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await NotificationService.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LinkSentry',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.mainBackground,
      ),

      home: const SplashScreen(),
    );
  }
}