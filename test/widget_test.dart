import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_api_cc/main.dart';
import 'package:cloud_api_cc/core/notifications/push_service.dart';
import 'package:cloud_api_cc/data/api/api_client.dart';
import 'package:cloud_api_cc/data/api/auth_api.dart';
import 'package:cloud_api_cc/data/api/conversations_api.dart';
import 'package:cloud_api_cc/data/api/devices_api.dart';

void main() {
  testWidgets('App se construye sin errores', (WidgetTester tester) async {
    final apiClient = ApiClient();
    final authApi = AuthApi(apiClient);
    final conversationsApi = ConversationsApi(apiClient);
    // Sin init() el servicio queda como no disponible y sus métodos no hacen
    // nada, así que el test no toca Firebase ni la red.
    final pushService = PushService(devicesApi: DevicesApi(apiClient));

    await tester.pumpWidget(CloudApiCCApp(
      apiClient: apiClient,
      authApi: authApi,
      conversationsApi: conversationsApi,
      pushService: pushService,
    ));

    // Verificar que al menos el widget se construyó.
    expect(find.byType(CloudApiCCApp), findsOneWidget);
  });
}
