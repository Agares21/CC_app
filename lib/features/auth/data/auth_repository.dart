import 'package:dio/dio.dart';

import '../../../core/storage/token_storage.dart';
import '../domain/app_user.dart';

class AuthRepository {
  const AuthRepository(this._dio, this._storage);
  final Dio _dio;
  final TokenStorage _storage;

  Future<AppUser> login(String email, String password) async {
    final response = await _dio.post(
      '/login',
      data: {'email': email, 'password': password},
    );
    await _storage.write(response.data['token'] as String);
    return AppUser.fromJson(Map<String, dynamic>.from(response.data['user']));
  }

  Future<AppUser?> restore() async {
    if (await _storage.read() == null) return null;
    try {
      final response = await _dio.get('/me');
      return AppUser.fromJson(Map<String, dynamic>.from(response.data['user']));
    } catch (_) {
      await _storage.clear();
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/logout');
    } finally {
      await _storage.clear();
    }
  }
}
