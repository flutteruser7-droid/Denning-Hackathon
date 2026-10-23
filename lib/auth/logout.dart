import 'package:emergency_app/auth/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogoutHelper {
  static Future<void> logout(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      
      // Clear shared preferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // Clear native Android SOS preferences so the background service stops triggering
      try {
        const platform = MethodChannel('com.example.emergency_app/sms');
        await platform.invokeMethod('clearSosData');
      } catch (e) {
        debugPrint('Failed to clear native SOS data: $e');
      }

      // Navigate to role selection page
      if (context.mounted) {
        Navigator.pop(context); // Remove loading dialog
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Remove loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error logging out: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}