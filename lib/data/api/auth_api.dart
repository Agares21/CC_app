import 'package:dio/dio.dart';
import 'api_client.dart';

/// Endpoints de autenticación.
class AuthApi {
  final ApiClient _client;
  AuthApi(this._client);
  Dio get _dio => _client.dio;

  /// Devuelve {token, user}. El `device_name` le dice al backend que emita un
  /// token para este aparato (y que reemplace el anterior si ya había uno).
  Future<Map<String, dynamic>> login({required String email, required String password, bool remember = false}) async {
    final r = await _dio.post('/login', data: {
      'email': email,
      'password': password,
      'remember': remember,
      'device_name': ApiClient.deviceName,
    });
    return r.data;
  }

  Future<void> logout() async { await _dio.post('/logout'); }

  Future<Map<String, dynamic>> getUser() async {
    final r = await _dio.get('/user');
    return r.data;
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final r = await _dio.post('/forgot-password', data: {'email': email});
    return r.data;
  }

  Future<Map<String, dynamic>> resetPassword({required String token, required String email, required String password, required String passwordConfirmation}) async {
    final r = await _dio.post('/reset-password', data: {'token': token, 'email': email, 'password': password, 'password_confirmation': passwordConfirmation});
    return r.data;
  }

  Future<Map<String, dynamic>> getInvitationStatus({required String token, required String email}) async {
    final r = await _dio.get('/invitations/status', queryParameters: {'token': token, 'email': email});
    return r.data;
  }

  Future<Map<String, dynamic>> acceptInvitation({required String token, required String email, required String password, required String passwordConfirmation}) async {
    final r = await _dio.post('/invitations/accept', data: {'token': token, 'email': email, 'password': password, 'password_confirmation': passwordConfirmation});
    return r.data;
  }
}
