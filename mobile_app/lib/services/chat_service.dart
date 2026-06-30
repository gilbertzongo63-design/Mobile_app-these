import 'dart:async';
import 'dart:convert';

import 'api_client.dart';

class ChatMessage {
  final int id;
  final String sender;
  final String message;
  final String createdAt;

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.message,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int,
      sender: json['sender'] as String,
      message: json['message'] as String,
      createdAt: json['created_at'] as String,
    );
  }

  bool get isUser => sender == 'user';
  bool get isBot => sender == 'bot';
}

class ChatService {
  final ApiClient _client = ApiClient();
  int? _lastMessageId;
  Timer? _pollTimer;
  final _messageController = StreamController<List<ChatMessage>>.broadcast();
  final List<ChatMessage> _messages = [];

  Stream<List<ChatMessage>> get messages => _messageController.stream;
  List<ChatMessage> get currentMessages => List.unmodifiable(_messages);

  Future<void> sendMessage(String text) async {
    final result = await _client.postJson(
      '/chat/messages',
      body: {'message': text},
      authRequired: true,
    );
    final userMsg = ChatMessage.fromJson(result['user_message'] as Map<String, dynamic>);
    final botMsg = ChatMessage.fromJson(result['bot_reply'] as Map<String, dynamic>);
    _messages.add(userMsg);
    _messages.add(botMsg);
    _lastMessageId = botMsg.id;
    _messageController.add(List.unmodifiable(_messages));
  }

  Future<void> _fetchMessages() async {
    try {
      final queryParams = <String, dynamic>{};
      if (_lastMessageId != null) {
        queryParams['after_id'] = _lastMessageId;
      }
      final response = await _client.getRawResponse(
        '/chat/messages',
        queryParameters: queryParams,
        authRequired: true,
      );
      if (response.statusCode != 200) return;
      final body = jsonDecode(response.body) as List;
      final list = body.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
      if (list.isNotEmpty) {
        _messages.addAll(list);
        _lastMessageId = list.last.id;
        _messageController.add(List.unmodifiable(_messages));
      }
    } catch (_) {}
  }

  void startPolling() {
    _fetchMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchMessages());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void dispose() {
    stopPolling();
    _messageController.close();
  }
}
