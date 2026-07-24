import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cloud_api_cc/data/api/api_client.dart';
import 'package:cloud_api_cc/data/api/conversations_api.dart';
import 'package:cloud_api_cc/presentation/bloc/chats/chats_bloc.dart';

const _summary = <String, dynamic>{
  'id': 12,
  'status': 'open',
  'created_at': '2026-07-24T12:00:00Z',
  'last_message_at': '2026-07-24T12:00:00Z',
  'unread_count': 1,
  'contact': <String, dynamic>{
    'id': 4,
    'wa_id': '59170000000',
    'name': 'Cliente',
    'phone': '59170000000',
  },
  'assignee': <String, dynamic>{'id': 7, 'name': 'Agente'},
  'preview': 'Hola',
  'can_send': true,
};

Map<String, dynamic> _message(int id, String status, String body, String at) => {
  'id': id,
  'direction': 'inbound',
  'type': 'text',
  'body': body,
  'status': status,
  'sent_at': at,
  'created_at': at,
  'media': <dynamic>[],
};

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('La condición esperada no ocurrió a tiempo.');
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'el polleo pide sólo novedades: updated_since en la bandeja, messages_limit en el chat',
    () async {
      final client = ApiClient(baseUrl: 'https://example.test/api/v1');
      final listUpdatedSince = <Object?>[];
      final detailMessagesLimit = <Object?>[];
      var listCount = 0;
      var detailCount = 0;

      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'GET' && options.path == '/conversations') {
              listCount++;
              listUpdatedSince.add(options.queryParameters['updated_since']);
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{
                    // El delta viene VACÍO (nada cambió): la bandeja no debe
                    // perder el chat que ya tenía.
                    'data': listCount == 1 ? <dynamic>[_summary] : <dynamic>[],
                    'meta': <String, dynamic>{
                      'archived_count': 0,
                      'synced_at': '2026-07-24T00:00:0${listCount}Z',
                    },
                  },
                ),
              );
              return;
            }
            if (options.method == 'GET' &&
                options.path == '/conversations/12') {
              detailCount++;
              detailMessagesLimit.add(options.queryParameters['messages_limit']);
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{
                    'data': <String, dynamic>{
                      ..._summary,
                      'messages': detailCount == 1
                          // Apertura: el hilo tal cual.
                          ? <Map<String, dynamic>>[
                              _message(1, 'delivered', 'Hola', '2026-07-24T12:00:00Z'),
                            ]
                          // Polleo: el mensaje 1 pasó a leído y llegó el 2.
                          : <Map<String, dynamic>>[
                              _message(1, 'read', 'Hola', '2026-07-24T12:00:00Z'),
                              _message(2, 'delivered', 'Otra cosa', '2026-07-24T12:05:00Z'),
                            ],
                    },
                  },
                ),
              );
              return;
            }
            handler.reject(
              DioException(
                requestOptions: options,
                message: 'Inesperado: ${options.method} ${options.path}',
              ),
            );
          },
        ),
      );

      final bloc = ChatsBloc(api: ConversationsApi(client));

      // 1) Carga inicial: bandeja completa, SIN updated_since.
      bloc.add(ChatsLoadRequested());
      await _waitUntil(() => bloc.state.conversations.isNotEmpty);
      expect(listUpdatedSince.first, isNull);

      // 2) Polleo de bandeja: delta con updated_since = synced_at anterior.
      bloc.add(const ChatsRefreshSilent());
      await _waitUntil(() => listCount == 2);
      expect(listUpdatedSince[1], '2026-07-24T00:00:01Z');
      // Aunque el delta vino vacío, el chat sigue en la bandeja.
      expect(bloc.state.conversations, hasLength(1));

      // 3) Abrir chat: hilo completo, SIN messages_limit.
      bloc.add(const ChatsSelectConversation(12));
      await _waitUntil(() => bloc.state.detail != null);
      expect(detailMessagesLimit.first, isNull);
      expect(bloc.state.detail!.messages, hasLength(1));

      // 4) Polleo con chat abierto: acotado con messages_limit, y los mensajes
      //    se fusionan (el 1 se actualiza a leído, el 2 se agrega).
      bloc.add(const ChatsRefreshSilent());
      await _waitUntil(() => detailCount == 2);
      expect(detailMessagesLimit[1], 40);
      await _waitUntil(() => bloc.state.detail!.messages.length == 2);

      final messages = bloc.state.detail!.messages;
      expect(messages.map((m) => m.id), <int>[1, 2]);
      expect(messages.first.status, 'read');
      expect(messages.last.body, 'Otra cosa');

      await bloc.close();
    },
  );
}
