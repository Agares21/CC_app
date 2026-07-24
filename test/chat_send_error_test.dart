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

/// Abre el chat 12 y deja que el envío falle con la respuesta indicada.
Future<ChatsBloc> _blocConEnvioFallido({
  required int status,
  Object? data,
}) async {
  final client = ApiClient(baseUrl: 'https://example.test/api/v1');

  client.dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.method == 'GET' && options.path == '/conversations') {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{
                'data': <dynamic>[_summary],
                'meta': <String, dynamic>{'archived_count': 0},
              },
            ),
          );
          return;
        }
        if (options.method == 'GET' && options.path == '/conversations/12') {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{'data': _detail()},
            ),
          );
          return;
        }
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: status,
              data: data,
            ),
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
  await _waitUntil(() => !bloc.state.sending && bloc.state.sendRevision > 0);

  return bloc;
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  // Si el chat pasó a otro agente, el envío devuelve 404. Antes eso sólo tiraba
  // un aviso —vacío, además, porque el abort() del backend no traía texto— y
  // dejaba al agente atrapado en un chat muerto. Ahora abre la misma vista
  // dedicada que ya usaba al ABRIR un chat tomado.
  test('un chat que pasó a otro agente abre la vista de chat tomado', () async {
    final bloc = await _blocConEnvioFallido(
      status: 404,
      data: <String, dynamic>{'message': ''},
    );

    expect(bloc.state.chatTaken, isTrue);
    expect(bloc.state.detail, isNull);
    expect(bloc.state.selectedId, isNull);
    // Nada de recuadros oscuros y vacíos: la vista ya lo explica.
    expect(bloc.state.sendNotice, isNull);

    await bloc.close();
  });

  test('la bandeja no queda mostrando un mensaje que nunca salió', () async {
    final bloc = await _blocConEnvioFallido(
      status: 404,
      data: <String, dynamic>{'message': ''},
    );

    expect(bloc.state.conversations.single.preview, 'Hola');

    await bloc.close();
  });

  test('cuando el backend explica el rechazo, se usa su texto', () async {
    final bloc = await _blocConEnvioFallido(
      status: 422,
      data: <String, dynamic>{
        'message':
            'Pasaron más de 24 horas desde el último mensaje del cliente.',
      },
    );

    expect(
      bloc.state.sendNotice,
      'Pasaron más de 24 horas desde el último mensaje del cliente.',
    );
    expect(bloc.state.restoreLastMessage, isTrue);

    await bloc.close();
  });

  // Cualquier otro rechazo sin texto tampoco puede terminar en un aviso vacío.
  test('un rechazo sin texto nunca deja el aviso en blanco', () async {
    final bloc = await _blocConEnvioFallido(
      status: 500,
      data: <String, dynamic>{'message': ''},
    );

    final notice = bloc.state.sendNotice;
    expect(notice, isNotNull);
    expect(notice!.trim(), isNotEmpty);
    expect(notice, contains('500'));
    // El texto tipeado vuelve al cuadro: no se pierde lo que escribió.
    expect(bloc.state.restoreLastMessage, isTrue);
    expect(
      bloc.state.detail!.messages.map((m) => m.body),
      isNot(contains('Respuesta')),
    );

    await bloc.close();
  });
}
