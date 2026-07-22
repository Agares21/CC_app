import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'api_client.dart';

/// Registro del aparato para recibir notificaciones nativas.
///
/// El token lo emite el sistema operativo (APNs en iOS, FCM en Android) y hay
/// que dejarlo acá para que el backend pueda despertar la app cuando entra un
/// mensaje de WhatsApp. Conviene llamar a [register] en cada arranque, no solo
/// la primera vez: el token rota (reinstalación, restore de backup, limpieza
/// de datos) y el registro es idempotente, así que repetirlo no duplica nada.
class DevicesApi {
  final ApiClient _client;
  DevicesApi(this._client);
  Dio get _dio => _client.dio;

  static String get _platform => Platform.isIOS ? 'ios' : 'android';

  Future<void> register({
    required String token,
    String? deviceName,
    String? appVersion,
  }) async {
    await _dio.post('/devices', data: {
      'token': token,
      'platform': _platform,
      'device_name': ?deviceName,
      'app_version': ?appVersion,
    });
  }

  /// Da de baja este aparato. El logout ya lo hace del lado del servidor, así
  /// que solo hace falta si el usuario apaga las notificaciones sin desloguearse.
  Future<void> unregister(String token) async {
    await _dio.delete('/devices', data: {'token': token});
  }

  Future<List<dynamic>> list() async {
    final r = await _dio.get('/devices');
    return r.data['data'] as List<dynamic>;
  }
}
