import 'package:dio/dio.dart';

import '../domain/conversation.dart';

class ChatRepository {
  const ChatRepository(this._dio);
  final Dio _dio;

  Future<List<Conversation>> all() async {
    final response = await _dio.get('/conversations');
    return (response.data['data'] as List)
        .map((item) => Conversation.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<ChatMessage>> messages(int id) async {
    final response = await _dio.get('/conversations/$id');
    return (response.data['data']['messages'] as List)
        .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> send(int id, String body) =>
      _dio.post('/conversations/$id/messages', data: {'body': body});
}
