import 'package:flutter/foundation.dart';
import '../data/chat_repository.dart';
import '../models/chat_message_model.dart';

class ChatViewModel extends ChangeNotifier {
  final ChatRepository _repository;
  final List<ChatMessageModel> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;

  ChatViewModel({ChatRepository? repository})
      : _repository = repository ?? GeminiChatRepository();

  List<ChatMessageModel> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isConfigured => _repository.isConfigured;
  bool get isEmpty => _messages.isEmpty;

  /// Clear the active error notification
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Reset conversation history
  void clearChat() {
    _messages.clear();
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Sends a message to the AI assistant
  Future<void> sendMessage(String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return;
    }

    if (_isLoading) {
      // Prevent duplicate requests while already waiting
      return;
    }

    final userMessage = ChatMessageModel(
      id: "user_${DateTime.now().microsecondsSinceEpoch}",
      text: trimmedText,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    _messages.add(userMessage);
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Send previous messages (excluding the new userMessage) as history
      final history = _messages.sublist(0, _messages.length - 1);
      final aiResponseText = await _repository.getAiResponse(
        prompt: trimmedText,
        history: history,
      );

      final aiMessage = ChatMessageModel(
        id: "ai_${DateTime.now().microsecondsSinceEpoch}",
        text: aiResponseText,
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      );

      _messages.add(aiMessage);
    } catch (e) {
      final errorText = e.toString().replaceFirst("Exception: ", "");
      _errorMessage = errorText;

      final errorMessageModel = ChatMessageModel(
        id: "error_${DateTime.now().microsecondsSinceEpoch}",
        text: errorText,
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
        isError: true,
      );
      _messages.add(errorMessageModel);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Retries sending the last user message if previous attempt failed
  Future<void> retryLastMessage() async {
    if (_isLoading || _messages.isEmpty) return;

    // Find the last user message
    final lastUserIndex = _messages.lastIndexWhere((m) => m.isUser);
    if (lastUserIndex == -1) return;

    final lastUserText = _messages[lastUserIndex].text;

    // Remove any trailing error messages
    if (_messages.last.isError) {
      _messages.removeLast();
    }
    // Remove the last user message so sendMessage can re-add it cleanly
    _messages.removeAt(lastUserIndex);
    notifyListeners();

    await sendMessage(lastUserText);
  }
}
