import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cloud_api_cc/core/notifications/push_service.dart';
import 'package:cloud_api_cc/data/api/api_client.dart';
import 'package:cloud_api_cc/data/api/auth_api.dart';
import 'package:cloud_api_cc/data/api/devices_api.dart';
import 'package:cloud_api_cc/presentation/bloc/auth/auth_bloc.dart';

const _cachedUser = <String, dynamic>{
  'id': 7,
  'name': 'Agente',
  'last_name': 'Prueba',
  'email': 'agente@example.com',
  'created_at': '2026-07-23T12:00:00Z',
  'role': <String, dynamic>{'id': 2, 'name': 'soporte'},
};

AuthBloc _authBloc(ApiClient client) {
  return AuthBloc(
    authApi: AuthApi(client),
    apiClient: client,
    push: PushService(devicesApi: DevicesApi(client)),
  );
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('una falla temporal de red no elimina la sesión guardada', () async {
    final client = ApiClient(baseUrl: 'https://example.test/api/v1');
    await client.saveToken('token-persistente');
    await client.saveUser(_cachedUser);

    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              message: 'Sin conexión',
            ),
          );
        },
      ),
    );

    final bloc = _authBloc(client);
    final result = expectLater(
      bloc.stream,
      emitsInOrder([isA<AuthLoading>(), isA<AuthAuthenticated>()]),
    );

    bloc.add(AuthCheckSession());
    await result;

    expect(await client.getToken(), 'token-persistente');
    await bloc.close();
  });
}
