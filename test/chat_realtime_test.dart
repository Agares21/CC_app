import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cloud_api_cc/data/api/api_client.dart';
import 'package:cloud_api_cc/data/api/conversations_api.dart';
import 'package:cloud_api_cc/data/models/conversation_model.dart';
import 'package:cloud_api_cc/presentation/bloc/chats/chats_bloc.dart';

const _summary = <String, dynamic>{
  'id': 12,
  'status': 'open',
  'created_at': '2026-07-24T12:00:00Z',
  'last_message_at': '2026-07-24T12:00:00Z',
  'unread_count': 0,
  'contact': <String, dynamic>{'id': 4, 'wa_id': '591700', 'name': 'Cliente', 'phone': '591700'},
  'assignee': <String, dynamic>{'id': 7, 'name': 'Agente'},
  'preview': 'Hola',
  'can_send': true,
};

ChatMessage _msg(int id, String status, String body) => ChatMessage(
  id: id,
  direction: 'inbound',
  type: 'text',
  body: body,
  status: status,
  sentAt: '2026-07-24T12:0$id:00Z',
  createdAt: '2026-07-24T12:0$id:00Z',
  media: const [],
);

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('La condición esperada no ocurrió a tiempo.');
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('un mensaje de tiempo real se fusiona en el chat abierto sin duplicar', () async {
    final client = ApiClient(baseUrl: 'https://example.test/api/v1');
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/conversations') {
            handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'data': [_summary], 'meta': {'archived_count': 0, 'synced_at': '2026-07-24T00:00:00Z'}},
            ));
            return;
          }
          if (options.path == '/conversations/12') {
            handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'data': {..._summary, 'messages': [
                {'id': 1, 'direction': 'inbound', 'type': 'text', 'body': 'Hola',
                 'status': 'delivered', 'sent_at': '2026-07-24T12:00:00Z',
                 'created_at': '2026-07-24T12:00:00Z', 'media': []},
              ]}},
            ));
            return;
          }
          handler.reject(DioException(requestOptions: options, message: 'inesperado ${options.path}'));
        },
      ),
    );

    final bloc = ChatsBloc(api: ConversationsApi(client)); // sin realtime: se prueba el handler directo
    bloc.add(ChatsLoadRequested());
    await _waitUntil(() => bloc.state.conversations.isNotEmpty);

    bloc.add(const ChatsSelectConversation(12));
    await _waitUntil(() => bloc.state.detail != null);
    expect(bloc.state.detail!.messages, hasLength(1));

    // Llega un mensaje nuevo por Pusher: se agrega al hilo.
    bloc.add(ChatsRealtimeMessage(_msg(2, 'delivered', 'Mensaje en vivo')));
    await _waitUntil(() => bloc.state.detail!.messages.length == 2);
    expect(bloc.state.detail!.messages.last.body, 'Mensaje en vivo');
    // Y sube el resumen de la bandeja.
    expect(bloc.state.conversations.single.preview, 'Mensaje en vivo');

    // El mismo mensaje llega otra vez con el estado actualizado: no se duplica.
    bloc.add(ChatsRealtimeMessage(_msg(2, 'read', 'Mensaje en vivo')));
    await _waitUntil(() => bloc.state.detail!.messages.last.status == 'read');
    expect(bloc.state.detail!.messages, hasLength(2));

    await bloc.close();
  });
}
