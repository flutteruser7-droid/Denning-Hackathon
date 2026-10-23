import 'package:flutter/material.dart';
import 'package:emergency_app/Admin/admin_dashboard_ui.dart';

class PoliceDashboard extends StatelessWidget {
  const PoliceDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminDashboardUI(
      serviceType: 'Police',
      primaryColor: Color(0xFF1D4ED8),
      serviceIcon: Icons.local_police,
    );
  }
}