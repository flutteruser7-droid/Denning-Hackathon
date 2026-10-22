import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:rive_animation/core/services/gemini_service.dart';
import 'package:rive_animation/core/utils/env_config.dart';

class MockGeminiClient implements GeminiClient {
  String? returnText;
  Exception? throwException;
  Duration? delay;
  String? lastPrompt;

  @override
  Future<String> generateText({
    required String prompt,
    List<Content>? history,
    String? systemInstruction,
  }) async {
    lastPrompt = prompt;
    if (delay != null) {
      await Future.delayed(delay!);
    }
    if (throwException != null) {
      throw throwException!;
    }
    return returnText ?? "Default mock AI response";
  }
}

void main() {
  group('GeminiService Tests', () {
    setUp(() {
      EnvConfig.setGeminiConfig(apiKey: 'test-api-key', model: 'gemini-1.5-flash');
    });

    test('Throws GeminiMissingApiKeyException when API key is empty', () async {
      EnvConfig.setGeminiConfig(apiKey: '', model: 'gemini-1.5-flash');
      final service = GeminiService();

      expect(
        () => service.sendMessage(prompt: "Hello"),
        throwsA(isA<GeminiMissingApiKeyException>()),
      );
    });

    test('Throws GeminiException when prompt is empty or blank', () async {
      final service = GeminiService();

      expect(
        () => service.sendMessage(prompt: "   "),
        throwsA(isA<GeminiException>()),
      );
    });

    test('Successfully generates text response via GeminiClient', () async {
      final mockClient = MockGeminiClient()..returnText = "Hello! I am Gemini.";
      final service = GeminiService(client: mockClient);

      final response = await service.sendMessage(prompt: "Hi there");
      expect(response, "Hello! I am Gemini.");
      expect(mockClient.lastPrompt, "Hi there");
    });

    test('Maps timeout to GeminiNetworkException', () async {
      final mockClient = MockGeminiClient()
        ..delay = const Duration(milliseconds: 100);
      final service = GeminiService(
        client: mockClient,
        timeout: const Duration(milliseconds: 20),
      );

      expect(
        () => service.sendMessage(prompt: "Slow request"),
        throwsA(isA<GeminiNetworkException>()),
      );
    });

    test('Maps GenerativeAIException with invalid key to friendly error', () async {
      final mockClient = MockGeminiClient()
        ..throwException = GenerativeAIException("API_KEY_INVALID: API key not valid.");
      final service = GeminiService(client: mockClient);

      expect(
        () => service.sendMessage(prompt: "Test prompt"),
        throwsA(predicate((e) =>
            e is GeminiApiException &&
            e.message.contains("Invalid Gemini API key"))),
      );
    });
  });
}
