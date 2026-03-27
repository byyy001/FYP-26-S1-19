import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:linksentry/screens/signup_screen.dart';
import 'firebase_options.dart';
import 'constants/app_colors.dart';
import 'screens/result_screen.dart';
import 'screens/invalid_url_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/user_management_screen.dart';
import 'screens/security_management_screen.dart';
import 'screens/scan_statistics_screen.dart';
import 'screens/flagged_reviews_screen.dart';
import 'screens/system_settings_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

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
      home: const SystemSettingsScreen()
    );
  }
}