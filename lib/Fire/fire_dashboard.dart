import 'package:flutter/material.dart';
import 'package:emergency_app/Admin/admin_dashboard_ui.dart';

class FireDashboard extends StatelessWidget {
  const FireDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminDashboardUI(
      serviceType: 'Fire Brigade',
      primaryColor: Color(0xFFE53E3E),
      serviceIcon: Icons.local_fire_department,
    );
  }
}