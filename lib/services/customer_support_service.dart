import 'dart:convert';

import 'package:http/http.dart' as http;

class SupportChatMessage {
  final String role;
  final String content;

  const SupportChatMessage({required this.role, required this.content});

  Map<String, dynamic> toApiJson() => {'role': role, 'content': content};
}

class CustomerSupportService {
  static const String _apiKey = 'YOUR_API_KEY_HERE';
  static const String _model = 'minimax/minimax-m2.5:free';
  static const String _apiUrl = 'https://openrouter.ai/api/v1/chat/completions';

  Future<String> sendMessage({
    required List<SupportChatMessage> history,
    required String userMessage,
  }) async {
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'temperature': 0.2,
        'max_tokens': 350,
        'messages': [
          {
            'role': 'system',
            'content': _systemPrompt,
          },
          ...history.map((message) => message.toApiJson()),
          {
            'role': 'user',
            'content': userMessage,
          },
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = _tryDecode(response.body);
      String? message;
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          message = error['message']?.toString();
        }
      }
      throw Exception(message ?? 'Support service request failed.');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>? ?? const [];
    if (choices.isEmpty) {
      throw Exception('The support assistant returned no response.');
    }

    final firstChoice = choices.first as Map<String, dynamic>;
    final message = firstChoice['message'] as Map<String, dynamic>?;
    final content = message?['content']?.toString().trim() ?? '';
    if (content.isEmpty) {
      throw Exception('The support assistant returned an empty response.');
    }

    return content;
  }

  dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static const String _systemPrompt =
      'You are FLOW Support, a concise customer support assistant for truck drivers. '
      'Only answer questions about the FLOW app and trucking workflows: loads, shipments, '
      'booking loads, pickup and delivery steps, navigation, route guidance, fuel logs, '
      'vehicle registration, profile setup, current shipment status, and load board usage. '
      'If the user asks something unrelated, refuse briefly and redirect them back to '
      'truck-driving or FLOW app help. Do not answer jokes, general knowledge, coding, '
      'or unrelated personal questions. Prefer short step-by-step answers and ask at most '
      'one clarifying question when needed.';
}
