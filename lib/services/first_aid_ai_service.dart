import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class FirstAidAiService {
  FirstAidAiService({http.Client? client}) : _client = client ?? http.Client();

  static const _endpoint = 'https://openrouter.ai/api/v1/chat/completions';
  final http.Client _client;

  Future<String> answer(String question) async {
    final prompt = question.trim();
    if (prompt.isEmpty) {
      throw ArgumentError('A first-aid question is required.');
    }

    final config = await _loadEnv();
    final apiKey = config['OPEN_ROUTER_API_KEY'];
    final model =
        config['OPEN_ROUTER_MODEL'] ?? 'nvidia/nemotron-3-ultra-550b-a55b:free';

    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final response = await _client
            .post(
              Uri.parse(_endpoint),
              headers: {
                'Authorization': 'Bearer $apiKey',
                'Content-Type': 'application/json',
                'HTTP-Referer': 'https://emergency-app.local',
                'X-Title': 'Emergency App First-Aid Responder',
              },
              body: jsonEncode({
                'model': model,
                'temperature': 0.2,
                'max_tokens': 300,
                'messages': [
                  {
                    'role': 'system',
                    'content': '''
You are an emergency first-aid responder. Give concise, safe, actionable guidance.
For every injury, illness, or emergency question, output exactly three bullet points
and nothing else. Do not include a summary, heading, introduction, or extra text.
The first bullet must tell the user to call emergency services (1122) immediately,
or explain when to call them immediately. The second and third bullets must be
critical physical steps or safety warnings. Do not diagnose, recommend medication
doses, or replace professional medical care. If the user may be in immediate danger,
prioritize calling emergency services.
''',
                  },
                  {'role': 'user', 'content': prompt},
                ],
              }),
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final choices = body['choices'] as List<dynamic>?;
          final content = choices?.isNotEmpty == true
              ? (choices!.first as Map<String, dynamic>)['message']
                    as Map<String, dynamic>?
              : null;
          final text = content?['content']?.toString().trim();
          if (text != null && text.isNotEmpty) {
            return _removeSummary(text);
          }
        }
      } on http.ClientException {
        // Use the offline protocol below when the network is unavailable.
      } on TimeoutException {
        // Use the offline protocol below when the network is unavailable.
      } on FormatException {
        // Use the offline protocol below when the provider response is invalid.
      }
    }

    return _offlineAnswer(prompt);
  }

  Future<Map<String, String>> _loadEnv() async {
    final source = await rootBundle.loadString('lib/.env');
    final values = <String, String>{};
    for (final line in source.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final separator = trimmed.indexOf('=');
      if (separator <= 0) continue;
      final key = trimmed.substring(0, separator).trim();
      final value = trimmed
          .substring(separator + 1)
          .trim()
          .replaceFirst(RegExp(r'^"'), '')
          .replaceFirst(RegExp(r'"$'), '');
      values[key] = value;
    }
    return values;
  }

  Future<String> _offlineAnswer(String question) async {
    final source = await rootBundle.loadString(
      'assets/emergency_protocols.json',
    );
    final protocols = jsonDecode(source) as List<dynamic>;
    final normalized = question.toLowerCase();
    for (final item in protocols) {
      final protocol = item as Map<String, dynamic>;
      final keywords = (protocol['keywords'] as List<dynamic>).map(
        (keyword) => keyword.toString().toLowerCase(),
      );
      if (keywords.any(normalized.contains)) {
        return _formatOffline(protocol);
      }
    }
    return _formatOffline({
      'steps': [
        'Call an ambulance or emergency services (1122) immediately if symptoms are severe, worsening, or life-threatening.',
        'Move to a safe place, keep the person still and calm, and check that they are breathing normally.',
        'Do not give food, drink, or medication; monitor them and follow the dispatcher’s instructions.',
      ],
    });
  }

  String _formatOffline(Map<String, dynamic> protocol) {
    final steps = (protocol['steps'] as List<dynamic>).take(3);
    return steps.map((step) => '- ${step.toString()}').join('\n');
  }

  String _removeSummary(String response) {
    final summaryIndex = response.toLowerCase().indexOf('summary:');
    if (summaryIndex == -1) return response;
    return response.substring(0, summaryIndex).trim();
  }

  void dispose() => _client.close();
}
