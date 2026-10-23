// import 'package:emergency_app/auth/AddEmergency.dart'; // UNUSED
import 'package:emergency_app/auth/login.dart';
import 'package:emergency_app/auth/splash_screen.dart';
// import 'package:emergency_app/services/emergency_config.dart'; // UNUSED
import 'package:emergency_app/Admin/admin_dashboard_ui.dart';
import 'package:emergency_app/theme/darkmode.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- Add this import

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // <-- Add this block to lock the app to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

// Global ThemeNotifier instance — lives for the app's lifetime
final _themeNotifier = ThemeNotifier();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeNotifierProvider(
      notifier: _themeNotifier,
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // home: AdminDashboardUI(serviceType: "Admin", primaryColor: Colors.blue, serviceIcon: Icons.admin_panel_settings),
      home: SplashScreen(),
      // home: UserDashboard(),
    );
  }
}