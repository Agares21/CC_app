import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Cliente HTTP principal de la app.
///
/// Apunta a la superficie versionada (/api/v1). El backend también sirve las
/// mismas rutas sin versión, pero eso está para no romper al panel web: la app
/// usa v1 para que un futuro v2 pueda cambiar el contrato sin dejar tirados a
/// los teléfonos con una versión vieja instalada.
class ApiClient {
  static const String _defaultBaseUrl = 'https://api.cloudapicc.com/api/v1';

  static const String _tokenKey = 'auth_token';

  late final Dio dio;
  final FlutterSecureStorage _storage;

  ApiClient({String? baseUrl, FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage() {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? _defaultBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(_AuthInterceptor(_storage));
  }

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);
  Future<String?> getToken() => _storage.read(key: _tokenKey);

  /// Cabeceras para bajar adjuntos (imágenes y videos de los chats).
  ///
  /// La API los sirve en una URL estable, pero autenticada: sin el Bearer
  /// responde 401. `CachedNetworkImage` las acepta en `httpHeaders`, y como la
  /// URL no caduca, el caché en disco sigue sirviendo entre sesiones.
  Future<Map<String, String>> mediaHeaders() async {
    final token = await getToken();

    return {
      'Accept': '*/*',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Nombre con el que se registra el token de sesión de este aparato. El
  /// backend guarda uno solo por nombre, así que volver a loguearse en el mismo
  /// teléfono reemplaza su token en vez de acumular sesiones huérfanas.
  static String get deviceName {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';

    return Platform.operatingSystem;
  }
}

class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  _AuthInterceptor(this._storage);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: ApiClient._tokenKey);
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }
}
