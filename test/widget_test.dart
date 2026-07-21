import 'package:cc_api/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la aplicación inicia sin errores', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ContactCenterApp()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
