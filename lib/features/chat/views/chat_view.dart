import 'package:flutter/material.dart';
import '../viewmodels/chat_view_model.dart';
import 'widgets/chat_empty_state.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/chat_typing_indicator.dart';

class ChatView extends StatefulWidget {
  final ChatViewModel? viewModel;

  const ChatView({super.key, this.viewModel});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  late final ChatViewModel _viewModel;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ChatInputBarState> _inputKey = GlobalKey<ChatInputBarState>();

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ?? ChatViewModel();
    _viewModel.addListener(_onViewModelUpdated);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelUpdated);
    if (widget.viewModel == null) {
      _viewModel.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _onViewModelUpdated() {
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSelectPrompt(String prompt) {
    _inputKey.currentState?.setInputText(prompt);
  }

  Future<void> _handleConfirmClearChat() async {
    if (_viewModel.isEmpty) return;

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Start New Chat?",
          style: TextStyle(
            fontFamily: "Poppins",
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: const Text(
          "This will clear the current conversation history.",
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("New Chat"),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      _viewModel.clearChat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Custom App Header with back button when pushed as destination
            Container(
              padding: EdgeInsets.fromLTRB(canPop ? 12 : 68, 12, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFF1F5F9),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (canPop) ...[
                    IconButton(
                      tooltip: "Back to Home",
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: Color(0xFF17203A),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Chat with AI",
                          style: TextStyle(
                            fontFamily: "Poppins",
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF17203A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              "Google Gemini",
                              style: TextStyle(
                                fontFamily: "Intel",
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: "New Chat",
                    icon: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add_comment_outlined,
                        size: 19,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    onPressed: _handleConfirmClearChat,
                  ),
                ],
              ),
            ),

            // Chat Messages / Empty State
            Expanded(
              child: ListenableBuilder(
                listenable: _viewModel,
                builder: (context, _) {
                  if (_viewModel.isEmpty && !_viewModel.isLoading) {
                    return ChatEmptyState(
                      isConfigured: _viewModel.isConfigured,
                      onSelectPrompt: _handleSelectPrompt,
                    );
                  }

                  final messageCount = _viewModel.messages.length;
                  final itemCount =
                      messageCount + (_viewModel.isLoading ? 1 : 0);

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (index < messageCount) {
                        final msg = _viewModel.messages[index];
                        return ChatMessageBubble(
                          key: ValueKey(msg.id),
                          message: msg,
                          onRetry: msg.isError
                              ? () => _viewModel.retryLastMessage()
                              : null,
                        );
                      } else {
                        return const ChatTypingIndicator();
                      }
                    },
                  );
                },
              ),
            ),

            // Input Bar
            ListenableBuilder(
              listenable: _viewModel,
              builder: (context, _) {
                return ChatInputBar(
                  key: _inputKey,
                  isLoading: _viewModel.isLoading,
                  onSendMessage: (text) => _viewModel.sendMessage(text),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
