import 'package:flutter_test/flutter_test.dart';
import 'package:rive_animation/features/chat/data/chat_repository.dart';
import 'package:rive_animation/features/chat/models/chat_message_model.dart';
import 'package:rive_animation/features/chat/viewmodels/chat_view_model.dart';

class MockChatRepository implements ChatRepository {
  bool configured = true;
  String? returnResponse;
  Exception? throwError;
  String? lastPrompt;
  List<ChatMessageModel>? lastHistory;

  @override
  bool get isConfigured => configured;

  @override
  Future<String> getAiResponse({
    required String prompt,
    List<ChatMessageModel> history = const [],
  }) async {
    lastPrompt = prompt;
    lastHistory = history;
    if (throwError != null) {
      throw throwError!;
    }
    return returnResponse ?? "Mock AI Response";
  }
}

void main() {
  group('ChatViewModel Tests', () {
    test('Initializes with empty messages and idle state', () {
      final repo = MockChatRepository();
      final viewModel = ChatViewModel(repository: repo);

      expect(viewModel.messages, isEmpty);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isEmpty, isTrue);
      expect(viewModel.isConfigured, isTrue);
    });

    test('Ignores empty or whitespace prompts', () async {
      final repo = MockChatRepository();
      final viewModel = ChatViewModel(repository: repo);

      await viewModel.sendMessage('');
      await viewModel.sendMessage('   ');

      expect(viewModel.messages, isEmpty);
      expect(viewModel.isLoading, isFalse);
      expect(repo.lastPrompt, isNull);
    });

    test('Successfully sends message and appends AI response', () async {
      final repo = MockChatRepository()..returnResponse = "Hello, world!";
      final viewModel = ChatViewModel(repository: repo);

      final future = viewModel.sendMessage('How are you?');

      expect(viewModel.isLoading, isTrue);
      expect(viewModel.messages.length, 1);
      expect(viewModel.messages.first.text, 'How are you?');
      expect(viewModel.messages.first.isUser, isTrue);

      await future;

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.messages.length, 2);
      expect(viewModel.messages[1].text, 'Hello, world!');
      expect(viewModel.messages[1].isAi, isTrue);
      expect(viewModel.messages[1].isError, isFalse);
      expect(viewModel.errorMessage, isNull);
    });

    test('Handles repository error properly and sets error message', () async {
      final repo = MockChatRepository()
        ..throwError = Exception("API quota exceeded");
      final viewModel = ChatViewModel(repository: repo);

      await viewModel.sendMessage('Generate something');

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.messages.length, 2);
      expect(viewModel.messages.last.isError, isTrue);
      expect(viewModel.messages.last.text, contains("API quota exceeded"));
      expect(viewModel.errorMessage, contains("API quota exceeded"));
    });

    test('clearChat resets messages and state', () async {
      final repo = MockChatRepository()..returnResponse = "Response";
      final viewModel = ChatViewModel(repository: repo);

      await viewModel.sendMessage('Hello');
      expect(viewModel.messages.length, 2);

      viewModel.clearChat();
      expect(viewModel.messages, isEmpty);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isLoading, isFalse);
    });

    test('clearError resets error notification', () {
      final repo = MockChatRepository()
        ..throwError = Exception("Some error");
      final viewModel = ChatViewModel(repository: repo);

      viewModel.sendMessage('Hello');
      viewModel.clearError();
      expect(viewModel.errorMessage, isNull);
    });

    test('retryLastMessage re-sends previous user prompt after failure', () async {
      final repo = MockChatRepository()
        ..throwError = Exception("Transient failure");
      final viewModel = ChatViewModel(repository: repo);

      await viewModel.sendMessage('Explain Dart');
      expect(viewModel.messages.length, 2);
      expect(viewModel.messages.last.isError, isTrue);

      // Now repo succeeds
      repo.throwError = null;
      repo.returnResponse = "Dart is a client-optimized language.";

      await viewModel.retryLastMessage();

      expect(viewModel.messages.length, 2);
      expect(viewModel.messages.first.text, 'Explain Dart');
      expect(viewModel.messages.last.text, 'Dart is a client-optimized language.');
      expect(viewModel.messages.last.isError, isFalse);
    });
  });
}
