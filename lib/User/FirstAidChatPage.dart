import 'package:emergency_app/services/first_aid_ai_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class FirstAidChatPage extends StatefulWidget {
  const FirstAidChatPage({super.key});

  @override
  State<FirstAidChatPage> createState() => _FirstAidChatPageState();
}

class _FirstAidChatPageState extends State<FirstAidChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _service = FirstAidAiService();
  final _tts = FlutterTts();
  final _speech = stt.SpeechToText();
  final _messages = <Map<String, String>>[];
  bool _loading = false;
  bool _listening = false;
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _loading) return;
    _controller.clear();
    setState(() {
      _messages.add({'role': 'user', 'text': question});
      _loading = true;
    });
    _scrollToBottom();
    try {
      final answer = await _service.answer(question);
      if (!mounted) return;
      setState(() => _messages.add({'role': 'assistant', 'text': answer}));
      await _tts.speak(answer);
    } on ArgumentError catch (error) {
      _showError(error.message?.toString() ?? 'Please enter a question.');
    } on Exception catch (error) {
      _showError('Unable to get first-aid guidance: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    _scrollToBottom();
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) return;
    if (_listening) {
      await _speech.stop();
    } else {
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() => _controller.text = result.recognizedWords);
          }
        },
      );
    }
    if (mounted) setState(() => _listening = !_listening);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _service.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('First-Aid Responder'),
        backgroundColor: const Color(0xFF0A2550),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFF0D1625),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Text(
              'Describe the emergency for immediate first-aid steps.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_loading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final message = _messages[index];
                final isUser = message['role'] == 'user';
                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 360),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF1565C0)
                          : const Color(0xFF1B2B49),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      message['text']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.35,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'What happened?',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF1B2B49),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                 
                  IconButton(
                    tooltip: 'Send',
                    onPressed: _loading ? null : _send,
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
