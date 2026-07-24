import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cloud_api_cc/presentation/pages/chats/widgets/chat_taken_view.dart';

void main() {
  testWidgets('explica que otro agente ya tomó el chat', (tester) async {
    var returned = false;

    await tester.pumpWidget(
      MaterialApp(home: ChatTakenView(onBack: () => returned = true)),
    );

    expect(find.text('El chat ya fue tomado por otro agente'), findsOneWidget);
    expect(
      find.text('La conversación ya no está disponible en tu bandeja.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Volver a chats'));
    expect(returned, isTrue);
  });
}
