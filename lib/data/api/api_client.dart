import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Cliente HTTP principal de la app.
///
/// Apunta a la superficie versionada (/api/v1). El backend también sirve las
/// mismas rutas sin versión, pero eso está para no romper al panel web: la app
/// usa v1 para que un futuro v2 pueda cambiar el contrato sin dejar tirados a
/// los teléfonos con una versión vieja instalada.
class ApiClient {
  /// Servidor por defecto. Se puede apuntar a otro (local o staging) sin tocar
  /// el código:
  ///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
  /// (10.0.2.2 es el host de la máquina visto desde el emulador de Android).
  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://cc.edgarcallisaya.com/api/v1',
  );

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';
  static const String _conversationsCacheKey = 'cache_conversations';
  static const String _tasksCacheKey = 'cache_tasks';

  late final Dio dio;
  final FlutterSecureStorage _storage;

  ApiClient({String? baseUrl, FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? _defaultBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
    dio.interceptors.add(_AuthInterceptor(_storage));
  }

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);
  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> saveUser(Map<String, dynamic> user) {
    return _storage.write(key: _userKey, value: jsonEncode(user));
  }

  Future<Map<String, dynamic>?> getSavedUser() async {
    final encoded = await _storage.read(key: _userKey);
    if (encoded == null) return null;

    try {
      final decoded = jsonDecode(encoded);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _userKey),
      _storage.delete(key: _conversationsCacheKey),
      _storage.delete(key: _tasksCacheKey),
    ]);
  }

  Future<void> saveConversationsCache(Map<String, dynamic> data) {
    return _storage.write(key: _conversationsCacheKey, value: jsonEncode(data));
  }

  Future<Map<String, dynamic>?> getConversationsCache() {
    return _readJsonMap(_conversationsCacheKey);
  }

  Future<void> saveTasksCache(Map<String, dynamic> data) {
    return _storage.write(key: _tasksCacheKey, value: jsonEncode(data));
  }

  Future<Map<String, dynamic>?> getTasksCache() {
    return _readJsonMap(_tasksCacheKey);
  }

  Future<Map<String, dynamic>?> _readJsonMap(String key) async {
    final encoded = await _storage.read(key: key);
    if (encoded == null) return null;

    try {
      final decoded = jsonDecode(encoded);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      await _storage.delete(key: key);
      return null;
    }
  }

  /// Convierte las rutas relativas que devuelve Laravel (por ejemplo, el
  /// avatar privado) en una URL del mismo servidor configurado para la app.
  String absoluteUrl(String path) {
    return Uri.parse(dio.options.baseUrl).resolve(path).toString();
  }

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
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // La lectura del llavero puede fallar (el keystore de Android tira
    // PlatformException si la clave quedó inservible, por ejemplo tras una
    // restauración de copia de seguridad). Si dejáramos propagar la excepción,
    // handler.next() no se llamaría nunca: los timeouts de Dio corren recién
    // desde que la petición sale, así que el Future no se completaría jamás y
    // la pantalla quedaría cargando para siempre. Mejor seguir sin Bearer y
    // que el backend conteste 401, que sí sabemos manejar.
    try {
      final token = await _storage.read(key: ApiClient._tokenKey);
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    } catch (e) {
      debugPrint('ApiClient: no se pudo leer el token guardado. $e');
    }

    handler.next(options);
  }
}
