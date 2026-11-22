import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import 'api_client.dart';

class ChatMessage {
  final String text;
  final String sender; // 'user' or 'richie'
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.sender,
    required this.timestamp,
  });

  bool get isUser => sender == 'user';

  Map<String, dynamic> toJson() => {
        'text': text,
        'sender': sender,
        'timestamp': timestamp.toIso8601String(),
      };
}

class ChatService {
  static final ChatService instance = ChatService._internal();
  ChatService._internal();

  final ApiClient _client = ApiClient.instance;

  Future<String> sendMessage({
    required String message,
    List<ChatMessage> history = const [],
  }) async {
    final url = '${ApiConfig.baseUrl}/api/chat/richie/';
    final historyPayload = history
        .map((m) => {
              'sender': m.sender,
              'text': m.text,
            })
        .toList();

    try {
      final response = await _client.post(
        url,
        body: {
          'message': message,
          'history': historyPayload,
        },
      );

      if (response is Map<String, dynamic> && response.containsKey('reply')) {
        return response['reply'] as String;
      }
      return 'Richie answered, but the response was unexpected.';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ChatService] Error sending message to Richie: $e');
      }
      rethrow;
    }
  }
}
