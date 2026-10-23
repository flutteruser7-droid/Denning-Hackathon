import 'package:flutter/material.dart';
import 'package:emergency_app/Admin/admin_dashboard_ui.dart';

class AmbulanceDashboard extends StatelessWidget {
  const AmbulanceDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminDashboardUI(
      serviceType: 'Ambulance',
      primaryColor: Color(0xFF38A169),
      serviceIcon: Icons.medical_services,
    );
  }
}