import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:emergency_app/auth/login.dart';
import 'package:emergency_app/auth/admin_selection.dart';

class RoleSelection extends StatelessWidget {
  const RoleSelection({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060E1F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset(
                  'assets/logo.png',
                  height: 100,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.health_and_safety, size: 100, color: Colors.red),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Welcome to Emergency App',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please select your role to continue',
                textAlign: TextAlign.center,
                style: GoogleFonts.openSans(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 60),
              _buildRoleButton(
                context,
                icon: Icons.person,
                title: 'User Login',
                subtitle: 'For general users seeking emergency help',
                color: const Color(0xFF3B7DE8),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildRoleButton(
                context,
                icon: Icons.admin_panel_settings,
                title: 'Admin Login',
                subtitle: 'For Police, Ambulance, and Fire Brigade',
                color: const Color(0xFFE53E3E),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminSelection()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF101F35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.5), size: 16),
          ],
        ),
      ),
    );
  }
}
