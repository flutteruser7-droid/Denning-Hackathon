import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'emergency_config.dart';

/// SOS SMS Service
///
/// Detects rapid volume button presses and sends emergency SMS:
/// - 5 presses within 3 seconds → SMS to Ambulance
/// - 4 presses within 3 seconds → SMS to Police
///
/// SMS includes: user details, emergency contacts, blood group, location.
/// Location is included only if internet is available, otherwise null.
class SosSmsService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final SosSmsService _instance = SosSmsService._internal();
  factory SosSmsService() => _instance;
  SosSmsService._internal();

  // ── Channels ───────────────────────────────────────────────────────────────
  static const MethodChannel _smsChannel = MethodChannel('com.example.emergency_app/sms');
  static const EventChannel _screenEventChannel = EventChannel('com.example.emergency_app/screen_events');
  StreamSubscription? _screenSubscription;

  // ── Dependencies ───────────────────────────────────────────────────────────
  final Connectivity _connectivity = Connectivity();

  // ── Button press tracking ──────────────────────────────────────────────────
  final List<DateTime> _volumePresses = [];
  Timer? _pressResetTimer;
  bool _isSending = false;

  // ── Callbacks ──────────────────────────────────────────────────────────────
  /// Called when SOS is triggered (to update UI)
  void Function(String serviceType)? onSosTriggered;

  /// Called when SMS is sent successfully
  void Function(String serviceType, String number)? onSmsSent;

  /// Called when SMS fails
  void Function(String error)? onSmsError;

  // ════════════════════════════════════════════════════════════════════════════
  //  INITIALIZATION
  // ════════════════════════════════════════════════════════════════════════════

  /// Initialize the SOS service. Call once from the dashboard's initState.
  Future<void> init() async {
    // Request permissions
    final status = await Permission.sms.request();
    final locStatus = await Permission.locationAlways.request();
    
    if (!status.isGranted) {
      onSmsError?.call('SMS permission denied. SOS SMS will not work.');
    }

    // Fetch user data and push to native
    await syncSosDataToNative();
  }

  Future<void> syncSosDataToNative() async {
    final user = FirebaseAuth.instance.currentUser;
    final userData = await _getUserData();
    if (userData != null && user != null) {
      final template = _buildSmsTemplate(userData);
      try {
        await _smsChannel.invokeMethod('saveSosData', {
          'uid': user.uid,
          'name': userData['full_name'] ?? userData['fullName'] ?? 'Unknown',
          'bloodGroup': userData['bloodGroup'] ?? 'N/A',
          'phone': userData['phone'] ?? 'N/A',
          'address': userData['homeAddress'] ?? 'N/A',
          'template': template,
          'ambulanceNumber': EmergencyConfig.ambulanceNumber,
          'policeNumber': EmergencyConfig.policeNumber,
        });
      } catch (e) {
        print('Failed to save SOS data to native: $e');
      }
    }
  }

  String _buildSmsTemplate(Map<String, dynamic> userData) {
    final name = userData['full_name'] ?? userData['fullName'] ?? 'Unknown';
    final phone = userData['phone'] ?? 'N/A';
    final bloodGroup = userData['bloodGroup'] ?? 'N/A';
    final nicNumber = userData['nicNumber'] ?? 'N/A';
    final address = userData['homeAddress'] ?? 'N/A';
    final emergency1 = userData['emergencyContact1'] ?? '';
    final emergency2 = userData['emergencyContact2'] ?? '';

    final buffer = StringBuffer();
    buffer.writeln('🚨 EMERGENCY SOS - {SERVICE} 🚨');
    buffer.writeln('');
    buffer.writeln('Name: $name');
    buffer.writeln('Phone: $phone');
    buffer.writeln('Blood Group: $bloodGroup');
    buffer.writeln('NIC: $nicNumber');
    buffer.writeln('Address: $address');
    buffer.writeln('');

    final contacts = <String>[];
    if (emergency1.isNotEmpty) contacts.add(emergency1);
    if (emergency2.isNotEmpty) contacts.add(emergency2);
    if (contacts.isNotEmpty) {
      buffer.writeln('Emergency Contacts: ${contacts.join(', ')}');
    }

    buffer.writeln('');
    buffer.writeln('Location: {LOCATION}');
    buffer.writeln('Map: {MAP}');
    buffer.writeln('');
    buffer.writeln('Time: {TIME}');
    buffer.writeln('');
    buffer.writeln('This is an automated emergency message.');

    return buffer.toString();
  }

  /// Dispose resources. Call from the dashboard's dispose.
  void dispose() {
    _screenSubscription?.cancel();
    _pressResetTimer?.cancel();
    _volumePresses.clear();
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  USER DATA FROM FIRESTORE
  // ════════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> _getUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  LOCATION
  // ════════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> _getLocation() async {
    try {
      // Check internet connectivity first
      final connectivityResult = await _connectivity.checkConnectivity();
      final hasInternet = connectivityResult.any((result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi);

      if (!hasInternet) {
        // No internet → location null as per friend's requirement
        return null;
      }

      // Check location service
      bool svcEnabled = await Geolocator.isLocationServiceEnabled();
      if (!svcEnabled) return null;

      // Check permission
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        onSmsError?.call('Location permission is required to include your location.');
        return null;
      }

      // Get position
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }

      if (pos == null) return null;

      return {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'googleMapsLink':
            'https://maps.google.com/?q=${pos.latitude},${pos.longitude}',
      };
    } catch (e) {
      return null; // Location fails silently → send SMS without location
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  BUILD SMS MESSAGE
  // ════════════════════════════════════════════════════════════════════════════

  String _buildSmsMessage(
    String serviceType,
    Map<String, dynamic> userData,
    Map<String, dynamic>? locationData,
  ) {
    final name = userData['full_name'] ?? userData['fullName'] ?? 'Unknown';
    final phone = userData['phone'] ?? 'N/A';
    final bloodGroup = userData['bloodGroup'] ?? 'N/A';
    final nicNumber = userData['nicNumber'] ?? 'N/A';
    final address = userData['homeAddress'] ?? 'N/A';
    final emergency1 = userData['emergencyContact1'] ?? '';
    final emergency2 = userData['emergencyContact2'] ?? '';
    final now = DateTime.now();
    final timestamp =
        '${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final buffer = StringBuffer();
    buffer.writeln('🚨 EMERGENCY SOS - $serviceType 🚨');
    buffer.writeln('');
    buffer.writeln('Name: $name');
    buffer.writeln('Phone: $phone');
    buffer.writeln('Blood Group: $bloodGroup');
    buffer.writeln('NIC: $nicNumber');
    buffer.writeln('Address: $address');
    buffer.writeln('');

    // Emergency contacts
    final contacts = <String>[];
    if (emergency1.isNotEmpty) contacts.add(emergency1);
    if (emergency2.isNotEmpty) contacts.add(emergency2);
    if (contacts.isNotEmpty) {
      buffer.writeln('Emergency Contacts: ${contacts.join(', ')}');
    }

    buffer.writeln('');

    // Location
    if (locationData != null) {
      buffer.writeln(
          'Location: ${locationData['latitude']}, ${locationData['longitude']}');
      buffer.writeln('Map: ${locationData['googleMapsLink']}');
    } else {
      buffer.writeln('Location: Not available (no internet)');
    }

    buffer.writeln('');
    buffer.writeln('Time: $timestamp');
    buffer.writeln('');
    buffer.writeln('This is an automated emergency message.');

    return buffer.toString();
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  SEND SMS
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> _sendSms(String number, String message) async {
    PermissionStatus status = await Permission.sms.request();
    if (status.isGranted) {
      try {
        final bool result = await _smsChannel.invokeMethod('sendSms', {
          'phone': number,
          'message': message,
        });
        if (result) {
          print("SMS sent successfully");
        } else {
          print("Failed to send SMS (native error)");
          throw Exception("Native SMS sending failed");
        }
      } catch (e) {
        print("Failed to send SMS: $e");
        throw Exception("SMS sending exception: $e");
      }
    } else {
      print("SMS permission denied");
      throw Exception("SMS permission denied");
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  ACCESSIBILITY SETTINGS
  // ════════════════════════════════════════════════════════════════════════════
  
  Future<void> openAccessibilitySettings() async {
    try {
      await _smsChannel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      print("Failed to open accessibility settings: $e");
    }
  }
}
