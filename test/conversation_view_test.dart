import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cloud_api_cc/data/api/api_client.dart';
import 'package:cloud_api_cc/data/models/conversation_model.dart';
import 'package:cloud_api_cc/presentation/pages/chats/widgets/conversation_view.dart';

const _detail = ConversationDetail(
  id: 12,
  status: 'open',
  createdAt: '2026-07-23T12:00:00Z',
  unreadCount: 0,
  contact: ContactModel(
    id: 4,
    waId: '59170000000',
    name: 'Cliente',
    phone: '59170000000',
  ),
  assignee: AssigneeModel(id: 7, name: 'Agente'),
  canSend: true,
  messages: <ChatMessage>[],
);

Widget _screen({
  required SendMessageCallback onSend,
  int revision = 0,
  String? notice,
  bool restore = false,
}) {
  // La vista resuelve las cabeceras de los adjuntos desde el ApiClient del
  // árbol, así que hay que proveerlo aunque este hilo no tenga media.
  return RepositoryProvider<ApiClient>(
    create: (_) => ApiClient(baseUrl: 'http://localhost/api/v1'),
    child: MaterialApp(
      home: Scaffold(
        body: ConversationView(
          detail: _detail,
          loading: false,
          sending: false,
          sendNotice: notice,
          sendRevision: revision,
          restoreLastMessage: restore,
          onBack: () {},
          onShowProfile: () {},
          onSendMessage: onSend,
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('restaura el texto y muestra el error cuando el POST falla', (
    tester,
  ) async {
    String? submitted;
    void onSend(String value, {String? mediaPath, String? mediaName}) =>
        submitted = value;

    await tester.pumpWidget(_screen(onSend: onSend));
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Escribe un mensaje...',
      ),
      'Mensaje importante',
    );
    // El botón alterna micrófono/enviar según el texto: el listener del
    // controlador agenda el repintado para el frame siguiente.
    await tester.pump();

    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(submitted, 'Mensaje importante');
    expect(find.text('Mensaje importante'), findsNothing);

    await tester.pumpWidget(
      _screen(
        onSend: onSend,
        revision: 1,
        notice: 'No hay conexión con el servidor.',
        restore: true,
      ),
    );
    await tester.pump();

    expect(find.text('Mensaje importante'), findsOneWidget);
    expect(find.text('No hay conexión con el servidor.'), findsOneWidget);
  });
}
