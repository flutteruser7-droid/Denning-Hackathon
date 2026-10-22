import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rive_animation/core/services/emailjs_service.dart';

void main() {
  group('EmailJsService Tests', () {
    test('sendOtpEmail sends HTTP POST with correct body and returns true on 200', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), "https://api.emailjs.com/api/v1.0/email/send");
        expect(request.headers['Content-Type'], 'application/json');

        final body = jsonDecode(request.body);
        expect(body['service_id'], 'test_service');
        expect(body['template_id'], 'test_template');
        expect(body['user_id'], 'test_public_key');
        expect(body['accessToken'], 'test_private_key');
        expect(body['template_params']['to_email'], 'user@example.com');
        expect(body['template_params']['otp'], '654321');

        return http.Response('OK', 200);
      });

      final service = EmailJsService(
        serviceId: 'test_service',
        templateId: 'test_template',
        publicKey: 'test_public_key',
        privateKey: 'test_private_key',
        client: mockClient,
      );

      final result = await service.sendOtpEmail(
        toEmail: 'user@example.com',
        otp: '654321',
        toName: 'John',
      );

      expect(result, isTrue);
    });

    test('sendOtpEmail throws EmailJsException on non-200 responses', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Unauthorized', 403);
      });

      final service = EmailJsService(
        serviceId: 'test_service',
        templateId: 'test_template',
        publicKey: 'test_public_key',
        privateKey: 'test_private_key',
        client: mockClient,
      );

      expect(
        () => service.sendOtpEmail(toEmail: 'user@example.com', otp: '111222'),
        throwsA(isA<EmailJsException>()),
      );
    });
  });
}
