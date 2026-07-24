import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cloud_api_cc/data/api/api_client.dart';
import 'package:cloud_api_cc/data/api/conversations_api.dart';
import 'package:cloud_api_cc/presentation/bloc/chats/chats_bloc.dart';

const _summary = <String, dynamic>{
  'id': 12,
  'status': 'open',
  'created_at': '2026-07-23T12:00:00Z',
  'last_message_at': '2026-07-23T12:00:00Z',
  'unread_count': 1,
  'contact': <String, dynamic>{
    'id': 4,
    'wa_id': '59170000000',
    'name': 'Cliente',
    'phone': '59170000000',
  },
  'assignee': null,
  'preview': 'Hola',
  'can_send': true,
};

Map<String, dynamic> _detail() => {
  ..._summary,
  'assignee': <String, dynamic>{'id': 7, 'name': 'Agente'},
  'messages': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 1,
      'direction': 'inbound',
      'type': 'text',
      'body': 'Hola',
      'status': 'delivered',
      'sent_at': '2026-07-23T12:00:00Z',
      'created_at': '2026-07-23T12:00:00Z',
      'media': <dynamic>[],
    },
  ],
};

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('La condición esperada no ocurrió a tiempo.');
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'usa la respuesta del envío sin otro GET y conserva el chat asignado',
    () async {
      final client = ApiClient(baseUrl: 'https://example.test/api/v1');
      var listRequests = 0;
      var detailRequests = 0;
      var sendRequests = 0;

      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'GET' && options.path == '/conversations') {
              listRequests++;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{
                    'data': listRequests == 1
                        ? <dynamic>[_summary]
                        : <dynamic>[],
                    'meta': <String, dynamic>{'archived_count': 0},
                  },
                ),
              );
              return;
            }
            if (options.method == 'GET' &&
                options.path == '/conversations/12') {
              detailRequests++;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{'data': _detail()},
                ),
              );
              return;
            }
            if (options.method == 'POST' &&
                options.path == '/conversations/12/messages') {
              sendRequests++;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 201,
                  data: <String, dynamic>{
                    'data': <String, dynamic>{
                      'id': 2,
                      'direction': 'outbound',
                      'type': 'text',
                      'body': 'Respuesta',
                      'status': 'sent',
                      'sent_at': '2026-07-23T12:01:00Z',
                      'created_at': '2026-07-23T12:01:00Z',
                      'media': <dynamic>[],
                    },
                    'delivery_failed': false,
                  },
                ),
              );
              return;
            }
            handler.reject(
              DioException(
                requestOptions: options,
                message:
                    'Solicitud inesperada: ${options.method} ${options.path}',
              ),
            );
          },
        ),
      );

      final bloc = ChatsBloc(api: ConversationsApi(client));
      bloc.add(ChatsLoadRequested());
      await _waitUntil(() => bloc.state.conversations.isNotEmpty);

      bloc.add(const ChatsSelectConversation(12));
      await _waitUntil(() => bloc.state.detail != null);

      bloc.add(const ChatsSendMessage(body: 'Respuesta'));
      await _waitUntil(() => !bloc.state.sending && sendRequests == 1);

      expect(detailRequests, 1);
      expect(bloc.state.detail!.messages.last.body, 'Respuesta');
      expect(bloc.state.detail!.messages.last.status, 'sent');

      bloc.add(ChatsBackToList());
      await _waitUntil(() => listRequests == 2);

      expect(bloc.state.conversations, hasLength(1));
      expect(bloc.state.conversations.single.id, 12);
      expect(bloc.state.conversations.single.assignee?.id, 7);
      await bloc.close();
    },
  );
}
