import 'dart:io';
import 'package:flutter/services.dart';

class EnvConfig {
  static String _emailJsPublicKey = "vz34m7-dasAOUvNix";
  static String _emailJsServiceId = "service_jiliz9j";
  static String _emailJsTemplateId = "template_1jkuy3t";
  // SECURITY NOTE: The EmailJS private key must NOT be hardcoded or shipped as a client secret.
  // Privileged email operations should be delegated to a secure backend (e.g. Firebase Cloud Functions).
  static String _emailJsPrivateKey = "";

  // Gemini Configuration
  // Note: Mobile client-side API keys in .env are not secure for production.
  // For production applications, delegate AI generation to a secure backend or Firebase AI Logic.
  static String _geminiApiKey = const String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
  static String _geminiModel = const String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3-flash-preview',
  );

  static const String firebaseApiKey =
      "AIzaSyB2fVBLPLNgo-qqqxYe4DasJcmJRWUNHx0";
  static const String firebaseAppId =
      "1:629528493489:android:8224de43403cd734f11190";
  static const String firebaseMessagingSenderId = "629528493489";
  static const String firebaseProjectId = "hackathonapp-91560";
  static const String firebaseStorageBucket =
      "hackathonapp-91560.firebasestorage.app";

  static String get emailJsPublicKey => _emailJsPublicKey;
  static String get emailJsServiceId => _emailJsServiceId;
  static String get emailJsTemplateId => _emailJsTemplateId;
  static String get emailJsPrivateKey => _emailJsPrivateKey;

  static String get geminiApiKey => _geminiApiKey;
  static String get geminiModel =>
      _geminiModel.trim().isNotEmpty ? _geminiModel.trim() : 'gemini-3-flash-preview';
  static bool get isGeminiConfigured => _geminiApiKey.trim().isNotEmpty;

  /// Visible for testing or manual configuration
  static void setGeminiConfig({String? apiKey, String? model}) {
    if (apiKey != null) _geminiApiKey = apiKey;
    if (model != null) _geminiModel = model;
  }

  static Future<void> init() async {
    // 1. Try reading from filesystem (desktop, test environments)
    bool loadedFromFile = false;
    for (final path in ['lib/.env', '.env']) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final content = await file.readAsString();
          _parseEnvString(content);
          loadedFromFile = true;
          break;
        }
      } catch (_) {}
    }

    // 2. Try reading from Flutter asset bundle if available
    if (!loadedFromFile) {
      try {
        final assetContent = await rootBundle.loadString('lib/.env');
        _parseEnvString(assetContent);
      } catch (_) {
        // Asset not bundled or file doesn't exist
      }
    }
  }

  static void _parseEnvString(String content) {
    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final parts = trimmed.split('=');
      if (parts.length >= 2) {
        final key = parts[0].trim();
        final value = parts
            .sublist(1)
            .join('=')
            .trim()
            .replaceAll('"', '')
            .replaceAll("'", "");
        switch (key) {
          case 'EMAILJS_PUBLIC_KEY':
            _emailJsPublicKey = value;
            break;
          case 'EMAILJS_SERVICE_ID':
            _emailJsServiceId = value;
            break;
          case 'EMAILJS_TEMPLATE_ID':
            _emailJsTemplateId = value;
            break;
          case 'EMAILJS_PRIVATE_KEY':
            _emailJsPrivateKey = value;
            break;
          case 'GEMINI_API_KEY':
          case 'Gemini_API_Key':
            if (_geminiApiKey.isEmpty) {
              _geminiApiKey = value;
            }
            break;
          case 'GEMINI_MODEL':
            if (value.isNotEmpty) {
              _geminiModel = value;
            }
            break;
        }
      }
    }
  }
}
