import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../utils/env_config.dart';

/// Custom exceptions for Gemini service
class GeminiException implements Exception {
  final String message;
  final Object? cause;

  const GeminiException(this.message, [this.cause]);

  @override
  String toString() => message;
}

class GeminiMissingApiKeyException extends GeminiException {
  const GeminiMissingApiKeyException([
    super.message =
        "Gemini API key is not configured. Please add your GEMINI_API_KEY to lib/.env or pass it via --dart-define.",
  ]);
}

class GeminiNetworkException extends GeminiException {
  const GeminiNetworkException([
    super.message =
        "Network error: Unable to connect to Gemini API. Please check your internet connection.",
    super.cause,
  ]);
}

class GeminiApiException extends GeminiException {
  const GeminiApiException(super.message, [super.cause]);
}

/// Abstract contract for Gemini client (enables clean testing/mocking)
abstract class GeminiClient {
  Future<String> generateText({
    required String prompt,
    List<Content>? history,
    String? systemInstruction,
  });
}

/// Real implementation of [GeminiClient] using Google's official `google_generative_ai` SDK
class GoogleGenerativeAiClient implements GeminiClient {
  final String apiKey;
  final String modelName;
  final GenerativeModel? model;

  GoogleGenerativeAiClient({
    required this.apiKey,
    required this.modelName,
    this.model,
  });

  GenerativeModel _getModel({String? systemInstruction}) {
    if (model != null) return model!;
    return GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      systemInstruction: systemInstruction != null
          ? Content.system(systemInstruction)
          : Content.system(
              "You are a helpful, intelligent, and concise AI assistant built for this mobile application. Keep responses clear and well-formatted.",
            ),
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 2048,
      ),
    );
  }

  @override
  Future<String> generateText({
    required String prompt,
    List<Content>? history,
    String? systemInstruction,
  }) async {
    final activeModel = _getModel(systemInstruction: systemInstruction);

    // If history is provided, use multi-turn chat session
    if (history != null && history.isNotEmpty) {
      final chat = activeModel.startChat(history: history);
      final response = await chat.sendMessage(Content.text(prompt));
      final text = response.text;
      if (text == null || text.trim().isEmpty) {
        throw const GeminiApiException(
          "Gemini returned an empty response. Please try rephrasing your prompt.",
        );
      }
      return text.trim();
    } else {
      final response = await activeModel.generateContent([
        Content.text(prompt),
      ]);
      final text = response.text;
      if (text == null || text.trim().isEmpty) {
        throw const GeminiApiException(
          "Gemini returned an empty response. Please try rephrasing your prompt.",
        );
      }
      return text.trim();
    }
  }
}

/// Dedicated service for communicating with Google Gemini API
class GeminiService {
  final GeminiClient? client;
  final Duration timeout;

  GeminiService({this.client, this.timeout = const Duration(seconds: 35)});

  bool get isConfigured => EnvConfig.isGeminiConfigured;

  String get configuredModel => EnvConfig.geminiModel;

  /// Generates a response from Gemini for the given prompt, optionally with conversation history
  Future<String> sendMessage({
    required String prompt,
    List<Content>? history,
    String? systemInstruction,
  }) async {
    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty) {
      throw const GeminiException("Cannot send an empty message.");
    }

    final apiKey = EnvConfig.geminiApiKey.trim();
    if (apiKey.isEmpty) {
      throw const GeminiMissingApiKeyException();
    }

    final activeClient =
        client ??
        GoogleGenerativeAiClient(apiKey: apiKey, modelName: configuredModel);

    try {
      final result = await activeClient
          .generateText(
            prompt: trimmedPrompt,
            history: history,
            systemInstruction: systemInstruction,
          )
          .timeout(timeout);

      return result;
    } on TimeoutException catch (e) {
      debugPrint("GeminiService timeout");
      throw GeminiNetworkException(
        "Request timed out waiting for Gemini. Please try again.",
        e,
      );
    } on SocketException catch (e) {
      debugPrint("GeminiService socket exception");
      throw GeminiNetworkException(
        "Network error: Unable to connect to Gemini API. Please check your internet connection.",
        e,
      );
    } on GenerativeAIException catch (e) {
      debugPrint("GeminiService GenerativeAIException: ${e.message}");
      final msg = e.message.toLowerCase();
      if (msg.contains("api_key") ||
          msg.contains("invalid api key") ||
          msg.contains("api key not valid")) {
        throw const GeminiApiException(
          "Invalid Gemini API key. Please check your key in lib/.env or Google AI Studio.",
        );
      } else if (msg.contains("quota") ||
          msg.contains("rate limit") ||
          msg.contains("resource_exhausted")) {
        throw const GeminiApiException(
          "Gemini quota or rate limit exceeded. Please wait a moment and try again.",
        );
      } else if (msg.contains("not found") || msg.contains("model")) {
        throw GeminiApiException(
          "Configured model '$configuredModel' was not found or is not supported. Please use 'gemini-3-flash-preview'.",
        );
      }
      throw GeminiApiException("Gemini API error: ${e.message}", e);
    } on GeminiException {
      rethrow;
    } catch (e, stack) {
      debugPrint("GeminiService unexpected error: $e\n$stack");
      final errStr = e.toString().toLowerCase();
      if (errStr.contains("socket") ||
          errStr.contains("handshake") ||
          errStr.contains("connection")) {
        throw GeminiNetworkException(
          "Connection failed. Please check your internet connection.",
          e,
        );
      }
      throw GeminiApiException(
        "An unexpected error occurred while generating a response: $e",
        e,
      );
    }
  }
}
