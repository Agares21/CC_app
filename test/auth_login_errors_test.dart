import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cloud_api_cc/core/notifications/push_service.dart';
import 'package:cloud_api_cc/data/api/api_client.dart';
import 'package:cloud_api_cc/data/api/auth_api.dart';
import 'package:cloud_api_cc/data/api/devices_api.dart';
import 'package:cloud_api_cc/presentation/bloc/auth/auth_bloc.dart';

/// Hace fallar el login de la forma indicada y devuelve el texto que la app le
/// muestra al agente.
Future<String> _mensajeDeLoginFallido({
  DioExceptionType type = DioExceptionType.badResponse,
  int? status,
  Object? data,
  Map<String, List<String>> headers = const {},
}) async {
  final client = ApiClient(baseUrl: 'https://example.test/api/v1');

  client.dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.reject(
        DioException(
          requestOptions: options,
          type: type,
          response: status == null
              ? null
              : Response<dynamic>(
                  requestOptions: options,
                  statusCode: status,
                  data: data,
                  headers: Headers.fromMap(headers),
                ),
        ),
      ),
    ),
  );

  final bloc = AuthBloc(
    authApi: AuthApi(client),
    apiClient: client,
    push: PushService(devicesApi: DevicesApi(client)),
  );

  final mensajes = <String>[];
  final sub = bloc.stream
      .where((estado) => estado is AuthError)
      .listen((estado) => mensajes.add((estado as AuthError).message));

  final result = expectLater(
    bloc.stream,
    emitsInOrder([
      isA<AuthLoading>(),
      isA<AuthError>(),
      isA<AuthUnauthenticated>(),
    ]),
  );

  bloc.add(
    const AuthLoginRequested(email: 'agente@example.com', password: 'secreta'),
  );

  await result;
  await sub.cancel();
  await bloc.close();

  return mensajes.single;
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('las credenciales rechazadas muestran el mensaje del backend', () async {
    final mensaje = await _mensajeDeLoginFallido(
      status: 422,
      data: <String, dynamic>{
        'message': 'Las credenciales no coinciden con nuestros registros.',
        'errors': <String, dynamic>{
          'email': <dynamic>['Las credenciales no coinciden con nuestros registros.'],
        },
      },
    );

    expect(mensaje, 'Las credenciales no coinciden con nuestros registros.');
  });

  test('quedarse sin conexión se distingue de una contraseña mala', () async {
    final mensaje = await _mensajeDeLoginFallido(
      type: DioExceptionType.connectionError,
    );

    expect(mensaje, contains('conexión'));
    expect(mensaje, isNot(contains('credenciales')));
  });

  test('el timeout dice que el servidor no respondió, no que falló el login', () async {
    final mensaje = await _mensajeDeLoginFallido(
      type: DioExceptionType.connectionTimeout,
    );

    expect(mensaje, contains('tardó demasiado'));
  });

  // El endpoint tiene throttle de 10 por minuto: sin este caso, reintentar sólo
  // renueva el bloqueo y el mensaje nunca cambiaría.
  test('el límite de intentos indica cuántos segundos hay que esperar', () async {
    final mensaje = await _mensajeDeLoginFallido(
      status: 429,
      headers: <String, List<String>>{
        'retry-after': <String>['37'],
      },
    );

    expect(mensaje, contains('Demasiados intentos'));
    expect(mensaje, contains('37'));
  });

  test('un error del servidor se reporta como tal, con su código', () async {
    final mensaje = await _mensajeDeLoginFallido(status: 500);

    expect(mensaje, contains('servidor'));
    expect(mensaje, contains('500'));
  });
}
