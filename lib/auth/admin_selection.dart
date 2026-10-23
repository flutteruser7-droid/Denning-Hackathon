import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:emergency_app/auth/admin_login.dart';

class AdminSelection extends StatelessWidget {
  const AdminSelection({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060E1F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Admin Portal',
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select your emergency service department to login.',
                style: GoogleFonts.openSans(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 40),
              _buildAdminOption(
                context,
                icon: Icons.local_police,
                title: 'Police Admin',
                color: const Color(0xFF3B7DE8), // Blue
                serviceType: 'Police',
              ),
              const SizedBox(height: 20),
              _buildAdminOption(
                context,
                icon: Icons.medical_services,
                title: 'Ambulance Admin',
                color: const Color(0xFF38A169), // Green
                serviceType: 'Ambulance',
              ),
              const SizedBox(height: 20),
              _buildAdminOption(
                context,
                icon: Icons.local_fire_department,
                title: 'Fire Brigade Admin',
                color: const Color(0xFFE53E3E), // Red
                serviceType: 'Fire Brigade',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required String serviceType,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AdminLoginScreen(departmentType: serviceType)),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF101F35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.5), size: 16),
          ],
        ),
      ),
    );
  }
}
