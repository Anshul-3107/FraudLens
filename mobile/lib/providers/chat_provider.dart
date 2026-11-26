import 'package:flutter/material.dart';

import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _service = ChatService.instance;

  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "Hi! I'm Richie, your FraudLens personal security assistant. How can I help you keep your transactions safe today?",
      sender: 'richie',
      timestamp: DateTime.now(),
    ),
  ];

  bool _isLoading = false;
  String? _error;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> sendUserMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    final userMsg = ChatMessage(
      text: trimmed,
      sender: 'user',
      timestamp: DateTime.now(),
    );

    _messages.add(userMsg);
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final replyText = await _service.sendMessage(
        message: trimmed,
        history: _messages,
      );

      _messages.add(
        ChatMessage(
          text: replyText,
          sender: 'richie',
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      _error = e.toString();
      _messages.add(
        ChatMessage(
          text: "Sorry, I had trouble reaching the server. Please check your connection and try again.",
          sender: 'richie',
          timestamp: DateTime.now(),
        ),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearChat() {
    _messages.clear();
    _messages.add(
      ChatMessage(
        text: "Hi! I'm Richie, your FraudLens personal security assistant. How can I help you keep your transactions safe today?",
        sender: 'richie',
        timestamp: DateTime.now(),
      ),
    );
    _error = null;
    notifyListeners();
  }
}
