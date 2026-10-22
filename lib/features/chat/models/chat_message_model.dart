import 'package:google_generative_ai/google_generative_ai.dart';

enum MessageSender {
  user,
  ai,
  system,
}

class ChatMessageModel {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;
  final bool isError;

  const ChatMessageModel({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.isError = false,
  });

  bool get isUser => sender == MessageSender.user;
  bool get isAi => sender == MessageSender.ai;
  bool get isSystem => sender == MessageSender.system;

  /// Converts this message into Gemini SDK [Content] for multi-turn history
  Content? toGeminiContent() {
    if (isUser) {
      return Content.text(text);
    } else if (isAi && !isError) {
      return Content.model([TextPart(text)]);
    }
    return null;
  }

  ChatMessageModel copyWith({
    String? id,
    String? text,
    MessageSender? sender,
    DateTime? timestamp,
    bool? isError,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      isError: isError ?? this.isError,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessageModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text &&
          sender == other.sender &&
          isError == other.isError;

  @override
  int get hashCode => Object.hash(id, text, sender, isError);
}
