import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive_animation/features/chat/data/chat_repository.dart';
import 'package:rive_animation/features/chat/models/chat_message_model.dart';
import 'package:rive_animation/features/chat/viewmodels/chat_view_model.dart';
import 'package:rive_animation/features/chat/views/chat_view.dart';

class FakeChatRepository implements ChatRepository {
  bool configured = true;
  String? responseToReturn;
  Exception? errorToThrow;
  Duration? responseDelay;

  @override
  bool get isConfigured => configured;

  @override
  Future<String> getAiResponse({
    required String prompt,
    List<ChatMessageModel> history = const [],
  }) async {
    if (responseDelay != null) {
      await Future.delayed(responseDelay!);
    }
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return responseToReturn ?? "Hello from Gemini!";
  }
}

void main() {
  group('ChatView Widget Tests', () {
    testWidgets('Renders ChatView header, empty state suggestions, and input bar', (tester) async {
      final fakeRepo = FakeChatRepository();
      final viewModel = ChatViewModel(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: ChatView(viewModel: viewModel),
        ),
      );

      // Verify Header & Greeting (Chat with AI appears in header and empty state)
      expect(find.text("Chat with AI"), findsNWidgets(2));
      expect(find.text("Google Gemini"), findsOneWidget);
      expect(find.byTooltip("New Chat"), findsOneWidget);

      // Verify Empty State Suggestions
      expect(find.text("Hackathon Ideas"), findsOneWidget);
      expect(find.text("Flutter Architecture"), findsOneWidget);
      expect(find.text("Quantum Computing"), findsOneWidget);

      // Verify Input Bar
      expect(find.text("Type a message..."), findsOneWidget);
    });

    testWidgets('Tapping prompt chip fills input bar and allows sending', (tester) async {
      final fakeRepo = FakeChatRepository()..responseToReturn = "Here are 3 hackathon ideas!";
      final viewModel = ChatViewModel(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: ChatView(viewModel: viewModel),
        ),
      );

      // Tap suggestion chip
      await tester.tap(find.text("Hackathon Ideas"));
      await tester.pumpAndSettle();

      // Verify TextField now has the prompt populated
      expect(
        find.widgetWithText(
          TextField,
          "Suggest 3 innovative hackathon project ideas using AI and mobile technology.",
        ),
        findsOneWidget,
      );

      // Tap send button
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump(); // Start sending

      await tester.pumpAndSettle(); // Finish response

      // AI response is rendered
      expect(find.text("Here are 3 hackathon ideas!"), findsOneWidget);
    });

    testWidgets('Displays error bubble with retry button when Gemini fails', (tester) async {
      final fakeRepo = FakeChatRepository()
        ..errorToThrow = Exception("Gemini quota or rate limit exceeded.");
      final viewModel = ChatViewModel(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: ChatView(viewModel: viewModel),
        ),
      );

      // Enter text and send
      await tester.enterText(find.byType(TextField), "Hello Gemini");
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      // Verify error message and retry button are shown
      expect(find.text("Gemini quota or rate limit exceeded."), findsOneWidget);
      expect(find.text("Retry"), findsOneWidget);
    });

    testWidgets('New Chat action clears conversation', (tester) async {
      final fakeRepo = FakeChatRepository()..responseToReturn = "First AI answer";
      final viewModel = ChatViewModel(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: ChatView(viewModel: viewModel),
        ),
      );

      // Send a message
      await tester.enterText(find.byType(TextField), "Message 1");
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      expect(find.text("Message 1"), findsOneWidget);
      expect(find.text("First AI answer"), findsOneWidget);

      // Tap New Chat icon
      await tester.tap(find.byTooltip("New Chat"));
      await tester.pumpAndSettle();

      // Confirm in dialog
      expect(find.text("Start New Chat?"), findsOneWidget);
      await tester.tap(find.text("New Chat").last);
      await tester.pumpAndSettle();

      // Verified cleared - back to empty state
      expect(find.text("Message 1"), findsNothing);
      expect(find.text("First AI answer"), findsNothing);
      expect(find.text("Hackathon Ideas"), findsOneWidget);
    });
  });
}
