import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../core/services/gemini_service.dart';
import '../models/chat_message_model.dart';

abstract class ChatRepository {
  bool get isConfigured;
  Future<String> getAiResponse({
    required String prompt,
    List<ChatMessageModel> history = const [],
  });
}

class GeminiChatRepository implements ChatRepository {
  final GeminiService _geminiService;

  GeminiChatRepository({GeminiService? geminiService})
      : _geminiService = geminiService ?? GeminiService();

  @override
  bool get isConfigured => _geminiService.isConfigured;

  @override
  Future<String> getAiResponse({
    required String prompt,
    List<ChatMessageModel> history = const [],
  }) async {
    // Convert previous chat history into Gemini Content objects (omitting errors and current prompt)
    final List<Content> geminiHistory = [];
    for (final message in history) {
      if (message.isError) continue;
      final content = message.toGeminiContent();
      if (content != null) {
        geminiHistory.add(content);
      }
    }

    return await _geminiService.sendMessage(
      prompt: prompt,
      history: geminiHistory.isNotEmpty ? geminiHistory : null,
    );
  }
}
