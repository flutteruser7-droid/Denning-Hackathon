// add_emergency_service.dart
// import 'package:emergency_app/Admindashboard.dart'; // UNUSED - file is deprecated
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class AddEmergencyService extends StatefulWidget {
  const AddEmergencyService({super.key});

  @override
  State<AddEmergencyService> createState() => _AddEmergencyServiceState();
}

class _AddEmergencyServiceState extends State<AddEmergencyService> {
  // Controllers
  final TextEditingController _stationNameController = TextEditingController();
  final TextEditingController _inChargeNameController = TextEditingController();
  final TextEditingController _badgeNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _vehicleCountController = TextEditingController();
  final TextEditingController _emergencyNumberController =
      TextEditingController();

  String? _selectedServiceType = 'Police';
  String? _selectedZone = 'Zone A';
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Location variables
  String _area = '';
  String _city = '';
  String _district = '';
  double _latitude = 0.0;
  double _longitude = 0.0;
  bool _isLocationLoading = false;

  // Service Types with colors & icons
  final List<Map<String, dynamic>> _serviceTypes = [
    {
      'name': 'Police',
      'icon': Icons.local_police,
      'color': const Color(0xFF1565C0),
      'serviceIdPrefix': 'POL',
    },
    {
      'name': 'Fire Brigade',
      'icon': Icons.local_fire_department,
      'color': const Color(0xFFB71C1C),
      'serviceIdPrefix': 'FIRE',
    },
    {
      'name': 'Ambulance',
      'icon': Icons.medical_services,
      'color': const Color(0xFF1B5E20),
      'serviceIdPrefix': 'AMB',
    },
  ];

  final List<String> _zones = [
    'Zone A',
    'Zone B',
    'Zone C',
    'Zone D',
    'Central',
    'North',
    'South',
    'East',
    'West',
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _stationNameController.dispose();
    _inChargeNameController.dispose();
    _badgeNumberController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    _vehicleCountController.dispose();
    _emergencyNumberController.dispose();
    super.dispose();
  }

  Color get _serviceColor {
    return _serviceTypes.firstWhere(
      (s) => s['name'] == _selectedServiceType,
      orElse: () => _serviceTypes[0],
    )['color'];
  }

  IconData get _serviceIcon {
    return _serviceTypes.firstWhere(
      (s) => s['name'] == _selectedServiceType,
      orElse: () => _serviceTypes[0],
    )['icon'];
  }

  String get _serviceIdPrefix {
    return _serviceTypes.firstWhere(
      (s) => s['name'] == _selectedServiceType,
      orElse: () => _serviceTypes[0],
    )['serviceIdPrefix'];
  }
Future<void> _getCurrentLocation() async {
  setState(() => _isLocationLoading = true);

  try {
    // ✅ Step 1: Service enabled check
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // User ko GPS on karne ko kaho
      await Geolocator.openLocationSettings();
      _showSnackBar("Please turn on GPS and try again", Colors.orange);
      setState(() => _isLocationLoading = false);
      return;
    }

    // ✅ Step 2: Permission check
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar("Location permission denied", Colors.red);
        setState(() => _isLocationLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Settings mein le jao
      await Geolocator.openAppSettings();
      _showSnackBar("Enable location in App Settings", Colors.red);
      setState(() => _isLocationLoading = false);
      return;
    }

    // ✅ Step 3: LOW accuracy try karo pehle (IO_ERROR fix)
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low, // low se start karo
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      // ✅ Fallback: Last known location use karo
      position = await Geolocator.getLastKnownPosition();
    }

    if (position == null) {
      _showSnackBar("Could not get location. Enter address manually", Colors.orange);
      setState(() => _isLocationLoading = false);
      return;
    }

    _latitude = position.latitude;
    _longitude = position.longitude;

// ✅ Step 4: Geocoding — smart city & district detection
try {
  List<Placemark> placemarks = await placemarkFromCoordinates(
    _latitude,
    _longitude,
  ).timeout(const Duration(seconds: 10));

  if (placemarks.isNotEmpty) {
    Placemark p = placemarks[0];

    // ✅ Debug — console mein sab fields dekho
    debugPrint("=== PLACEMARK DEBUG ===");
    debugPrint("name:                 ${p.name}");
    debugPrint("street:               ${p.street}");
    debugPrint("subLocality:          ${p.subLocality}");
    debugPrint("locality:             ${p.locality}");
    debugPrint("subAdminArea:         ${p.subAdministrativeArea}");
    debugPrint("adminArea:            ${p.administrativeArea}");
    debugPrint("postalCode:           ${p.postalCode}");
    debugPrint("country:              ${p.country}");
    debugPrint("======================");

    // ✅ Area — mohalla / neighborhood
    String detectedArea = '';
    if (p.subLocality != null && p.subLocality!.isNotEmpty) {
      detectedArea = p.subLocality!;
    } else if (p.locality != null && p.locality!.isNotEmpty) {
      detectedArea = p.locality!;
    } else if (p.name != null && p.name!.isNotEmpty) {
      detectedArea = p.name!;
    }

    // ✅ City — proper city name
    String detectedCity = '';
    if (p.locality != null && p.locality!.isNotEmpty) {
      detectedCity = p.locality!;
    } else if (p.subAdministrativeArea != null &&
        p.subAdministrativeArea!.isNotEmpty) {
      detectedCity = p.subAdministrativeArea!;
    } else if (p.administrativeArea != null &&
        p.administrativeArea!.isNotEmpty) {
      detectedCity = p.administrativeArea!;
    }

    // ✅ District — tehsil / district level
    String detectedDistrict = '';
    if (p.subAdministrativeArea != null &&
        p.subAdministrativeArea!.isNotEmpty) {
      detectedDistrict = p.subAdministrativeArea!;
    } else if (p.administrativeArea != null &&
        p.administrativeArea!.isNotEmpty) {
      detectedDistrict = p.administrativeArea!;
    } else if (p.locality != null && p.locality!.isNotEmpty) {
      detectedDistrict = p.locality!;
    }

    // ✅ Clean address — empty parts skip karo
    List<String> addressParts = [
      if (p.street != null && p.street!.isNotEmpty) p.street!,
      if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality!,
      if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
      if (p.subAdministrativeArea != null &&
          p.subAdministrativeArea!.isNotEmpty)
        p.subAdministrativeArea!,
      if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty)
        p.administrativeArea!,
      if (p.country != null && p.country!.isNotEmpty) p.country!,
    ];

    setState(() {
      _area     = detectedArea;
      _city     = detectedCity;
      _district = detectedDistrict;
      _addressController.text = addressParts.join(', ');
    });

    _showSnackBar("✅ Location detected successfully!", Colors.green);

  } else {
    _showSnackBar("No address found, please enter manually", Colors.orange);
  }

} catch (geocodeError) {
  debugPrint("Geocode error: $geocodeError");
  // Coordinates to hain, address nahi mila — manually enter kar sakte hain
  setState(() {
    _area     = '';
    _city     = '';
    _district = '';
  });
  _showSnackBar("Address lookup failed, please enter manually", Colors.orange);
}

  } catch (e) {
    _showSnackBar(
      "Location unavailable. Please enter address manually.",
      Colors.orange,
    );
    // ✅ Manual entry allow karo — error pe app crash nahi hogi
  } finally {
    setState(() => _isLocationLoading = false);
  }
}

  // ── Service ID generator ──
  Future<String> _generateServiceId() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('EmergencyServices')
        .where('serviceType', isEqualTo: _selectedServiceType)
        .get();

    int count = snapshot.docs.length + 1;
    String countStr = count.toString().padLeft(3, '0');
    return '$_serviceIdPrefix-$countStr'; // ✅ AMB-001 / POL-001 / FIRE-001
  }

  Future<void> _saveSession(String userId, String email) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userId', userId);
    await prefs.setString('userRole', 'emergency_service');
    await prefs.setString('userEmail', email);
    await prefs.setString('serviceType', _selectedServiceType!);
  }

  // Validation
  bool _validateInputs() {
    if (_stationNameController.text.isEmpty) {
      _showSnackBar("Please enter Station / Service Name", Colors.red);
      return false;
    }
    if (_inChargeNameController.text.isEmpty) {
      _showSnackBar("Please enter In-Charge Officer Name", Colors.red);
      return false;
    }
    if (_badgeNumberController.text.isEmpty) {
      _showSnackBar("Please enter Badge / Service Number", Colors.red);
      return false;
    }
    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
      _showSnackBar("Please enter a valid email address", Colors.red);
      return false;
    }
    if (_phoneController.text.isEmpty || _phoneController.text.length < 11) {
      _showSnackBar(
        "Please enter a valid phone number (11 digits)",
        Colors.red,
      );
      return false;
    }
    if (_emergencyNumberController.text.isEmpty) {
      _showSnackBar("Please enter emergency helpline number", Colors.red);
      return false;
    }
    if (_passwordController.text.length < 6) {
      _showSnackBar("Password must be at least 6 characters long", Colors.red);
      return false;
    }
    if (_area.isEmpty) {
      _showSnackBar("Unable to detect location. Please check GPS", Colors.red);
      return false;
    }
    return true;
  }

void _clearAllFields() {
  _stationNameController.clear();
  _inChargeNameController.clear();
  _badgeNumberController.clear();
  _emailController.clear();
  _phoneController.clear();
  _passwordController.clear();
  _addressController.clear();
  _vehicleCountController.clear();
  _emergencyNumberController.clear();

  setState(() {
    _selectedServiceType = 'Police';
    _selectedZone = 'Zone A';
    _area = '';
    _city = '';
    _district = '';
    _latitude = 0.0;
    _longitude = 0.0;
    _obscurePassword = true;
  });
}
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _registerService() async {
    if (!_validateInputs()) return;

    setState(() => _isLoading = true);

    final createdByEmail = FirebaseAuth.instance.currentUser?.email ?? 'system';

    try {
      // Check for duplicate email
      QuerySnapshot existing = await FirebaseFirestore.instance
          .collection('EmergencyServices')
          .where('email', isEqualTo: _emailController.text.trim())
          .get();

      if (existing.docs.isNotEmpty) {
        _showSnackBar("This email is already registered!", Colors.orange);
        setState(() => _isLoading = false);
        return;
      }

      // Generate unique service ID
      String serviceId = await _generateServiceId();

      // Create Firebase Auth user
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('EmergencyServices')
          .doc(userCredential.user!.uid)
          .set({
            'uid': userCredential.user!.uid,
            'serviceId': serviceId,
            'serviceType': _selectedServiceType,
            'stationName': _stationNameController.text.trim(),
            'inChargeName': _inChargeNameController.text.trim(),
            'badgeNumber': _badgeNumberController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'emergencyHelpline': _emergencyNumberController.text.trim(),
            'area': _area,
            'city': _city,
            'district': _district,
            'address': _addressController.text.trim(),
            'latitude': _latitude,
            'longitude': _longitude,
            'vehicleCount': _vehicleCountController.text.trim().isEmpty
                ? '0'
                : _vehicleCountController.text.trim(),
            'zone': _selectedZone,
            'userType': 'emergency_service',
            'status': 'active',
            'rating': 0.0,
            'totalRequests': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': createdByEmail,
          });

      _showSnackBar(
        "✓ $_selectedServiceType Service registered successfully!",
        Colors.green,
       
      );
 _clearAllFields();
      await _saveSession(
        userCredential.user!.uid,
        _emailController.text.trim(),
      );

      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        // Navigate to Admin Dashboard
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(builder: (context) => const AdminDashboard()),
        // );
      }
    } on FirebaseAuthException catch (e) {
      String msg = "An error occurred";
      if (e.code == 'email-already-in-use') msg = "Email is already in use";
      if (e.code == 'weak-password') msg = "Password is too weak";
      if (e.code == 'invalid-email') msg = "Invalid email format";
      _showSnackBar(msg, Colors.red);
    } catch (e) {
      _showSnackBar("Error: ${e.toString()}", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        "Register Emergency Service",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      // ── Service Type Selector ──
                      _buildSectionTitle("Select Service Type"),
                      const SizedBox(height: 12),
                      Row(
                        children: _serviceTypes.map((service) {
                          bool isSelected =
                              _selectedServiceType == service['name'];
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(
                                () => _selectedServiceType = service['name'],
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? service['color']
                                      : Colors.white.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? service['color']
                                        : Colors.white24,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: (service['color'] as Color)
                                                .withOpacity(0.4),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      service['icon'],
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      service['name'],
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),

                      // ── Station Info ──
                      _buildCard(
                        title: "Station / Service Information",
                        icon: _serviceIcon,
                        children: [
                          _buildTextField(
                            hint: "Station / Service Name",
                            icon: Icons.business,
                            controller: _stationNameController,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            hint: "In-Charge Officer Name",
                            icon: Icons.person_pin,
                            controller: _inChargeNameController,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            hint: "Badge / Service ID Number",
                            icon: Icons.badge,
                            controller: _badgeNumberController,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            hint: "Emergency Helpline Number (e.g., 1122)",
                            icon: Icons.sos,
                            controller: _emergencyNumberController,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            hint: "Number of Vehicles / Units",
                            icon: Icons.directions_car,
                            controller: _vehicleCountController,
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Location Info (Auto-detected) ──
                      _buildCard(
                        title: "Location Details (Auto-detected)",
                        icon: Icons.location_on,
                        children: [
                          if (_isLocationLoading)
                            const Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Center(
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 10),
                                    Text(
                                      "Fetching current location...",
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_pin,
                                        color: Colors.greenAccent,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        "📍 Current Location Detected",
                                        style: TextStyle(
                                          color: Colors.greenAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildLocationInfoRow(
                                    Icons.map,
                                    "Area",
                                    _area.isNotEmpty ? _area : "Not detected",
                                  ),
                                  const SizedBox(height: 8),
                                  _buildLocationInfoRow(
                                    Icons.location_city,
                                    "City",
                                    _city.isNotEmpty ? _city : "Not detected",
                                  ),
                                  const SizedBox(height: 8),
                                  _buildLocationInfoRow(
                                    Icons.grid_view,
                                    "District",
                                    _district.isNotEmpty
                                        ? _district
                                        : "Not detected",
                                  ),
                                  const SizedBox(height: 8),
                                  _buildLocationInfoRow(
                                    Icons.pin_drop,
                                    "Coordinates",
                                    _latitude != 0
                                        ? "${_latitude.toStringAsFixed(6)}, ${_longitude.toStringAsFixed(6)}"
                                        : "Not detected",
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _getCurrentLocation,
                              icon: const Icon(Icons.refresh),
                              label: const Text("Refresh Location"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _buildTextField(
                            hint: "Full Address (Auto-filled, can edit)",
                            icon: Icons.location_city,
                            controller: _addressController,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          _buildDropdown(
                            hint: "Select Zone",
                            icon: Icons.grid_view,
                            value: _selectedZone,
                            items: _zones,
                            onChanged: (v) => setState(() => _selectedZone = v),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Login Credentials ──
                      _buildCard(
                        title: "Login Credentials",
                        icon: Icons.lock,
                        children: [
                          _buildTextField(
                            hint: "Official Email Address",
                            icon: Icons.email,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            hint: "Contact Phone Number",
                            icon: Icons.phone,
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            hint: "Password (minimum 6 characters)",
                            icon: Icons.lock_outline,
                            controller: _passwordController,
                            isPassword: true,
                            obscureText: _obscurePassword,
                            onToggleVisibility: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // ── Register Button ──
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _serviceColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 8,
                          ),
                          onPressed: (_isLoading || _isLocationLoading)
                              ? null
                              : _registerService,
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(_serviceIcon, color: Colors.white),
                                    const SizedBox(width: 10),
                                    Text(
                                      "Register $_selectedServiceType",
                                      style: const TextStyle(
                                        fontSize: 17,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 15),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Go Back",
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper Widgets ──

  Widget _buildLocationInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            "$label:",
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.tealAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.tealAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false,
    bool obscureText = true,
    VoidCallback? onToggleVisibility,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? obscureText : false,
      keyboardType: keyboardType,
      maxLines: isPassword ? 1 : maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white54,
                ),
                onPressed: onToggleVisibility,
              )
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.tealAccent, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String hint,
    required IconData icon,
    required String? value,
    required List<String> items,
    required void Function(String?)? onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: const Color(0xFF1A3040),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item, style: const TextStyle(color: Colors.white)),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
  
}

