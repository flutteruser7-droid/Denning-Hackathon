import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/env_config.dart';

class EmailJsException implements Exception {
  final String message;
  final int? statusCode;

  EmailJsException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class EmailJsService {
  final String? serviceId;
  final String? templateId;
  final String? publicKey;
  final String? privateKey;
  final http.Client _client;

  EmailJsService({
    this.serviceId,
    this.templateId,
    this.publicKey,
    this.privateKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  String get activeServiceId => serviceId ?? EnvConfig.emailJsServiceId;
  String get activeTemplateId => templateId ?? EnvConfig.emailJsTemplateId;
  String get activePublicKey => publicKey ?? EnvConfig.emailJsPublicKey;
  String get activePrivateKey => privateKey ?? EnvConfig.emailJsPrivateKey;

  Future<bool> sendOtpEmail({
    required String toEmail,
    required String otp,
    String toName = 'User',
  }) async {
    final url = Uri.parse("https://api.emailjs.com/api/v1.0/email/send");

    try {
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
        },
        body: jsonEncode({
          'service_id': activeServiceId,
          'template_id': activeTemplateId,
          'user_id': activePublicKey,
          if (activePrivateKey.isNotEmpty) 'accessToken': activePrivateKey,
          'template_params': {
            'to_email': toEmail.trim(),
            'email': toEmail.trim(),
            'user_email': toEmail.trim(),
            'reply_to': toEmail.trim(),
            'recipient': toEmail.trim(),
            'to_name': toName.trim(),
            'otp': otp.trim(),
            'passcode': otp.trim(),
            'message': 'Your verification OTP code is: $otp',
          },
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw EmailJsException(
          "Email delivery service returned code ${response.statusCode}",
          response.statusCode,
        );
      }
    } on EmailJsException {
      rethrow;
    } catch (e) {
      throw EmailJsException("Failed to send OTP email: $e");
    }
  }
}
